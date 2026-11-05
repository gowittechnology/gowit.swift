import Foundation

/// How firm a support statement is.
///
/// The operating-system floor is a **release-time** decision, deferred with a
/// provisional default until the installed distribution is measured. Publishing it
/// as `provisional` is what keeps a build target from being read as a support
/// commitment nobody made.
public enum SupportStatus: String, Codable {
    case provisional
    case committed
}

/// What this build says about the operating systems it runs on.
///
/// `minimumOS` is the package's compiled deployment target — a fact. `status` is
/// what that fact may be used for, and it is `provisional` until the floor is fixed
/// at release.
public struct SupportStatement: Codable, Equatable {
    public let minimumOS: String
    public let status: SupportStatus
    public let note: String

    public init(minimumOS: String, status: SupportStatus, note: String) {
        self.minimumOS = minimumOS
        self.status = status
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case minimumOS = "minimum_os"
        case status
        case note
    }
}

/// The declared, typed manifest of what this client can render and measure.
///
/// It exists so that negotiation is a property of the **installed build** rather
/// than of whatever the caller remembers to pass: a caller asks the package what it
/// can do, and the package answers from one place. Adding a capability here without
/// adding the code that executes it is the failure this type is meant to make
/// visible, so every token below is justified in a comment beside it.
public enum GowitCapabilities {

    /// The serving protocol generation this client speaks.
    public static let protocolMajor = 1

    /// The build identity this client reports. Compiled in, not configured.
    public static var rendererVersion: String { gowitVersion }

    /// The operating-system floor, provisional (see `SupportStatus`).
    public static let support = SupportStatement(
        minimumOS: "iOS 15.0",
        status: .provisional,
        note: "The package's compiled deployment target. The supported-OS floor is a release-time "
            + "decision and is not fixed by this build; three clients of one product currently "
            + "compile to three different floors."
    )

    /// The capability vector for this build.
    ///
    /// Justification, token by token, so the manifest cannot drift from the code:
    ///
    /// - `primitive.image`, `primitive.text`, `primitive.container` — the declarative
    ///   standard-ad components in `AdViews`.
    /// - `primitive.entity_card` — `SponsoredProductView` and `SponsoredDisplayView`.
    /// - `primitive.video` — the video stack (player manager, playback controller,
    ///   observer, cache, configuration).
    /// - `primitive.html_frame` — `HTMLAdDisplayView`. A LAYOUT boundary; see
    ///   `isolation` for why that is not a security claim.
    /// - `action.open_url`, `action.in_app_browser` — the redirect handler and
    ///   `InAppBrowserView`.
    /// - `media.vast` / `media.videoLifecycle` / `media.autoplay` — the VAST parser,
    ///   validator and event tracker together with the player.
    /// - `observation.root_impression`, `observation.click`, `observation.viewability`
    ///   — the typed event vocabulary and the events endpoint. `observation.video_completion`
    ///   is deliberately ABSENT: a VAST event tracker exists, but whether it reports
    ///   completion under this contract's definition has not been measured, and a
    ///   renderer without completion measurement may not advertise completion coverage.
    /// - `isolation.sandboxed = false` — NOT MEASURED, and therefore false. The
    ///   presence of an HTML display view is not evidence that it is constrained;
    ///   a constrained WebView with restricted origins, navigation and storage is
    ///   separate work. Declaring `false` is what makes an opaque-markup format
    ///   refuse this client, which is the correct outcome.
    public static var installed: RendererCapability {
        RendererCapability(
            protocolMajor: protocolMajor,
            platform: .ios,
            rendererVersion: rendererVersion,
            primitives: [
                CapabilityToken.Primitive.image,
                CapabilityToken.Primitive.text,
                CapabilityToken.Primitive.container,
                CapabilityToken.Primitive.entityCard,
                CapabilityToken.Primitive.video,
                CapabilityToken.Primitive.htmlFrame
            ],
            actions: [
                CapabilityToken.Action.openURL,
                CapabilityToken.Action.inAppBrowser
            ],
            media: MediaCapability(videoLifecycle: true, autoplay: true, vast: true),
            observation: [
                CapabilityToken.Observation.rootImpression,
                CapabilityToken.Observation.click,
                CapabilityToken.Observation.viewability
            ],
            isolation: IsolationCapability(sandboxed: false)
        )
    }

    /// The installed vector with the space actually available at request time.
    public static func installed(in geometry: GeometryCapability) -> RendererCapability {
        installed.withGeometry(geometry)
    }

    /// Encode the installed vector for transport. Absent collections stay absent:
    /// `nil` must not be normalised to `[]`, because the two mean different things.
    public static func encodedManifest() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(installed)
    }
}
