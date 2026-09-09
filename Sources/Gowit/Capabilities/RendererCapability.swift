import Foundation

/// The platform a renderer runs on.
public enum RendererPlatform: String, Codable, CaseIterable {
    case web
    case ios
    case android
}

/// Playback capability, declared separately from the video **primitive** because
/// parsing is not playing: a client can carry a VAST parser and still have no
/// working player, and that state must be expressible.
public struct MediaCapability: Codable, Equatable {
    /// load, start, quartile, complete, plus muted, autoplay, background and retry.
    public let videoLifecycle: Bool?
    public let autoplay: Bool?
    public let codecs: [String]?
    /// Wrapper resolution and tracker integration. Parsing a VAST document does not set this.
    public let vast: Bool?

    public init(videoLifecycle: Bool? = nil, autoplay: Bool? = nil, codecs: [String]? = nil, vast: Bool? = nil) {
        self.videoLifecycle = videoLifecycle
        self.autoplay = autoplay
        self.codecs = codecs
        self.vast = vast
    }

    enum CodingKeys: String, CodingKey {
        case videoLifecycle = "video_lifecycle"
        case autoplay
        case codecs
        case vast
    }
}

/// The ACTUAL space available at request time — distinct from a placement's logical
/// outer opportunity and from a template region's own size. It is a property of the
/// request, not of the installed build, which is why it is absent from the static
/// manifest and supplied by `RendererCapability.withGeometry(_:)`.
public struct GeometryCapability: Codable, Equatable {
    public let availableWidth: Int?
    public let availableHeight: Int?
    /// Device pixel ratio. Asset pixels are checked against region x density.
    public let density: Double?
    public let heightMayChange: Bool?

    public init(availableWidth: Int? = nil, availableHeight: Int? = nil, density: Double? = nil, heightMayChange: Bool? = nil) {
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        self.density = density
        self.heightMayChange = heightMayChange
    }

    enum CodingKeys: String, CodingKey {
        case availableWidth = "available_width"
        case availableHeight = "available_height"
        case density
        case heightMayChange = "height_may_change"
    }
}

/// What the runtime can actually ENFORCE around opaque markup.
///
/// Declared separately from `primitive.html_frame` because a frame is a LAYOUT
/// boundary and a sandbox is a SECURITY boundary. A format whose content profile is
/// opaque markup requires `sandboxed` and will refuse a client that only has the
/// frame — which is the correct answer, not a defect.
public struct IsolationCapability: Codable, Equatable {
    public let sandboxed: Bool?
    public let restrictedNavigation: Bool?
    public let restrictedStorage: Bool?
    public let bridgeVersion: Int?

    public init(sandboxed: Bool? = nil, restrictedNavigation: Bool? = nil, restrictedStorage: Bool? = nil, bridgeVersion: Int? = nil) {
        self.sandboxed = sandboxed
        self.restrictedNavigation = restrictedNavigation
        self.restrictedStorage = restrictedStorage
        self.bridgeVersion = bridgeVersion
    }

    enum CodingKeys: String, CodingKey {
        case sandboxed
        case restrictedNavigation = "restricted_navigation"
        case restrictedStorage = "restricted_storage"
        case bridgeVersion = "bridge_version"
    }
}

/// What this runtime DECLARES it can draw, do, play and observe.
///
/// The negotiation rule, in one place, so three decoders cannot disagree:
///
/// 1. The client sends its vector on the ad request. A vector is not a claim of
///    support for anything it does not name.
/// 2. The server evaluates one tuple per candidate and returns either a resolved
///    render plan or a structured reason. It never returns a plan the vector cannot
///    execute.
/// 3. An ABSENT array or object means "declares nothing of this kind". It never
///    means "declares everything" — which is why every collection here is
///    `Optional` and `nil` is preserved through a round trip rather than
///    normalised to empty.
/// 4. An UNKNOWN TOKEN in a vector is ignored, so a newer client cannot be refused
///    by an older server for saying more than it was asked.
/// 5. An unknown FIELD in this envelope is ignored by both sides, so v1 stays
///    additive. `Decodable` gives that for free; do not add a strict-key check.
/// 6. `protocolMajor` is the one field whose mismatch is fatal in both directions.
/// 7. NO VECTOR AT ALL is legal and means the legacy generation.
public struct RendererCapability: Codable, Equatable {

    /// The serving protocol generation this runtime speaks. An unknown major gets an
    /// explicit `UNSUPPORTED_PROTOCOL_MAJOR`, never a best-effort render.
    public let protocolMajor: Int
    public let platform: RendererPlatform
    /// The client build — distinct from `protocolMajor`, which is the wire generation.
    public let rendererVersion: String

    public let primitives: [String]?
    public let actions: [String]?
    public let media: MediaCapability?
    public let observation: [String]?
    public let geometry: GeometryCapability?
    public let isolation: IsolationCapability?

    public init(
        protocolMajor: Int,
        platform: RendererPlatform,
        rendererVersion: String,
        primitives: [String]? = nil,
        actions: [String]? = nil,
        media: MediaCapability? = nil,
        observation: [String]? = nil,
        geometry: GeometryCapability? = nil,
        isolation: IsolationCapability? = nil
    ) {
        self.protocolMajor = protocolMajor
        self.platform = platform
        self.rendererVersion = rendererVersion
        self.primitives = primitives
        self.actions = actions
        self.media = media
        self.observation = observation
        self.geometry = geometry
        self.isolation = isolation
    }

    enum CodingKeys: String, CodingKey {
        case protocolMajor = "protocol_major"
        case platform
        case rendererVersion = "renderer_version"
        case primitives
        case actions
        case media
        case observation
        case geometry
        case isolation
    }

    // MARK: - Negotiation

    /// Whether this vector names `token`. Absence is the answer for an absent
    /// collection: "declares nothing of this kind" is not "declares everything".
    public func declares(_ token: String) -> Bool {
        if primitives?.contains(token) == true { return true }
        if actions?.contains(token) == true { return true }
        if observation?.contains(token) == true { return true }
        return false
    }

    /// The subset of `required` this vector does not declare, in the order asked.
    /// An empty result means the variant is executable here.
    public func missingCapabilities(from required: [String]) -> [String] {
        required.filter { !declares($0) }
    }

    /// The same vector with request-time geometry attached. Geometry belongs to the
    /// request, not to the installed build.
    public func withGeometry(_ geometry: GeometryCapability) -> RendererCapability {
        RendererCapability(
            protocolMajor: protocolMajor,
            platform: platform,
            rendererVersion: rendererVersion,
            primitives: primitives,
            actions: actions,
            media: media,
            observation: observation,
            geometry: geometry,
            isolation: isolation
        )
    }
}
