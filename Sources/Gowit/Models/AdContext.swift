import Foundation

/// Request context shared by ad requests and sponsored display views.
///
/// Holds everything an ad request carries except the placements themselves.
/// Set an app-wide default once with `Gowit.shared.defaultContext` and pass a
/// per-request or per-view context to override parts of it:
/// - Non-nil fields of the more specific context win.
/// - `customer` is merged field by field, so a per-view `Customer(city: "Riyadh")`
///   keeps the default `customerId`.
/// - Arrays (`products`, `filters`, `Customer.segments`) are replaced, not concatenated.
///
/// ```swift
/// Gowit.shared.defaultContext = AdContext(
///     customer: Customer(customerId: "42"),
///     language: "AR",
///     sessionId: session.id
/// )
/// ```
public struct AdContext: Equatable {
    public var customer: Customer?
    public var language: String?
    public var locationId: String?
    public var regionId: String?
    public var search: String?
    public var category: String?
    public var categoryId: String?
    public var products: [Product]?
    /// Request-level filters. Placement-level filters belong on `PlacementRequest.filters`.
    public var filters: [String]?
    public var pageNumber: Int?
    /// Session ID used when a request or view does not pass one explicitly.
    public var sessionId: String?

    public init(
        customer: Customer? = nil,
        language: String? = nil,
        locationId: String? = nil,
        regionId: String? = nil,
        search: String? = nil,
        category: String? = nil,
        categoryId: String? = nil,
        products: [Product]? = nil,
        filters: [String]? = nil,
        pageNumber: Int? = nil,
        sessionId: String? = nil
    ) {
        self.customer = customer
        self.language = language
        self.locationId = locationId
        self.regionId = regionId
        self.search = search
        self.category = category
        self.categoryId = categoryId
        self.products = products
        self.filters = filters
        self.pageNumber = pageNumber
        self.sessionId = sessionId
    }

    /// Returns a context where this context's non-nil values take precedence over `base`.
    public func merged(over base: AdContext?) -> AdContext {
        guard let base = base else { return self }
        return AdContext(
            customer: Customer.merge(customer, over: base.customer),
            language: language ?? base.language,
            locationId: locationId ?? base.locationId,
            regionId: regionId ?? base.regionId,
            search: search ?? base.search,
            category: category ?? base.category,
            categoryId: categoryId ?? base.categoryId,
            products: products ?? base.products,
            filters: filters ?? base.filters,
            pageNumber: pageNumber ?? base.pageNumber,
            sessionId: sessionId ?? base.sessionId
        )
    }
}

extension Customer {
    /// Merges two customers field by field; non-nil values of `customer` win over `base`.
    public static func merge(_ customer: Customer?, over base: Customer?) -> Customer? {
        guard let customer = customer else { return base }
        guard let base = base else { return customer }
        return Customer(
            customerId: customer.customerId ?? base.customerId,
            gender: customer.gender ?? base.gender,
            age: customer.age ?? base.age,
            city: customer.city ?? base.city,
            deviceType: customer.deviceType ?? base.deviceType,
            id: customer.id ?? base.id,
            environmentType: customer.environmentType ?? base.environmentType,
            ip: customer.ip ?? base.ip,
            segments: customer.segments ?? base.segments,
            userAgent: customer.userAgent ?? base.userAgent
        )
    }
}
