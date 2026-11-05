import XCTest
@testable import Gowit
@testable import AdViews

final class StandardAdRendererTests: XCTestCase {

    private func productAd(html: String? = nil, videoUrl: String? = nil) -> Ad {
        Ad(
            adId: "ad-1",
            creativeId: 7,
            imgUrl: "https://example.invalid/a.png",
            videoUrl: videoUrl,
            redirect: Redirect(url: "https://example.invalid/click", type: "product"),
            advertiserId: "adv-1",
            products: [
                PromotedProduct(name: "Kettle", sku: "SKU-1", imageUrl: "https://example.invalid/p.png", rating: 4.5, price: 249.9)
            ],
            html: html
        )
    }

    func testStandardProductAdResolvesToAnEntityCard() throws {
        let plan = try XCTUnwrap(
            StandardAdResolver.resolve(ad: productAd(), capability: GowitCapabilities.installed).get()
        )
        guard case .entityCard(let role, let children) = plan.root else {
            return XCTFail("expected an entity card, got \(plan.root)")
        }
        XCTAssertEqual(role, .root)
        XCTAssertEqual(plan.adId, "ad-1")
        XCTAssertTrue(children.contains(.text(role: .headline, value: "Kettle")))
        XCTAssertTrue(
            children.contains(.text(role: .sponsorshipLabel, value: StandardAdResolver.sponsorshipLabel)),
            "the disclosure is part of the tree, not a decoration the host may forget"
        )
    }

    func testActionPrefersTheInAppBrowserThisRuntimeDeclares() throws {
        let plan = try StandardAdResolver.resolve(ad: productAd(), capability: GowitCapabilities.installed).get()
        XCTAssertEqual(plan.action?.token, CapabilityToken.Action.inAppBrowser)
        XCTAssertEqual(plan.action?.url.absoluteString, "https://example.invalid/click")
    }

    /// D-50, enforced: opaque advertiser markup is REFUSED here and routed to the
    /// isolated profile. It is never silently converted into an embedded browser view,
    /// because that would trade native fidelity and measurement for a render nobody
    /// asked for.
    func testOpaqueMarkupIsRefusedNotSilentlyConvertedToAWebView() {
        let result = StandardAdResolver.resolve(
            ad: productAd(html: "<div onclick='steal()'>buy</div>"),
            capability: GowitCapabilities.installed
        )
        guard case .failure(let refusal) = result else {
            return XCTFail("markup must not resolve to a native plan")
        }
        XCTAssertEqual(refusal.code, .missingCapability)
        XCTAssertEqual(refusal.refusalClass, .incompatible)
        XCTAssertEqual(refusal.missingCapabilities, [StandardAdResolver.sandboxToken])
    }

    /// Declaring `primitive.html_frame` is a LAYOUT claim. Only `isolation.sandboxed`
    /// is a security claim, and this build makes it false, so the frame alone does not
    /// let markup through.
    func testHTMLFrameAloneDoesNotAdmitMarkup() {
        XCTAssertTrue(GowitCapabilities.installed.declares(CapabilityToken.Primitive.htmlFrame))
        XCTAssertNotEqual(GowitCapabilities.installed.isolation?.sandboxed, true)
    }

    /// Parsing is not playing: a runtime with the video primitive but no lifecycle is
    /// refused, and the refusal names the lifecycle it lacks.
    func testVideoWithoutPlaybackLifecycleIsRefused() {
        let parserOnly = RendererCapability(
            protocolMajor: 1,
            platform: .ios,
            rendererVersion: "1.0.4",
            primitives: [CapabilityToken.Primitive.video, CapabilityToken.Primitive.image, CapabilityToken.Primitive.text],
            media: MediaCapability(videoLifecycle: false, vast: true)
        )
        let result = StandardAdResolver.resolve(
            ad: productAd(videoUrl: "https://example.invalid/v.mp4"),
            capability: parserOnly
        )
        guard case .failure(let refusal) = result else { return XCTFail("expected a refusal") }
        XCTAssertEqual(refusal.missingCapabilities, ["media.video_lifecycle"])
    }

    func testMissingPrimitiveIsRefusedByNameRatherThanDegraded() {
        let noCards = RendererCapability(
            protocolMajor: 1,
            platform: .ios,
            rendererVersion: "1.0.4",
            primitives: [CapabilityToken.Primitive.image, CapabilityToken.Primitive.text],
            actions: [CapabilityToken.Action.openURL]
        )
        let result = StandardAdResolver.resolve(ad: productAd(), capability: noCards)
        guard case .failure(let refusal) = result else { return XCTFail("expected a refusal") }
        XCTAssertEqual(refusal.code, .missingCapability)
        XCTAssertEqual(refusal.missingCapabilities, [CapabilityToken.Primitive.entityCard])
    }

    func testUnknownProtocolMajorIsFatalRatherThanBestEffort() {
        let future = RendererCapability(protocolMajor: 99, platform: .ios, rendererVersion: "9.0.0")
        let result = StandardAdResolver.resolve(ad: productAd(), capability: future)
        guard case .failure(let refusal) = result else { return XCTFail("expected a refusal") }
        XCTAssertEqual(refusal.code, .unsupportedProtocolMajor)
    }

    // MARK: - Lifecycle

    /// The once-only rule, and the reason it is keyed on the ad rather than on the
    /// view: a recycled cell must not double-count the ad it is leaving, and must not
    /// swallow the impression of the ad it is arriving at.
    func testExposureFiresOncePerIdentityAndAgainAfterReuse() {
        var events: [AdRenderEvent] = []
        let lifecycle = AdRenderLifecycle { events.append($0) }

        lifecycle.mount(adID: "ad-1")
        XCTAssertTrue(lifecycle.expose(adID: "ad-1"))
        XCTAssertFalse(lifecycle.expose(adID: "ad-1"), "a second exposure of the same identity must not fire")

        lifecycle.dispose()
        lifecycle.mount(adID: "ad-2")
        XCTAssertTrue(lifecycle.expose(adID: "ad-2"), "a recycled view showing a different ad must fire")

        XCTAssertEqual(events, [
            .mounted(adId: "ad-1"),
            .exposed(adId: "ad-1"),
            .disposed(adId: "ad-1"),
            .mounted(adId: "ad-2"),
            .exposed(adId: "ad-2")
        ])
    }

    /// A refusal reports and draws nothing. It must not reach the exposure path — an
    /// ad that was never rendered cannot have been seen.
    func testARefusalNeverProducesAnExposure() {
        var events: [AdRenderEvent] = []
        let lifecycle = AdRenderLifecycle { events.append($0) }
        lifecycle.refuse(.missingCapability([StandardAdResolver.sandboxToken]))

        XCTAssertEqual(events.count, 1)
        guard case .refused = events[0] else { return XCTFail("expected a refusal event") }
    }

    func testDisposeReleasesTheIdentitySoTheSameAdCanBeCountedOnARemount() {
        var exposures = 0
        let lifecycle = AdRenderLifecycle { if case .exposed = $0 { exposures += 1 } }
        lifecycle.expose(adID: "ad-1")
        lifecycle.dispose()
        lifecycle.expose(adID: "ad-1")
        XCTAssertEqual(exposures, 2, "a genuine remount after teardown is a new opportunity")
    }
}
