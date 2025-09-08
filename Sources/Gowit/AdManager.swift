import Foundation

class AdManager {
    public static let shared = AdManager()
    private init() {
        client = HTTPClient()
    }

    private var url: URL?
    private var client: HTTPClientProtocol
    private var marketplaceId: String = "MARKETPLACE_UUID"
    public var timeoutInterval: TimeInterval = 60

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
        let result: Result<Data?, NetworkFailure>
        do {
            let data = try await client.asyncPost(url: url, data: requestData, timeoutInterval: timeoutInterval)
            result = .success(data)
        } catch {
            result = .failure(error)
        }

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
        let result: Result<Data?, NetworkFailure>
        do {
            let data = try await client.asyncPost(url: url, data: requestData, timeoutInterval: timeoutInterval)
            result = .success(data)
        } catch {
            result = .failure(error)
        }

        return try processResponse(result: result)
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
