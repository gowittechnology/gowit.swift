import XCTest
@testable import Gowit

final class AdContextTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Gowit.shared.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )
        Gowit.shared.defaultContext = nil
    }

    override func tearDown() {
        Gowit.shared.defaultContext = nil
        super.tearDown()
    }

    // MARK: - Merge Rules

    func testMergedOverNilBaseReturnsSelf() {
        let context = AdContext(language: "AR")
        XCTAssertEqual(context.merged(over: nil), context)
    }

    func testSpecificValuesWinAndMissingValuesFallBack() {
        let base = AdContext(
            language: "EN",
            locationId: "1",
            regionId: "10",
            category: "Burgers",
            filters: ["brand:a"],
            pageNumber: 2,
            sessionId: "base-session"
        )
        let specific = AdContext(language: "AR", search: "pizza", sessionId: "view-session")

        let merged = specific.merged(over: base)

        XCTAssertEqual(merged.language, "AR")
        XCTAssertEqual(merged.search, "pizza")
        XCTAssertEqual(merged.sessionId, "view-session")
        XCTAssertEqual(merged.locationId, "1")
        XCTAssertEqual(merged.regionId, "10")
        XCTAssertEqual(merged.category, "Burgers")
        XCTAssertEqual(merged.filters, ["brand:a"])
        XCTAssertEqual(merged.pageNumber, 2)
    }

    func testCustomerIsMergedFieldByField() {
        let base = AdContext(customer: Customer(customerId: "42", city: "Jeddah", segments: ["vip"]))
        let specific = AdContext(customer: Customer(city: "Riyadh", deviceType: "MOBILE"))

        let customer = specific.merged(over: base).customer

        XCTAssertEqual(customer?.customerId, "42")
        XCTAssertEqual(customer?.city, "Riyadh")
        XCTAssertEqual(customer?.deviceType, "MOBILE")
        XCTAssertEqual(customer?.segments, ["vip"])
    }

    func testCustomerMergeHandlesNilSides() {
        let customer = Customer(customerId: "42")
        XCTAssertEqual(Customer.merge(customer, over: nil), customer)
        XCTAssertEqual(Customer.merge(nil, over: customer), customer)
        XCTAssertNil(Customer.merge(nil, over: nil))
    }

    func testArraysAreReplacedNotConcatenated() {
        let base = AdContext(products: [Product(productId: "1")], filters: ["a"])
        let specific = AdContext(products: [Product(productId: "2")])

        let merged = specific.merged(over: base)

        XCTAssertEqual(merged.products, [Product(productId: "2")])
        XCTAssertEqual(merged.filters, ["a"])
    }

    // MARK: - Builder

    func testBuilderWithContextOverridesValuesAndMergesCustomer() {
        let builder = AdRequestBuilder(placementId: 8)
            .with(customer: Customer(customerId: "42"))
            .with(language: "EN")
            .with(context: AdContext(
                customer: Customer(city: "Riyadh"),
                language: "AR",
                regionId: "5",
                products: [Product(productId: "p1", categories: ["Burgers", "Fast Food"])]
            ))

        XCTAssertEqual(builder.language, "AR")
        XCTAssertEqual(builder.regionId, "5")
        XCTAssertEqual(builder.customer?.customerId, "42")
        XCTAssertEqual(builder.customer?.city, "Riyadh")
        XCTAssertEqual(builder.products?.first?.categories, ["Burgers", "Fast Food"])
    }

    func testBuilderLanguageReachesTheRequest() {
        let builder = AdRequestBuilder(placementId: 8).with(language: "AR")
        let request = Gowit.shared.buildRequest(placements: builder.placements, context: builder.toAdContext())
        XCTAssertEqual(request.language, "AR")
    }

    // MARK: - Request Encoding

    private func encodedRequest(_ context: AdContext) throws -> [String: Any] {
        let request = Gowit.shared.buildRequest(
            placements: [PlacementRequest(placementId: 8, maxAds: 1)],
            context: context
        )
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEncodesEveryContextFieldWithApiFieldNames() throws {
        let json = try encodedRequest(AdContext(
            customer: Customer(
                customerId: "42",
                gender: "F",
                age: 30,
                city: "Riyadh",
                deviceType: "MOBILE",
                id: "u1",
                environmentType: "APP",
                ip: "10.0.0.1",
                segments: ["vip"],
                userAgent: "HungerStation/1.0"
            ),
            language: "AR",
            locationId: "3",
            regionId: "4",
            search: "burger",
            category: "Burgers",
            categoryId: "7",
            products: [Product(productId: "p1", categories: ["Burgers", "Fast Food"], categoryIdStructures: ["7", "1"])],
            filters: ["brand:a"],
            pageNumber: 2,
            sessionId: "s1"
        ))

        XCTAssertEqual(json["session_id"] as? String, "s1")
        XCTAssertEqual(json["language"] as? String, "AR")
        XCTAssertEqual(json["location_id"] as? String, "3")
        XCTAssertEqual(json["region_id"] as? String, "4")
        XCTAssertEqual(json["search"] as? String, "burger")
        XCTAssertEqual(json["category"] as? String, "Burgers")
        XCTAssertEqual(json["category_id"] as? String, "7")
        XCTAssertEqual(json["page_number"] as? Int, 2)
        XCTAssertEqual(json["filters"] as? [String], ["brand:a"])

        let customer = try XCTUnwrap(json["customer"] as? [String: Any])
        XCTAssertEqual(customer["id"] as? String, "u1")
        XCTAssertEqual(customer["customer_id"] as? String, "42")
        XCTAssertEqual(customer["gender"] as? String, "F")
        XCTAssertEqual(customer["age"] as? Int, 30)
        XCTAssertEqual(customer["city"] as? String, "Riyadh")
        XCTAssertEqual(customer["device_type"] as? String, "MOBILE")
        XCTAssertEqual(customer["environment_type"] as? String, "APP")
        XCTAssertEqual(customer["ip"] as? String, "10.0.0.1")
        XCTAssertEqual(customer["segments"] as? [String], ["vip"])
        XCTAssertEqual(customer["user_agent"] as? String, "HungerStation/1.0")

        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        XCTAssertEqual(products.first?["id"] as? String, "p1")
        XCTAssertNil(products.first?["product_id"])
        XCTAssertEqual(products.first?["categories"] as? [String], ["Burgers", "Fast Food"])
        XCTAssertEqual(products.first?["category_id_structures"] as? [String], ["7", "1"])

        let placement = try XCTUnwrap((json["placements"] as? [[String: Any]])?.first)
        XCTAssertEqual(placement["placement_id"] as? Int, 8)
        XCTAssertEqual(placement["max_ads"] as? Int, 1)
    }

    func testOmitsUnsetFields() throws {
        let json = try encodedRequest(AdContext(sessionId: "s1"))

        XCTAssertNil(json["customer"])
        XCTAssertNil(json["language"])
        XCTAssertNil(json["region_id"])
        XCTAssertNil(json["page_number"])
    }

    func testGeneratesSessionIdWhenNoneIsSet() throws {
        let json = try encodedRequest(AdContext())
        XCTAssertFalse((json["session_id"] as? String ?? "").isEmpty)
    }

    func testDefaultContextIsReadableAndClearable() {
        Gowit.shared.defaultContext = AdContext(language: "AR")
        XCTAssertEqual(Gowit.shared.defaultContext?.language, "AR")

        Gowit.shared.defaultContext = nil
        XCTAssertNil(Gowit.shared.defaultContext)
    }
}
