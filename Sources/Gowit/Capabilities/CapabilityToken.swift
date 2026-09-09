import Foundation

/// The namespaced capability tokens this client understands.
///
/// The token set is deliberately **open**. A reader must ignore a token it does not
/// know rather than refuse the vector that carries it, so these constants are the
/// tokens this build can justify — not a closed universe.
///
/// New primitives, privileged actions and unsupported codecs require a client
/// release; changing a supported recipe does not. That asymmetry is the reason the
/// client declares capabilities rather than a version.
public enum CapabilityToken {

    /// What the runtime can DRAW. Namespace `primitive.*`.
    public enum Primitive {
        public static let image = "primitive.image"
        public static let text = "primitive.text"
        public static let container = "primitive.container"
        public static let entityCard = "primitive.entity_card"
        public static let video = "primitive.video"
        public static let htmlFrame = "primitive.html_frame"
    }

    /// What the runtime can DO on a click. Namespace `action.*`.
    ///
    /// An action the runtime does not declare makes the variant incompatible; it does
    /// **not** make the click a no-op, and an unknown action name may never invoke
    /// arbitrary host functionality.
    public enum Action {
        public static let openURL = "action.open_url"
        public static let entityDestination = "action.entity_destination"
        public static let inAppBrowser = "action.in_app_browser"
        public static let hostCallback = "action.host_callback"
    }

    /// What the runtime can MEASURE and report. Namespace `observation.*`.
    ///
    /// A renderer without completion measurement cannot advertise completion
    /// coverage: omitting `videoCompletion` here is what refuses a variant whose
    /// profile requires it.
    public enum Observation {
        public static let rootImpression = "observation.root_impression"
        public static let viewability = "observation.viewability"
        public static let click = "observation.click"
        public static let entityExposure = "observation.entity_exposure"
        public static let videoCompletion = "observation.video_completion"
        public static let foregroundState = "observation.foreground_state"
    }
}
