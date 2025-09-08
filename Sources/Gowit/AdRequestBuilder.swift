import Foundation

public struct ProductRequest {
    public let productId: String
    public let category: String?

    public init(productId: String, category: String? = nil) {
        self.productId = productId
        self.category = category
    }
}

public struct AdRequestBuilder {
    public let placements: [PlacementRequest]
    public var pageNumber: Int = 0
    public var sessionId: String?
    public var customer: Customer?
    public var products: [ProductRequest]?
    public var search: String?
    public var category: String?
    public var categoryId: String?
    public var maxAds: Int?
    public var filters: [String]?
    public var locationId: String?
    public var regionId: String?
    public var language: String?

    public init(placements: [PlacementRequest]) {
        self.placements = placements
    }

    public init(placementId: Int) {
        self.placements = [PlacementRequest(placementId: placementId)]
    }

    public init(placementIds: [Int]) {
        self.placements = placementIds.map { PlacementRequest(placementId: $0) }
    }

    public func with(pageNumber: Int) -> AdRequestBuilder {
        var builder = self
        builder.pageNumber = pageNumber
        return builder
    }

    public func with(sessionId: String) -> AdRequestBuilder {
        var builder = self
        builder.sessionId = sessionId
        return builder
    }

    public func with(customer: Customer) -> AdRequestBuilder {
        var builder = self
        builder.customer = customer
        return builder
    }

    public func with(products: [ProductRequest]) -> AdRequestBuilder {
        var builder = self
        builder.products = products
        return builder
    }

    public func with(search: String) -> AdRequestBuilder {
        var builder = self
        builder.search = search
        return builder
    }

    public func with(category: String) -> AdRequestBuilder {
        var builder = self
        builder.category = category
        return builder
    }

    public func with(categoryId: String) -> AdRequestBuilder {
        var builder = self
        builder.categoryId = categoryId
        return builder
    }

    public func with(maxAds: Int) -> AdRequestBuilder {
        var builder = self
        builder.maxAds = maxAds
        return builder
    }

    public func with(filters: [String]) -> AdRequestBuilder {
        var builder = self
        builder.filters = filters
        return builder
    }

    public func with(locationId: String) -> AdRequestBuilder {
        var builder = self
        builder.locationId = locationId
        return builder
    }

    public func with(regionId: String) -> AdRequestBuilder {
        var builder = self
        builder.regionId = regionId
        return builder
    }

    public func with(language: String) -> AdRequestBuilder {
        var builder = self
        builder.language = language
        return builder
    }
}
