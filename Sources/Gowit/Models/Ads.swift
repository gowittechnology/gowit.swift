import Foundation

// MARK: - Ad Request Models

public struct AdRequest: Codable {
    public let marketplaceId: String
    public let customer: Customer?
    public let products: [Product]?
    public let search: String?
    public let category: String?
    public let categoryId: String?
    public let placements: [PlacementRequest]
    public let maxAds: Int?
    public let filters: [String]?
    public let pageNumber: Int?
    public let sessionId: String
    public let locationId: String?
    public let regionId: String?
    public let language: String?

    public init(
        marketplaceId: String,
        placements: [PlacementRequest],
        sessionId: String,
        customer: Customer? = nil,
        products: [Product]? = nil,
        search: String? = nil,
        category: String? = nil,
        categoryId: String? = nil,
        maxAds: Int? = nil,
        filters: [String]? = nil,
        pageNumber: Int? = nil,
        locationId: String? = nil,
        regionId: String? = nil,
        language: String? = nil
    ) {
        self.marketplaceId = marketplaceId
        self.customer = customer
        self.products = products
        self.search = search
        self.category = category
        self.categoryId = categoryId
        self.placements = placements
        self.maxAds = maxAds
        self.filters = filters
        self.pageNumber = pageNumber
        self.sessionId = sessionId
        self.locationId = locationId
        self.regionId = regionId
        self.language = language
    }

    enum CodingKeys: String, CodingKey {
        case marketplaceId = "marketplace_id"
        case customer
        case products
        case search
        case category
        case categoryId = "category_id"
        case placements
        case maxAds = "max_ads"
        case filters
        case pageNumber = "page_number"
        case sessionId = "session_id"
        case locationId = "location_id"
        case regionId = "region_id"
        case language
    }
}

public struct Customer: Codable {
    public let customerId: String?
    public let gender: String?
    public let age: Int?
    public let city: String?
    public let deviceType: String?

    public init(
        customerId: String? = nil,
        gender: String? = nil,
        age: Int? = nil,
        city: String? = nil,
        deviceType: String? = nil,
    ) {
        self.customerId = customerId
        self.gender = gender
        self.age = age
        self.city = city
        self.deviceType = deviceType
    }

    enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case gender
        case age
        case city
        case deviceType = "device_type"
    }
}

public struct Product: Codable {
    public let productId: String?
    public let category: String?

    public init(productId: String? = nil, category: String? = nil) {
        self.productId = productId
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case category
    }
}

/// Represents a filter group where each inner array is treated as an OR-group,
/// and the outer array applies AND semantics across those groups.
///
/// Example: `[["brand:samsung", "brand:apple"], ["color:black", "color:white"]]`
/// means "(brand is Samsung OR Apple) AND (color is Black OR White)"
public struct PlacementRequest: Codable {
    public let placementId: Int
    public let placementIdentifier: String?
    /// Filters is an array of arrays where:
    /// - Each inner array represents an OR-group of filter strings
    /// - The outer array applies AND semantics across those groups
    /// - Example: `[["brand:samsung", "brand:apple"], ["color:black", "color:white"]]`
    ///   means "(brand is Samsung OR Apple) AND (color is Black OR White)"
    public let filters: [[String]]?
    public let maxAds: Int?

    public init(
        placementId: Int,
        placementIdentifier: String? = nil,
        filters: [[String]]? = nil,
        maxAds: Int? = nil
    ) {
        self.placementId = placementId
        self.placementIdentifier = placementIdentifier
        self.filters = filters
        self.maxAds = maxAds
    }

    enum CodingKeys: String, CodingKey {
        case placementId = "placement_id"
        case placementIdentifier = "placement_identifier"
        case filters
        case maxAds = "max_ads"
    }
}

// MARK: - Ad Response Models

public struct AdResponse: Codable {
    public let responseId: String
    public let placements: [Placement]?

    public init(
        responseId: String,
        placements: [Placement]? = nil,
    ) {
        self.responseId = responseId
        self.placements = placements
    }

    // MARK: - Convenience Methods

    /// Get ads for a specific placement ID
    public func getAds(for placementId: Int) -> [Ad]? {
        return placements?.first { $0.placementId == placementId }?.ads
    }

    /// Get all ads from all placements as a flat array
    public var allAds: [Ad] {
        return placements?.flatMap { $0.ads ?? [] } ?? []
    }

    /// Get placement by ID
    public func getPlacement(id: Int) -> Placement? {
        return placements?.first { $0.placementId == id }
    }

    /// Check if a specific placement has ads
    public func hasAds(for placementId: Int) -> Bool {
        return getAds(for: placementId)?.isEmpty == false
    }

    /// Get the number of ads for a specific placement
    public func adCount(for placementId: Int) -> Int {
        return getAds(for: placementId)?.count ?? 0
    }

    // MARK: - Product Ad Convenience Methods

    /// Get all product ads from all placements
    public var allProductAds: [Ad] {
        return allAds.filter { $0.isProductAd }
    }

    /// Get all display ads from all placements
    public var allDisplayAds: [Ad] {
        return allAds.filter { $0.isDisplayAd }
    }

    /// Get product ads for a specific placement ID
    public func getProductAds(for placementId: Int) -> [Ad]? {
        return getAds(for: placementId)?.filter { $0.isProductAd }
    }

    /// Get display ads for a specific placement ID
    public func getDisplayAds(for placementId: Int) -> [Ad]? {
        return getAds(for: placementId)?.filter { $0.isDisplayAd }
    }

    /// Check if a specific placement has product ads
    public func hasProductAds(for placementId: Int) -> Bool {
        return getProductAds(for: placementId)?.isEmpty == false
    }

    /// Check if a specific placement has display ads
    public func hasDisplayAds(for placementId: Int) -> Bool {
        return getDisplayAds(for: placementId)?.isEmpty == false
    }

    /// Get the number of product ads for a specific placement
    public func productAdCount(for placementId: Int) -> Int {
        return getProductAds(for: placementId)?.count ?? 0
    }

    /// Get the number of display ads for a specific placement
    public func displayAdCount(for placementId: Int) -> Int {
        return getDisplayAds(for: placementId)?.count ?? 0
    }

    /// Get all unique SKUs from product ads
    public var allSKUs: [String] {
        return Array(Set(allProductAds.compactMap { $0.sku }))
    }

    /// Get SKUs for product ads in a specific placement
    public func getSKUs(for placementId: Int) -> [String] {
        return getProductAds(for: placementId)?.compactMap { $0.sku } ?? []
    }

    enum CodingKeys: String, CodingKey {
        case responseId = "response_id"
        case placements
    }
}

public struct Placement: Codable {
    public let placementId: Int
    public let placementIdentifier: String?
    public let ads: [Ad]?

    public init(placementId: Int, placementIdentifier: String? = nil, ads: [Ad]? = nil) {
        self.placementId = placementId
        self.placementIdentifier = placementIdentifier
        self.ads = ads
    }

    // MARK: - Convenience Methods

    /// Check if this placement has ads
    public var hasAds: Bool {
        return ads?.isEmpty == false
    }

    /// Get the number of ads in this placement
    public var adCount: Int {
        return ads?.count ?? 0
    }

    /// Get the first ad in this placement
    public var firstAd: Ad? {
        return ads?.first
    }

    enum CodingKeys: String, CodingKey {
        case placementId = "placement_id"
        case placementIdentifier = "placement_identifier"
        case ads
    }
}

public struct Ad: Codable {
    public let adId: String?
    public let productId: String?
    public let creativeId: Int?
    public let imgUrl: String?
    public let videoUrl: String?
    public let vastTag: String?
    public let duration: Int?
    public let size: String?
    public let redirect: Redirect?
    public let position: Int?
    public let advertiserId: String?
    public let products: [PromotedProduct]?
    public let language: String?
    public let html: String?

    public init(
        adId: String? = nil,
        productId: String? = nil,
        creativeId: Int? = nil,
        imgUrl: String? = nil,
        videoUrl: String? = nil,
        vastTag: String? = nil,
        duration: Int? = nil,
        size: String? = nil,
        redirect: Redirect? = nil,
        position: Int? = nil,
        advertiserId: String? = nil,
        products: [PromotedProduct]? = nil,
        language: String? = nil,
        html: String? = nil
    ) {
        self.adId = adId
        self.productId = productId
        self.creativeId = creativeId
        self.imgUrl = imgUrl
        self.videoUrl = videoUrl
        self.vastTag = vastTag
        self.duration = duration
        self.size = size
        self.redirect = redirect
        self.position = position
        self.advertiserId = advertiserId
        self.products = products
        self.language = language
        self.html = html
    }

    // MARK: - Ad Type Detection Methods

    /// Determines if this ad is a Sponsored Product ad.
    /// A product ad contains a product_id (SKU) that customers can use to query product details.
    public var isProductAd: Bool {
        return productId != nil && !productId!.isEmpty
    }

    /// Determines if this ad is a Sponsored Display ad.
    /// A display ad contains img_url, html, or redirect information for direct display.
    public var isDisplayAd: Bool {
        return (imgUrl != nil && !imgUrl!.isEmpty) ||
               (html != nil && !html!.isEmpty) ||
               redirect != nil
    }

    /// Returns the SKU (product ID) if this is a product ad.
    /// The SKU can be used by customers to query their catalog for product details.
    public var sku: String? {
        return isProductAd ? productId : nil
    }

    /// Returns the display URL for this ad if it's a display ad.
    /// This is the image URL that should be displayed to users.
    public var displayImageUrl: String? {
        return isDisplayAd ? imgUrl : nil
    }

    /// Returns the click URL for this ad if it has redirect information.
    public var clickUrl: String? {
        return redirect?.url
    }

    enum CodingKeys: String, CodingKey {
        case adId = "ad_id"
        case productId = "product_id"
        case creativeId = "creative_id"
        case imgUrl = "img_url"
        case videoUrl = "video_url"
        case vastTag = "vast_tag"
        case duration
        case size
        case redirect
        case position
        case advertiserId = "advertiser_id"
        case products
        case language
        case html
    }
}

public struct Redirect: Codable {
    public let url: String
    public let type: String

    public init(url: String, type: String) {
        self.url = url
        self.type = type
    }
}

public struct PromotedProduct: Codable {
    public let name: String?
    public let sku: String?
    public let imageUrl: String?
    public let rating: Double?
    public let price: Double?
    public let stockCount: Int?
    public let advertiserId: String?

    public init(
        name: String? = nil,
        sku: String? = nil,
        imageUrl: String? = nil,
        rating: Double? = nil,
        price: Double? = nil,
        stockCount: Int? = nil,
        advertiserId: String? = nil
    ) {
        self.name = name
        self.sku = sku
        self.imageUrl = imageUrl
        self.rating = rating
        self.price = price
        self.stockCount = stockCount
        self.advertiserId = advertiserId
    }

    enum CodingKeys: String, CodingKey {
        case name
        case sku
        case imageUrl = "image_url"
        case rating
        case price
        case stockCount = "stock_count"
        case advertiserId = "advertiser_id"
    }
}
