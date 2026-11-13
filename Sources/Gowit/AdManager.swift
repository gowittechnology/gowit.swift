import Foundation

class AdManager {
    public static let shared = AdManager()
    private init() {
        client = HTTPClient()
    }

    /// Default total time allowed for one ad request.
    static let defaultTimeoutInterval: TimeInterval = 0.6
    /// Network timeout used when the SDK deadline is turned off (`timeoutInterval <= 0`).
    static let fallbackNetworkTimeout: TimeInterval = 60

    private var url: URL?
    var client: HTTPClientProtocol
    private var marketplaceId: String = "MARKETPLACE_UUID"

    private let timeoutLock = NSLock()
    private var storedTimeoutInterval: TimeInterval = AdManager.defaultTimeoutInterval

    /// Total time allowed for one ad request, from sending it to receiving the full response.
    /// When it runs out, the request is cancelled and `getAds` throws
    /// `AdError.http(error: .timeout)`. Set to `0` or less to turn the SDK deadline off.
    var timeoutInterval: TimeInterval {
        get {
            timeoutLock.lock()
            defer { timeoutLock.unlock() }
            return storedTimeoutInterval
        }
        set {
            timeoutLock.lock()
            storedTimeoutInterval = newValue
            timeoutLock.unlock()
        }
    }

    public func configure(hostname: String, marketplaceId: String) {
        self.marketplaceId = marketplaceId

        // Construct the ads endpoint URL
        if let baseUrl = URL(string: hostname) {
            self.url = baseUrl.appendingPathComponent("server/v2/sdk/ads")
        }
    }

    public func getAds(
        placements: [PlacementRequest],
        pageNumber: Int? = nil,
        sessionId: String? = nil
    ) async throws -> AdResponse {
        guard let url = url else {
            throw AdError.configurationError(message: "URL not configured. Call configure() first.")
        }

        // Validate placements
        guard !placements.isEmpty else {
            throw AdError.invalidPlacements
        }

        // Create the ad request
        let adRequest = AdRequest(
            marketplaceId: marketplaceId,
            placements: placements,
            sessionId: sessionId ?? UUID().uuidString,
            pageNumber: pageNumber ?? 0
        )

        // Serialize the request
        guard let requestData = try? JSONEncoder().encode(adRequest) else {
            throw AdError.serializationError
        }

        // Make the request
        let result = await post(url: url, data: requestData)
        return try processResponse(result: result)
    }

    public func getAds(request: AdRequest) async throws -> AdResponse {
        guard let url = url else {
            throw AdError.configurationError(message: "URL not configured. Call configure() first.")
        }

        // Validate placements
        guard !request.placements.isEmpty else {
            throw AdError.invalidPlacements
        }

        // Serialize the request
        guard let requestData = try? JSONEncoder().encode(request) else {
            throw AdError.serializationError
        }

        // Make the request
        let result = await post(url: url, data: requestData)
        return try processResponse(result: result)
    }

    /// Sends the request and cancels it when `timeoutInterval` runs out.
    private func post(url: URL, data: Data) async -> Result<Data?, NetworkFailure> {
        let timeout = timeoutInterval
        let client = self.client

        guard timeout > 0 else {
            do {
                return .success(try await client.asyncPost(url: url, data: data, timeoutInterval: Self.fallbackNetworkTimeout))
            } catch {
                return .failure(error)
            }
        }

        do {
            let responseData = try await withThrowingTaskGroup(of: Data?.self) { group -> Data? in
                group.addTask {
                    try await client.asyncPost(url: url, data: data, timeoutInterval: timeout)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw NetworkFailure.timeout(context: NetworkContext(endpoint: url.absoluteString, method: .POST))
                }
                // Whichever finishes first wins; the other task is cancelled.
                defer { group.cancelAll() }
                guard let first = try await group.next() else { return nil }
                return first
            }
            return .success(responseData)
        } catch let failure as NetworkFailure {
            return .failure(failure)
        } catch {
            return .failure(.connectivity(underlying: error, context: NetworkContext(endpoint: url.absoluteString, method: .POST)))
        }
    }

    private func processResponse(result: Result<Data?, NetworkFailure>) throws -> AdResponse {
        switch result {
        case let .success(data):
            // Handle 204 No Content (no ads available)
            if data == nil {
                // Server returned 204 - no ads available
                return createEmptyResponse()
            }

            // Handle regular response with data
            return try decodeAdResponse(data: data!)
        case let .failure(error):
            throw AdError.http(error: error)
        }
    }

    private func createEmptyResponse() -> AdResponse {
        // Create an empty response when no ads are available (204 status)
        return AdResponse(
            responseId: UUID().uuidString,
            placements: []
        )
    }

    private func decodeAdResponse(data: Data) throws -> AdResponse {
        do {
            return try JSONDecoder().decode(AdResponse.self, from: data)
        } catch {
            throw AdError.deserializationError(error: error, data: data)
        }
    }
}
