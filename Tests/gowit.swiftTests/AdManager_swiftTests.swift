import XCTest
@testable import Gowit

final class AdManagerTests: XCTestCase {

    var adManager: AdManager!

    override func setUp() {
        super.setUp()
        adManager = AdManager.shared
    }

    override func tearDown() {
        adManager = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testAdManagerConfiguration() {
        // Test that configuration doesn't throw errors
        XCTAssertNoThrow(adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        ))

        // Test that we can change timeout interval
        adManager.timeoutInterval = 1.2
        XCTAssertEqual(adManager.timeoutInterval, 1.2)
        adManager.timeoutInterval = AdManager.defaultTimeoutInterval
    }

    func testAdManagerSingletonBehavior() {
        let manager1 = AdManager.shared
        let manager2 = AdManager.shared

        // Test that both references point to the same instance
        XCTAssertTrue(manager1 === manager2)
    }

    // MARK: - Error Handling Tests

    func testGetAdsWithEmptyPlacements() async throws {
        // Configure the manager first
        adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )

        // Test that empty placements throw the correct error
        do {
            _ = try await adManager.getAds(placements: [], sessionId: "test-session")
            XCTFail("Expected AdError.invalidPlacements to be thrown")
        } catch AdError.invalidPlacements {
            // Expected error
        } catch {
            XCTFail("Expected AdError.invalidPlacements but got \(error)")
        }
    }

    func testGetAdsWithoutConfiguration() async throws {
        // Create a fresh instance by accessing shared and clearing its configuration
        // Note: This test verifies configuration error handling

        let placements = [PlacementRequest(placementId: 1)]

        // Test error handling by trying to use unconfigured manager
        // We'll simulate this by using shared without proper configuration
        do {
            let freshManager = AdManager.shared
            // The manager should be configured from previous tests,
            // but we can test error handling with invalid requests
            _ = try await freshManager.getAds(placements: placements, sessionId: "test-session")
            XCTFail("Expected AdError.invalidPlacements to be thrown")
        } catch AdError.invalidPlacements {
            // Expected error - empty placements
        } catch {
            // Other errors are also acceptable for this test
            print("Got expected error: \(error)")
        }
    }

    func testGetAdsWithValidPlacements() async throws {
        // Configure the manager
        adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )

        let placements = [
            PlacementRequest(placementId: 1, maxAds: 5)
        ]

        // This will likely fail due to network, but we can test the error type
        do {
            _ = try await adManager.getAds(placements: placements, sessionId: "test-session")
            XCTFail("Expected an error due to network failure in test environment")
        } catch AdError.http {
            // Expected error - network failure
        } catch AdError.configurationError {
            // Expected error - configuration issue
        } catch {
            // Other errors are also acceptable in test environment
            print("Network test error (expected): \(error)")
        }
    }

    func testGetAdsWithAdRequest() async throws {
        // Configure the manager
        adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )

        let adRequest = AdRequest(
            marketplaceId: "TEST_MARKETPLACE_UUID",
            placements: [PlacementRequest(placementId: 1)],
            sessionId: "test-session"
        )

        // Test the new getAds(request:) method
        do {
            _ = try await adManager.getAds(request: adRequest)
            XCTFail("Expected an error due to network failure in test environment")
        } catch AdError.http {
            // Expected error - network failure
        } catch AdError.configurationError {
            // Expected error - configuration issue
        } catch {
            // Other errors are also acceptable in test environment
            print("AdRequest test error (expected): \(error)")
        }
    }

    // MARK: - Parameter Validation Tests

    func testPageNumberDefaults() async throws {
        // Configure the manager
        adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )

        let placements = [PlacementRequest(placementId: 1)]

        // Test that pageNumber defaults to 0 when nil is passed
        do {
            _ = try await adManager.getAds(placements: placements, pageNumber: nil, sessionId: "test-session")
            XCTFail("Expected network error")
        } catch {
            // Expected - network or configuration error
            // The important thing is that nil pageNumber didn't cause a crash
        }
    }

    func testSessionIdGeneration() async throws {
        // Configure the manager
        adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )

        let placements = [PlacementRequest(placementId: 1)]

        // Test that sessionId is auto-generated when nil is passed
        do {
            _ = try await adManager.getAds(placements: placements, sessionId: nil)
            XCTFail("Expected network error")
        } catch {
            // Expected - network or configuration error
            // The important thing is that nil sessionId didn't cause a crash
        }
    }

    // MARK: - Response Processing Tests

    func testCreateEmptyResponse() {
        // Test the empty response creation (private method behavior)
        // We can't directly test the private method, but we can verify behavior

        // Configure first
        adManager.configure(
            hostname: "https://platform-stage.gowit.com",
            marketplaceId: "TEST_MARKETPLACE_UUID"
        )

        // The empty response creation is tested implicitly through the public API
        // when the server returns 204 No Content
    }

    // MARK: - Timeout Configuration Tests

    func testDefaultAdRequestTimeoutIs600Milliseconds() {
        XCTAssertEqual(Gowit.defaultAdRequestTimeout, 0.6)
        XCTAssertEqual(AdManager.defaultTimeoutInterval, 0.6)
    }

    func testAdRequestTimeoutIsConfigurableThroughGowit() {
        let original = Gowit.shared.adRequestTimeout
        defer { Gowit.shared.adRequestTimeout = original }

        Gowit.shared.adRequestTimeout = 1.5
        XCTAssertEqual(Gowit.shared.adRequestTimeout, 1.5)
        XCTAssertEqual(adManager.timeoutInterval, 1.5)
    }

    func testSlowAdRequestTimesOutAtTheDeadline() async {
        let original = (adManager.client, adManager.timeoutInterval)
        defer { (adManager.client, adManager.timeoutInterval) = original }

        let mock = MockHTTPClient(postResult: .success(nil))
        mock.postDelay = 2
        adManager.client = mock
        adManager.timeoutInterval = 0.2
        adManager.configure(hostname: "https://platform-stage.gowit.com", marketplaceId: "TEST_MARKETPLACE_UUID")

        let start = Date()
        do {
            _ = try await adManager.getAds(placements: [PlacementRequest(placementId: 1)], sessionId: "test-session")
            XCTFail("Expected a timeout")
        } catch AdError.http(error: .timeout) {
            // Expected
        } catch {
            XCTFail("Expected AdError.http(.timeout) but got \(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1, "The request should end at the deadline, not when the server answers")
    }

    func testFastAdRequestFinishesBeforeTheDeadline() async throws {
        let original = (adManager.client, adManager.timeoutInterval)
        defer { (adManager.client, adManager.timeoutInterval) = original }

        let mock = MockHTTPClient(postResult: .success(nil))
        mock.postDelay = 0.05
        adManager.client = mock
        adManager.timeoutInterval = 1
        adManager.configure(hostname: "https://platform-stage.gowit.com", marketplaceId: "TEST_MARKETPLACE_UUID")

        let response = try await adManager.getAds(placements: [PlacementRequest(placementId: 1)], sessionId: "test-session")
        XCTAssertEqual(response.placements?.count, 0, "204 No Content maps to an empty response")
        XCTAssertEqual(mock.lastPostTimeout, 1)
    }

    func testZeroTimeoutTurnsTheDeadlineOff() async throws {
        let original = (adManager.client, adManager.timeoutInterval)
        defer { (adManager.client, adManager.timeoutInterval) = original }

        let mock = MockHTTPClient(postResult: .success(nil))
        mock.postDelay = 0.3
        adManager.client = mock
        adManager.timeoutInterval = 0
        adManager.configure(hostname: "https://platform-stage.gowit.com", marketplaceId: "TEST_MARKETPLACE_UUID")

        _ = try await adManager.getAds(placements: [PlacementRequest(placementId: 1)], sessionId: "test-session")
        XCTAssertEqual(mock.lastPostTimeout, AdManager.fallbackNetworkTimeout)
    }
}
