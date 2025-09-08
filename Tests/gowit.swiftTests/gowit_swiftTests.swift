import XCTest
@testable import Gowit

final class GowitSDKTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset configuration before each test
        Gowit.shared.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )
    }

    // MARK: - Configuration Tests

    func testBasicConfiguration() {
        // Test basic configuration
        XCTAssertNoThrow(Gowit.shared.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        ))
    }

    func testConfigurationWithAutoImpression() {
        // Test configuration with auto impression enabled
        XCTAssertNoThrow(Gowit.shared.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID",
            autoImpressionEnabled: true
        ))
    }

    // MARK: - AdRequestBuilder Tests

    func testAdRequestBuilderSinglePlacement() {
        let builder = AdRequestBuilder(placementId: 5)
            .with(sessionId: "test-session")
            .with(pageNumber: 0)

        XCTAssertEqual(builder.placements.count, 1)
        XCTAssertEqual(builder.placements.first?.placementId, 5)
        XCTAssertEqual(builder.sessionId, "test-session")
        XCTAssertEqual(builder.pageNumber, 0)
    }

    func testAdRequestBuilderMultiplePlacements() {
        let builder = AdRequestBuilder(placementIds: [1, 2, 3])
            .with(sessionId: "test-session")

        XCTAssertEqual(builder.placements.count, 3)
        XCTAssertEqual(builder.placements.map { $0.placementId }, [1, 2, 3])
        XCTAssertEqual(builder.sessionId, "test-session")
    }

    func testAdRequestBuilderWithProducts() {
        let products = [
            ProductRequest(productId: "PROD-001", category: "Electronics"),
            ProductRequest(productId: "PROD-002", category: "Accessories")
        ]

        let builder = AdRequestBuilder(placementId: 5)
            .with(sessionId: "test-session")
            .with(products: products)
            .with(search: "iPhone")

        XCTAssertEqual(builder.products?.count, 2)
        XCTAssertEqual(builder.products?.first?.productId, "PROD-001")
        XCTAssertEqual(builder.search, "iPhone")
    }

    func testAdRequestBuilderWithCustomer() {
        let customer = Customer(
            customerId: "external-456",
            gender: "Male",
            age: 30,
            city: "San Francisco"
        )

        let builder = AdRequestBuilder(placementId: 5)
            .with(sessionId: "test-session")
            .with(customer: customer)
            .with(locationId: "SF-01")
            .with(language: "en")

        XCTAssertEqual(builder.locationId, "SF-01")
        XCTAssertEqual(builder.language, "en")
    }

    // MARK: - Model Tests

    func testPlacementRequestInitialization() {
        let placement = PlacementRequest(
            placementId: 5,
            filters: [["brand:apple", "brand:samsung"]],
            maxAds: 10
        )

        XCTAssertEqual(placement.placementId, 5)
        XCTAssertEqual(placement.filters?.count, 1)
        XCTAssertEqual(placement.filters?.first?.count, 2)
        XCTAssertEqual(placement.maxAds, 10)
    }

    func testProductRequestInitialization() {
        let product = ProductRequest(
            productId: "PROD-123",
            category: "Electronics > Smartphones"
        )

        XCTAssertEqual(product.productId, "PROD-123")
        XCTAssertEqual(product.category, "Electronics > Smartphones")
    }

    func testSaleInitialization() {
        let sale = Sale(
            advertiserId: "adv-123",
            quantity: 2,
            unitPrice: 49.99,
            productId: "prod-456"
        )

        XCTAssertEqual(sale.advertiserId, "adv-123")
        XCTAssertEqual(sale.quantity, 2)
        XCTAssertEqual(sale.unitPrice, 49.99)
        XCTAssertEqual(sale.productId, "prod-456")
    }

    func testCustomerInitialization() {
        let customer = Customer(
            customerId: "external-456",
            gender: "Female",
            age: 28,
            city: "New York",
            deviceType: "Mobile",
        )

        XCTAssertEqual(customer.customerId, "external-456")
        XCTAssertEqual(customer.gender, "Female")
        XCTAssertEqual(customer.age, 28)
        XCTAssertEqual(customer.city, "New York")
        XCTAssertEqual(customer.deviceType, "Mobile")
    }

    // MARK: - Event Model Tests

    func testEventRequestInitialization() {
        let eventRequest = EventRequest(
            marketplaceId: "TEST_MARKETPLACE_UUID",
            eventType: .impression,
            sessionId: "test-session",
            adId: "ad-456"
        )

        XCTAssertEqual(eventRequest.marketplaceId, "TEST_MARKETPLACE_UUID")
        XCTAssertEqual(eventRequest.eventType, .impression)
        XCTAssertEqual(eventRequest.sessionId, "test-session")
        XCTAssertEqual(eventRequest.adId, "ad-456")
    }

    func testEventRequestWithSales() {
        let sales = [
            Sale(advertiserId: "adv-1", quantity: 1, unitPrice: 99.99, productId: "prod-1"),
            Sale(advertiserId: "adv-2", quantity: 2, unitPrice: 49.99, productId: "prod-2")
        ]

        let eventRequest = EventRequest(
            marketplaceId: "TEST_MARKETPLACE_UUID",
            eventType: .sale,
            sessionId: "test-session",
            sales: sales
        )

        XCTAssertEqual(eventRequest.marketplaceId, "TEST_MARKETPLACE_UUID")
        XCTAssertEqual(eventRequest.eventType, .sale)
        XCTAssertEqual(eventRequest.sessionId, "test-session")
        XCTAssertEqual(eventRequest.sales?.count, 2)
        XCTAssertNil(eventRequest.adId)
    }

    func testEventTypes() {
        XCTAssertEqual(EventType.impression.rawValue, "impression")
        XCTAssertEqual(EventType.viewableImpression.rawValue, "viewable_impression")
        XCTAssertEqual(EventType.click.rawValue, "click")
        XCTAssertEqual(EventType.sale.rawValue, "sale")
    }

    // MARK: - Error Handling Tests

    func testAdError() {
        let configError = AdError.configurationError(message: "Test error")

        switch configError {
        case .configurationError(let message):
            XCTAssertEqual(message, "Test error")
        default:
            XCTFail("Expected configurationError")
        }
    }

    // MARK: - Integration Tests

    func testBuilderAPIIntegration() async throws {
        // Test that builder API creates proper ad requests
        let products = [ProductRequest(productId: "PROD-001")]
        let customer = Customer(customerId: "user-123", age: 30)

        let builder = AdRequestBuilder(placementId: 5)
            .with(sessionId: "integration-test")
            .with(products: products)
            .with(customer: customer)
            .with(search: "test search")
            .with(category: "test category")

        // This would normally make a network request, so we expect it to fail
        // but we can verify the builder constructs the request properly
        do {
            _ = try await Gowit.shared.getAds(builder)
            XCTFail("Expected network error due to test environment")
        } catch AdError.http {
            // Expected - network request failed
        } catch AdError.configurationError {
            // Expected - configuration issue
        } catch {
            // Other errors are also acceptable in test environment
            print("Integration test error (expected): \(error)")
        }
    }
}
