import Foundation

public protocol GowitProtocol {

    func configure(hostname: String, marketplaceId: String)
    func configure(hostname: String, marketplaceId: String, autoImpressionEnabled: Bool)

    // Multiple placements
    func getAds(placements: [PlacementRequest], pageNumber: Int?, sessionId: String?) async throws -> AdResponse

    // Single placement convenience method
    func getAds(placementId: Int, pageNumber: Int?, sessionId: String?) async throws -> AdResponse

    // New builder-based API
    func getAds(_ builder: AdRequestBuilder) async throws -> AdResponse

    // Event methods
    func sendImpressionEvent(adId: String, sessionId: String) async throws
    func sendViewableImpressionEvent(adId: String, sessionId: String) async throws
    func sendClickEvent(adId: String, sessionId: String) async throws
    func sendSaleEvent(sales: [Sale], sessionId: String, customerId: String?) async throws
}

public class Gowit: GowitProtocol {
    public static let shared = Gowit()

    private var hostname: String = "https://platform-stage.gowit.com"
    private var marketplaceId: String = "SET_MARKETPLACE_UUID"
    private var autoImpressionEnabled: Bool = false

    private init() {}

    public func configure(hostname: String, marketplaceId: String) {
        configure(hostname: hostname, marketplaceId: marketplaceId, autoImpressionEnabled: false)
    }

    public func configure(hostname: String, marketplaceId: String, autoImpressionEnabled: Bool) {
        self.hostname = hostname
        self.marketplaceId = marketplaceId
        self.autoImpressionEnabled = autoImpressionEnabled

        // Configure managers with the new settings
        AdManager.shared.configure(hostname: hostname, marketplaceId: marketplaceId)
        EventManager.shared.configure(hostname: hostname, marketplaceId: marketplaceId, autoImpressionEnabled: autoImpressionEnabled)
    }

    // MARK: - Ad Request Methods

    /// Request ads for multiple placements
    public func getAds(placements: [PlacementRequest], pageNumber: Int? = nil, sessionId: String? = nil) async throws -> AdResponse {
        return try await AdManager.shared.getAds(placements: placements, pageNumber: pageNumber, sessionId: sessionId)
    }

    /// Request ads for a single placement (convenience method)
    public func getAds(placementId: Int, pageNumber: Int? = nil, sessionId: String? = nil) async throws -> AdResponse {
        let placement = PlacementRequest(placementId: placementId)
        return try await getAds(placements: [placement], pageNumber: pageNumber, sessionId: sessionId)
    }

    /// Request ads using the builder pattern for cleaner API
    public func getAds(_ builder: AdRequestBuilder) async throws -> AdResponse {
        // Convert ProductRequest to Product if needed
        let products: [Product]? = builder.products?.map { productReq in
            Product(productId: productReq.productId, category: productReq.category)
        }

        // Create AdRequest with all builder parameters
        let request = AdRequest(
            marketplaceId: self.marketplaceId,
            placements: builder.placements,
            sessionId: builder.sessionId ?? UUID().uuidString,
            customer: builder.customer,
            products: products,
            search: builder.search,
            category: builder.category,
            categoryId: builder.categoryId,
            maxAds: builder.maxAds,
            filters: builder.filters,
            pageNumber: builder.pageNumber,
            locationId: builder.locationId,
            regionId: builder.regionId,
        )

        return try await AdManager.shared.getAds(request: request)
    }

    // MARK: - Event Reporting Methods

    /// Send impression event
    public func sendImpressionEvent(adId: String, sessionId: String) async throws {
        try await EventManager.shared.sendImpressionEvent(adId: adId, sessionId: sessionId)
    }

    /// Send viewable impression event
    public func sendViewableImpressionEvent(adId: String, sessionId: String) async throws {
        try await EventManager.shared.sendViewableImpressionEvent(adId: adId, sessionId: sessionId)
    }

    /// Send click event
    public func sendClickEvent(adId: String, sessionId: String) async throws {
        try await EventManager.shared.sendClickEvent(adId: adId, sessionId: sessionId)
    }

    /// Send sale event
    public func sendSaleEvent(sales: [Sale], sessionId: String, customerId: String? = nil) async throws {
        try await EventManager.shared.sendSaleEvent(sales: sales, sessionId: sessionId, customerId: customerId)
    }

    /// Convenience method to send impression event for an Ad object (bypasses auto impression)
    public func sendImpressionEvent(for ad: Ad, sessionId: String) async throws {
        guard let adId = ad.adId else {
            throw AdError.invalidAdId
        }
        try await sendImpressionEvent(adId: adId, sessionId: sessionId)
    }

    /// Convenience method to send viewable impression event for an Ad object
    public func sendViewableImpressionEvent(for ad: Ad, sessionId: String) async throws {
        guard let adId = ad.adId else {
            throw AdError.invalidAdId
        }
        try await sendViewableImpressionEvent(adId: adId, sessionId: sessionId)
    }

    /// Convenience method to send click event for an Ad object
    public func sendClickEvent(for ad: Ad, sessionId: String) async throws {
        guard let adId = ad.adId else {
            throw AdError.invalidAdId
        }
        try await sendClickEvent(adId: adId, sessionId: sessionId)
    }

}
