import XCTest
@testable import Gowit

final class CapabilityManifestTests: XCTestCase {

    /// The capability vector the contract lane froze for this client, verbatim.
    ///
    /// It is pinned here rather than fetched so that a change on either side is a
    /// failing test in a diff someone reads, instead of a silent divergence between
    /// what the client declares and what the server negotiates against.
    private let frozenIOSVector = """
    {
      "protocol_major": 1,
      "platform": "ios",
      "renderer_version": "1.0.4",
      "primitives": [
        "primitive.image",
        "primitive.text",
        "primitive.container",
        "primitive.entity_card",
        "primitive.video",
        "primitive.html_frame"
      ],
      "actions": [
        "action.open_url",
        "action.in_app_browser"
      ],
      "media": { "video_lifecycle": true, "autoplay": true, "vast": true },
      "observation": [
        "observation.root_impression",
        "observation.click",
        "observation.viewability"
      ],
      "isolation": { "sandboxed": false }
    }
    """

    func testInstalledManifestMatchesFrozenContractVector() throws {
        let encoded = try GowitCapabilities.encodedManifest()
        let mine = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        let frozen = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(frozenIOSVector.utf8)) as? NSDictionary
        )
        XCTAssertEqual(mine, frozen, "The installed manifest drifted from the frozen ios-1.0.4 capability vector.")
    }

    func testFrozenVectorDecodesIntoTheTypedEnvelope() throws {
        let decoded = try JSONDecoder().decode(RendererCapability.self, from: Data(frozenIOSVector.utf8))
        XCTAssertEqual(decoded, GowitCapabilities.installed)
        XCTAssertEqual(decoded.platform, .ios)
        XCTAssertEqual(decoded.protocolMajor, 1)
    }

    func testRendererVersionIsTheCompiledBuildNotTheProtocol() {
        XCTAssertEqual(GowitCapabilities.rendererVersion, gowitVersion)
        XCTAssertNotEqual(GowitCapabilities.rendererVersion, String(GowitCapabilities.protocolMajor))
    }

    /// An absent collection means "declares nothing of this kind". Normalising it to
    /// an empty array would lose nothing here, but normalising it to "everything" is
    /// the mistake the contract names, and the way to be sure neither happens is that
    /// `nil` survives a round trip.
    func testAbsentCollectionsStayAbsent() throws {
        let bare = RendererCapability(protocolMajor: 1, platform: .ios, rendererVersion: "0.0.1")
        let data = try JSONEncoder().encode(bare)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["primitives"])
        XCTAssertNil(object["observation"])
        XCTAssertNil(object["isolation"])

        let round = try JSONDecoder().decode(RendererCapability.self, from: data)
        XCTAssertNil(round.primitives)
        XCTAssertNil(round.observation)
        XCTAssertFalse(round.declares(CapabilityToken.Primitive.image))
    }

    /// v1 stays additive: an unknown field must not make a decoder refuse a vector a
    /// newer peer sent.
    func testUnknownEnvelopeFieldIsIgnored() throws {
        let json = """
        {"protocol_major":1,"platform":"ios","renderer_version":"1.0.4","some_future_field":{"a":1}}
        """
        let decoded = try JSONDecoder().decode(RendererCapability.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.rendererVersion, "1.0.4")
    }

    /// A newer client saying more than it was asked must not be refused for it.
    func testUnknownTokenIsCarriedNotRefused() throws {
        let json = """
        {"protocol_major":1,"platform":"ios","renderer_version":"9.9.9","primitives":["primitive.image","primitive.hologram"]}
        """
        let decoded = try JSONDecoder().decode(RendererCapability.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.declares("primitive.hologram"))
        XCTAssertTrue(decoded.declares(CapabilityToken.Primitive.image))
    }

    func testMissingCapabilitiesNamesEveryMissingTokenInOrder() {
        let vector = RendererCapability(
            protocolMajor: 1,
            platform: .ios,
            rendererVersion: "1.0.4",
            primitives: [CapabilityToken.Primitive.image]
        )
        let missing = vector.missingCapabilities(from: [
            CapabilityToken.Primitive.container,
            CapabilityToken.Primitive.image,
            CapabilityToken.Primitive.entityCard
        ])
        XCTAssertEqual(missing, [CapabilityToken.Primitive.container, CapabilityToken.Primitive.entityCard])
    }

    /// The completion-coverage rule, enforced at the manifest rather than in prose: a
    /// renderer that cannot measure completion may not advertise it.
    func testVideoCompletionIsNotAdvertised() {
        XCTAssertFalse(GowitCapabilities.installed.declares(CapabilityToken.Observation.videoCompletion))
        XCTAssertTrue(GowitCapabilities.installed.declares(CapabilityToken.Observation.viewability))
    }

    /// The OS floor is a build fact published as a provisional statement, not a
    /// support commitment.
    func testSupportStatementIsProvisional() {
        XCTAssertEqual(GowitCapabilities.support.status, .provisional)
        XCTAssertEqual(GowitCapabilities.support.minimumOS, "iOS 15.0")
    }

    /// Geometry is a property of the request, so it is absent from the installed
    /// manifest and present only once a caller supplies it.
    func testGeometryIsRequestScoped() throws {
        XCTAssertNil(GowitCapabilities.installed.geometry)
        let sized = GowitCapabilities.installed(in: GeometryCapability(
            availableWidth: 390, availableHeight: 120, density: 3.0, heightMayChange: false
        ))
        XCTAssertEqual(sized.geometry?.availableWidth, 390)
        XCTAssertEqual(sized.primitives, GowitCapabilities.installed.primitives)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(sized)) as? [String: Any]
        )
        let geometry = try XCTUnwrap(object["geometry"] as? [String: Any])
        XCTAssertEqual(geometry["available_width"] as? Int, 390)
        XCTAssertEqual(geometry["height_may_change"] as? Bool, false)
    }

    func testRefusalEncodesTheContractSpelling() throws {
        let refusal = CapabilityRefusal.missingCapability(["primitive.entity_card"])
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(refusal)) as? [String: Any]
        )
        XCTAssertEqual(object["class"] as? String, "incompatible")
        XCTAssertEqual(object["code"] as? String, "MISSING_CAPABILITY")
        XCTAssertEqual(object["missing_capabilities"] as? [String], ["primitive.entity_card"])
    }
}
