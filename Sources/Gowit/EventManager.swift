import Foundation

public enum EventManagerError: Error {
    case http(error: NetworkFailure)
    case serializationError
    case deserializationError(error: Error, data: Data)
    case emptyResponse
    case invalidEventType
    case configurationError(message: String)
}

class EventManager {
    public static let shared = EventManager()

    private var baseUrl: URL?
    private var client: HTTPClientProtocol
    private var marketplaceId: String = "MARKETPLACE_UUID"
    private var autoImpressionEnabled: Bool = false

    private init() {
        client = HTTPClient()
    }

    public func configure(hostname: String, marketplaceId: String) {
        configure(hostname: hostname, marketplaceId: marketplaceId, autoImpressionEnabled: false)
    }

    public func configure(hostname: String, marketplaceId: String, autoImpressionEnabled: Bool) {
        self.marketplaceId = marketplaceId
        self.autoImpressionEnabled = autoImpressionEnabled

        // Store base URL for constructing different endpoints
        self.baseUrl = URL(string: hostname)
    }

    // MARK: - Public Properties

    public var isAutoImpressionEnabled: Bool {
        return autoImpressionEnabled
    }

    // MARK: - Event Methods

    public func sendImpressionEvent(adId: String, sessionId: String) async throws {
        try await sendSdkEvent(type: .impression, adId: adId, sessionId: sessionId)
    }

    public func sendViewableImpressionEvent(adId: String, sessionId: String) async throws {
        try await sendSdkEvent(type: .viewableImpression, adId: adId, sessionId: sessionId)
    }

    public func sendClickEvent(adId: String, sessionId: String) async throws {
        try await sendSdkEvent(type: .click, adId: adId, sessionId: sessionId)
    }

    public func sendSaleEvent(sales: [Sale], sessionId: String, customerId: String? = nil) async throws {
        let saleEventRequest = SdkSaleEventRequest(
            marketplaceUuid: marketplaceId,
            sessionId: sessionId,
            eventType: .sale,
            sales: sales,
            customerId: customerId
        )

        try await sendSdkSaleEvent(saleEventRequest)
    }

    // MARK: - Private Methods

    /// Send impression/click events via GET /sdk/events
    private func sendSdkEvent(type: EventType, adId: String, sessionId: String) async throws {
        guard let baseUrl = baseUrl else {
            throw EventManagerError.configurationError(message: "Base URL not configured. Call configure() first.")
        }

        // Build URL with query parameters for /sdk/events endpoint
        guard var urlComponents = URLComponents(url: baseUrl.appendingPathComponent("sdk/events"), resolvingAgainstBaseURL: false) else {
            throw EventManagerError.configurationError(message: "Invalid base URL configuration.")
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "type", value: type.rawValue),
            URLQueryItem(name: "ad_id", value: adId)
        ]

        guard let url = urlComponents.url else {
            throw EventManagerError.configurationError(message: "Failed to construct event URL.")
        }

        // Send GET request
        do {
            _ = try await client.asyncGet(url: url, timeoutInterval: 30)
        } catch {
            throw EventManagerError.http(error: error)
        }
    }

    /// Send sale events via POST /sdk/sale_events
    private func sendSdkSaleEvent(_ saleEventRequest: SdkSaleEventRequest) async throws {
        guard let baseUrl = baseUrl else {
            throw EventManagerError.configurationError(message: "Base URL not configured. Call configure() first.")
        }

        let url = baseUrl.appendingPathComponent("sdk/sale_events")

        // Serialize the sale event request
        guard let requestData = try? JSONEncoder().encode(saleEventRequest) else {
            throw EventManagerError.serializationError
        }

        // Send POST request
        do {
            _ = try await client.asyncPost(url: url, data: requestData, timeoutInterval: 30)
        } catch {
            throw EventManagerError.http(error: error)
        }
    }
}
