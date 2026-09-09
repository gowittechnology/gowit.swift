import Foundation
import Gowit

/// The semantic role a node fills, bound to a native view by the renderer rather
/// than to a pixel position by the server. Roles are what let one profile produce an
/// appropriate layout on each platform instead of one platform's layout everywhere.
public enum AdSlotRole: String, Codable, CaseIterable {
    case root
    case media
    case headline
    case price
    case rating
    case sponsorshipLabel = "sponsorship_label"
    case callToAction = "call_to_action"
}

/// The bounded declarative grammar for a standard ad.
///
/// It is bounded on purpose: a node kind that is not in this enum cannot be sent,
/// and a new kind requires a client release. That is the whole difference between
/// declaring capabilities and downloading executable code — which this renderer
/// never does.
public indirect enum StandardAdNode: Equatable {
    /// `primitive.container`
    case container(role: AdSlotRole, children: [StandardAdNode])
    /// `primitive.image`
    case image(role: AdSlotRole, url: URL, accessibilityLabel: String?)
    /// `primitive.text`
    case text(role: AdSlotRole, value: String)
    /// `primitive.entity_card` — one promoted entity drawn as a unit.
    case entityCard(role: AdSlotRole, children: [StandardAdNode])

    /// The capability token this node needs in order to be drawn.
    public var requiredCapability: String {
        switch self {
        case .container: return CapabilityToken.Primitive.container
        case .image: return CapabilityToken.Primitive.image
        case .text: return CapabilityToken.Primitive.text
        case .entityCard: return CapabilityToken.Primitive.entityCard
        }
    }

    /// Every token this node and its descendants need, deduplicated, in first-seen order.
    public var requiredCapabilities: [String] {
        var seen: [String] = []
        func walk(_ node: StandardAdNode) {
            if !seen.contains(node.requiredCapability) { seen.append(node.requiredCapability) }
            switch node {
            case .container(_, let children), .entityCard(_, let children):
                children.forEach(walk)
            case .image, .text:
                break
            }
        }
        walk(self)
        return seen
    }
}

/// What the host may be asked to do when the ad is tapped.
///
/// The payload is a URL and nothing else. There is no field that could name a host
/// selector, a method or a script, so an action can never invoke arbitrary host
/// functionality however it is spelled on the wire.
public struct AdActionRequest: Equatable {
    public let token: String
    public let url: URL

    public init(token: String, url: URL) {
        self.token = token
        self.url = url
    }
}

/// A resolved, executable render plan: a tree that this runtime has already been
/// proven able to draw, plus the identity the measurement of it is reported under.
public struct StandardAdPlan: Equatable {
    public let adId: String?
    public let root: StandardAdNode
    public let action: AdActionRequest?

    public init(adId: String?, root: StandardAdNode, action: AdActionRequest?) {
        self.adId = adId
        self.root = root
        self.action = action
    }

    /// Every capability the plan needs, including the action's.
    public var requiredCapabilities: [String] {
        var required = root.requiredCapabilities
        if let action = action, !required.contains(action.token) {
            required.append(action.token)
        }
        return required
    }
}

// MARK: - Resolution

public enum StandardAdResolver {

    /// The token an opaque-markup ad requires. It is an ISOLATION capability, not a
    /// primitive: drawing a frame and confining what runs inside it are different
    /// claims, and only the second one makes advertiser markup safe to execute.
    public static let sandboxToken = "isolation.sandboxed"

    /// Turn one served ad into a plan this runtime can execute, or refuse with the
    /// exact tokens that are missing.
    ///
    /// Three refusals, and each is deliberate:
    ///
    /// - **Opaque markup** is refused rather than drawn. A known absent capability is
    ///   incompatibility; it is never degraded and never silently converted into an
    ///   embedded browser view. This build declares `isolation.sandboxed = false`, so
    ///   an ad whose content is advertiser markup cannot be rendered here even though
    ///   `primitive.html_frame` is declared.
    /// - **Video** is refused unless the vector declares both the primitive and a
    ///   playback lifecycle, because parsing is not playing.
    /// - **A missing primitive** is refused with every token the tree needed and the
    ///   vector did not name, not just the first.
    public static func resolve(
        ad: Ad,
        capability: RendererCapability
    ) -> Result<StandardAdPlan, CapabilityRefusal> {

        guard capability.protocolMajor == GowitCapabilities.protocolMajor else {
            return .failure(.unsupportedProtocolMajor(capability.protocolMajor))
        }

        if let html = ad.html, !html.isEmpty {
            if capability.isolation?.sandboxed != true {
                return .failure(.missingCapability(
                    [sandboxToken],
                    message: "Opaque advertiser markup requires an isolated profile; this runtime declares a frame but not a sandbox."
                ))
            }
            return .failure(.missingCapability(
                [sandboxToken],
                message: "Opaque markup is rendered by the isolated WebView profile, not by the declarative standard-ad renderer."
            ))
        }

        if let video = ad.videoUrl, !video.isEmpty {
            var missing: [String] = []
            if capability.declares(CapabilityToken.Primitive.video) == false {
                missing.append(CapabilityToken.Primitive.video)
            }
            if capability.media?.videoLifecycle != true {
                missing.append("media.video_lifecycle")
            }
            if !missing.isEmpty {
                return .failure(.missingCapability(missing, message: "Video content on a runtime without playback."))
            }
        }

        guard let root = buildTree(ad: ad) else {
            return .failure(CapabilityRefusal(
                refusalClass: .incompatible,
                code: .noCompatibleVariant,
                message: "The ad carries neither media nor text this renderer can draw."
            ))
        }

        let action = buildAction(ad: ad, capability: capability)

        var required = root.requiredCapabilities
        if let action = action { required.append(action.token) }
        let missing = capability.missingCapabilities(from: required)
        guard missing.isEmpty else {
            return .failure(.missingCapability(missing))
        }

        return .success(StandardAdPlan(adId: ad.adId, root: root, action: action))
    }

    /// Prefer an in-app browser when the runtime declares one, and fall back to the
    /// system URL open. An action is only ever chosen from tokens the vector NAMES —
    /// resolution never invents one and never falls back to "do nothing", because a
    /// click that quietly does nothing is indistinguishable from a broken ad.
    private static func buildAction(ad: Ad, capability: RendererCapability) -> AdActionRequest? {
        guard let raw = ad.clickUrl, let url = URL(string: raw) else { return nil }
        if capability.declares(CapabilityToken.Action.inAppBrowser) {
            return AdActionRequest(token: CapabilityToken.Action.inAppBrowser, url: url)
        }
        if capability.declares(CapabilityToken.Action.openURL) {
            return AdActionRequest(token: CapabilityToken.Action.openURL, url: url)
        }
        return AdActionRequest(token: CapabilityToken.Action.openURL, url: url)
    }

    private static func buildTree(ad: Ad) -> StandardAdNode? {
        if let product = ad.products?.first {
            var children: [StandardAdNode] = []
            if let raw = product.imageUrl ?? ad.imgUrl, let url = URL(string: raw) {
                children.append(.image(role: .media, url: url, accessibilityLabel: product.name))
            }
            if let name = product.name, !name.isEmpty {
                children.append(.text(role: .headline, value: name))
            }
            if let price = product.price {
                children.append(.text(role: .price, value: formatPrice(price)))
            }
            if let rating = product.rating, rating > 0 {
                children.append(.text(role: .rating, value: String(format: "%.1f", rating)))
            }
            children.append(.text(role: .sponsorshipLabel, value: sponsorshipLabel))
            guard !children.isEmpty else { return nil }
            return .entityCard(role: .root, children: children)
        }

        var children: [StandardAdNode] = []
        if let raw = ad.imgUrl, !raw.isEmpty, let url = URL(string: raw) {
            children.append(.image(role: .media, url: url, accessibilityLabel: nil))
        }
        children.append(.text(role: .sponsorshipLabel, value: sponsorshipLabel))
        guard children.count > 1 else { return nil }
        return .container(role: .root, children: children)
    }

    /// The disclosure every standard ad carries. It is part of the tree rather than a
    /// decoration the host may forget, so a plan cannot be drawn without it.
    public static let sponsorshipLabel = "Sponsored"

    private static func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
