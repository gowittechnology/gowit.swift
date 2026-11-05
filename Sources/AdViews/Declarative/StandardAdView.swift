import SwiftUI
import Gowit

/// The stages a rendered ad passes through, reported separately because request
/// success, render readiness, exposure and error are four different facts and
/// collapsing them is how an empty response comes to fire a success impression.
public enum AdRenderEvent: Equatable {
    case mounted(adId: String?)
    case exposed(adId: String?)
    case refused(CapabilityRefusal)
    case disposed(adId: String?)
}

/// Owns one rendered ad's lifetime.
///
/// The impression is fired **once per mounted identity**. A recycled list cell hands
/// the same view a different ad, so the guard is keyed on the ad's own id rather than
/// on the view's existence — a view-scoped `hasFired` flag would suppress the second
/// ad's impression entirely and count the first one twice on the way back.
public final class AdRenderLifecycle: ObservableObject {
    private var exposedAdID: String?
    private let onEvent: ((AdRenderEvent) -> Void)?

    public init(onEvent: ((AdRenderEvent) -> Void)? = nil) {
        self.onEvent = onEvent
    }

    public func mount(adID: String?) {
        onEvent?(.mounted(adId: adID))
    }

    /// Report exposure for `adID` unless this identity has already been reported.
    /// Returns whether it fired, so a caller can assert the once-only rule.
    @discardableResult
    public func expose(adID: String?) -> Bool {
        guard exposedAdID != adID else { return false }
        exposedAdID = adID
        onEvent?(.exposed(adId: adID))
        return true
    }

    public func refuse(_ refusal: CapabilityRefusal) {
        onEvent?(.refused(refusal))
    }

    /// Release the identity so a reused view starts clean, and tell the host the
    /// surface is gone. Nothing here retains the view.
    public func dispose() {
        let adID = exposedAdID
        exposedAdID = nil
        onEvent?(.disposed(adId: adID))
    }
}

/// Draws a resolved plan with native views.
///
/// It renders a plan, never an `Ad`: resolution has already refused anything this
/// runtime cannot execute, so there is no branch here that could quietly substitute
/// a browser view for a native one.
public struct StandardAdView: View {
    private let plan: StandardAdPlan
    private let onAction: ((AdActionRequest) -> Void)?
    @ObservedObject private var lifecycle: AdRenderLifecycle

    public init(
        plan: StandardAdPlan,
        lifecycle: AdRenderLifecycle,
        onAction: ((AdActionRequest) -> Void)? = nil
    ) {
        self.plan = plan
        self.lifecycle = lifecycle
        self.onAction = onAction
    }

    public var body: some View {
        AdNodeView(node: plan.root)
            .contentShape(Rectangle())
            .modifier(TapAction(action: plan.action, onAction: onAction))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(accessibilitySummary))
            .accessibilityAddTraits(plan.action == nil ? [] : .isButton)
            .onAppear {
                lifecycle.mount(adID: plan.adId)
                lifecycle.expose(adID: plan.adId)
            }
            .onDisappear { lifecycle.dispose() }
    }

    /// One spoken sentence for the whole ad. The disclosure leads, because a screen
    /// reader user learns it is an ad before they learn what it sells.
    private var accessibilitySummary: String {
        var parts: [String] = []
        func walk(_ node: StandardAdNode) {
            switch node {
            case .text(let role, let value):
                if role == .sponsorshipLabel { parts.insert(value, at: 0) } else { parts.append(value) }
            case .image(_, _, let label):
                if let label = label, !label.isEmpty { parts.append(label) }
            case .container(_, let children), .entityCard(_, let children):
                children.forEach(walk)
            }
        }
        walk(plan.root)
        return parts.joined(separator: ", ")
    }

}

/// One node of the grammar, drawn.
///
/// It is a named type rather than a `@ViewBuilder` method on `StandardAdView` because
/// the grammar is a tree and a method that returns `some View` while calling itself
/// defines its own opaque type in terms of itself. A concrete struct recursing into
/// itself is the shape SwiftUI can actually type-check.
struct AdNodeView: View {
    let node: StandardAdNode

    var body: some View {
        switch node {
        case .container(_, let children):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(children.enumerated()), id: \.offset) { item in
                    AdNodeView(node: item.element)
                }
            }

        case .entityCard(_, let children):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(children.enumerated()), id: \.offset) { item in
                    AdNodeView(node: item.element)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
            )

        case .image(_, let url, _):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .failure:
                    AdNodePlaceholder(systemName: "photo")
                case .empty:
                    AdNodePlaceholder(systemName: nil)
                @unknown default:
                    AdNodePlaceholder(systemName: nil)
                }
            }
            // A media region that grows to whatever the image reports would let one
            // creative push the host's own content off the screen. The ceiling is the
            // renderer's, not the creative's.
            .frame(maxWidth: .infinity, maxHeight: Self.mediaHeightCeiling)
            .accessibilityHidden(true)

        case .text(let role, let value):
            Text(value)
                .font(Self.font(for: role))
                .foregroundColor(role == .sponsorshipLabel ? .secondary : .primary)
                .lineLimit(role == .headline ? 2 : 1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The tallest a media region may draw, in points.
    static let mediaHeightCeiling: CGFloat = 180

    /// Text styles, never fixed point sizes, so the ad follows the reader's own
    /// Dynamic Type setting instead of overriding it.
    static func font(for role: AdSlotRole) -> Font {
        switch role {
        case .headline: return .subheadline.weight(.medium)
        case .price: return .headline
        case .rating, .sponsorshipLabel: return .caption
        default: return .body
        }
    }
}

struct AdNodePlaceholder: View {
    let systemName: String?

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Group {
                    if let systemName = systemName {
                        Image(systemName: systemName).foregroundColor(.secondary)
                    }
                }
            )
    }
}

/// A tap gesture only where there is an action to run. An ad with no action must not
/// look tappable, and a tap on it must not be swallowed from the host's own gestures.
private struct TapAction: ViewModifier {
    let action: AdActionRequest?
    let onAction: ((AdActionRequest) -> Void)?

    func body(content: Content) -> some View {
        if let action = action, let onAction = onAction {
            content.onTapGesture { onAction(action) }
        } else {
            content
        }
    }
}

/// Renders an ad, or renders nothing and reports why.
///
/// The refusal path draws an empty view rather than an error card: a refusal is an
/// operator fact, and a placeholder in a retailer's app would turn a contract
/// decision into a visible defect for a shopper.
public struct StandardAdContainerView: View {
    private let ad: Ad
    private let capability: RendererCapability
    private let lifecycle: AdRenderLifecycle
    private let onAction: ((AdActionRequest) -> Void)?

    public init(
        ad: Ad,
        capability: RendererCapability = GowitCapabilities.installed,
        lifecycle: AdRenderLifecycle,
        onAction: ((AdActionRequest) -> Void)? = nil
    ) {
        self.ad = ad
        self.capability = capability
        self.lifecycle = lifecycle
        self.onAction = onAction
    }

    public var body: some View {
        switch StandardAdResolver.resolve(ad: ad, capability: capability) {
        case .success(let plan):
            StandardAdView(plan: plan, lifecycle: lifecycle, onAction: onAction)
        case .failure(let refusal):
            Color.clear
                .frame(width: 0, height: 0)
                .onAppear { lifecycle.refuse(refusal) }
        }
    }
}
