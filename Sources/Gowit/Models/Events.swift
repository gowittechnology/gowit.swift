import Foundation

// MARK: - Event Types

public enum EventType: String, Codable, CaseIterable {
    case impression = "impression"
    case viewableImpression = "viewable_impression"
    case click = "click"
    case sale = "sale"
}

// MARK: - SDK Event Request Models

/// Request model for sale events sent to /sdk/sale_events endpoint
public struct SdkSaleEventRequest: Codable {
    public let marketplaceUuid: String?
    public let sessionId: String
    public let eventType: EventType
    public let sales: [Sale]
    public let customerId: String?
    public let requestId: String?
    public let time: String?

    public init(
        marketplaceUuid: String?,
        sessionId: String,
        eventType: EventType = .sale,
        sales: [Sale],
        customerId: String? = nil,
        requestId: String? = nil,
        time: String? = nil
    ) {
        self.marketplaceUuid = marketplaceUuid
        self.sessionId = sessionId
        self.eventType = eventType
        self.sales = sales
        self.customerId = customerId
        self.requestId = requestId
        self.time = time
    }

    enum CodingKeys: String, CodingKey {
        case marketplaceUuid = "marketplace_uuid"
        case sessionId = "session_id"
        case eventType = "event_type"
        case sales
        case customerId = "customer_id"
        case requestId = "request_id"
        case time
    }
}

// MARK: - Legacy Event Request Model (for backward compatibility)

public struct EventRequest: Codable {
    public let marketplaceId: String
    public let eventType: EventType
    public let adId: String?
    public let sessionId: String
    public let sales: [Sale]?

    public init(
        marketplaceId: String,
        eventType: EventType,
        sessionId: String,
        adId: String? = nil,
        sales: [Sale]? = nil
    ) {
        self.marketplaceId = marketplaceId
        self.eventType = eventType
        self.sessionId = sessionId
        self.adId = adId
        self.sales = sales
    }

    enum CodingKeys: String, CodingKey {
        case marketplaceId = "marketplace_id"
        case eventType = "event_type"
        case adId = "ad_id"
        case sessionId = "session_id"
        case sales
    }
}

// MARK: - Sale Model

public struct Sale: Codable {
    public let advertiserId: String
    public let quantity: Int
    public let unitPrice: Double
    public let productId: String

    public init(
        advertiserId: String,
        quantity: Int,
        unitPrice: Double,
        productId: String
    ) {
        self.advertiserId = advertiserId
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.productId = productId
    }

    enum CodingKeys: String, CodingKey {
        case advertiserId = "advertiser_id"
        case quantity
        case unitPrice = "unit_price"
        case productId = "product_id"
    }
}
