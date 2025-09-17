import SwiftUI
import Gowit

/// Represents the current state of the sponsored display views
public enum SponsoredDisplayState {
    case loading
    case loaded([Ad])
    case noAds
    case error(String)
}

/// A SwiftUI component for displaying sponsored display ads.
/// This component automatically loads and displays ads for a given placement.
public struct SponsoredDisplayView: View {
    @State private var ads: [Ad] = []
    @State private var isLoading = false
    @State private var error: String?

    private let placementId: Int
    private let sessionId: String
    private let isClickable: Bool
    private let onStateChange: ((SponsoredDisplayState) -> Void)?
    @Binding private var sponsoredDisplayState: SponsoredDisplayState?

    /// Initialize SponsoredDisplayView with completion callback
    public init(
        placementId: Int,
        sessionId: String,
        isClickable: Bool = true,
        onStateChange: ((SponsoredDisplayState) -> Void)? = nil
    ) {
        self.placementId = placementId
        self.sessionId = sessionId
        self.isClickable = isClickable
        self.onStateChange = onStateChange
        self._sponsoredDisplayState = .constant(nil)
    }

    /// Initialize SponsoredDisplayView with state binding
    public init(
        placementId: Int,
        sessionId: String,
        isClickable: Bool = true,
        state: Binding<SponsoredDisplayState?>
    ) {
        self.placementId = placementId
        self.sessionId = sessionId
        self.isClickable = isClickable
        self.onStateChange = nil
        self._sponsoredDisplayState = state
    }

    public var body: some View {
        Group {
            if isLoading {
                // Loading state - developer can customize this
                Color.clear
            } else if error != nil {
                // Error state - developer can customize this
                Color.clear
            } else if ads.isEmpty {
                // No ads available - this will be hidden when using conditional rendering
                Color.clear
            } else {
                // Display ads - just the image, no padding/margins
                ForEach(ads, id: \.adId) { ad in
                    AdImageView(ad: ad, sessionId: sessionId, isClickable: isClickable)
                }
            }
        }
        .onAppear {
            loadAds()
        }
    }

    private func loadAds() {
        // Don't reload if already loading or already have ads
        guard !isLoading && ads.isEmpty else { return }

        isLoading = true
        error = nil
        notifyStateChange(.loading)

        // Use detached task to ensure it doesn't block UI
        Task.detached { [placementId, sessionId] in
            do {
                // Use the single placement convenience method
                let response = try await Gowit.shared.getAds(
                    placementId: placementId,
                    sessionId: sessionId,
                )

                await MainActor.run {
                    // Get ads specifically for this placement
                    let fetchedAds = response.getAds(for: placementId) ?? []
                    self.ads = fetchedAds
                    self.isLoading = false

                    // Notify about the final state
                    if fetchedAds.isEmpty {
                        self.notifyStateChange(.noAds)
                    } else {
                        self.notifyStateChange(.loaded(fetchedAds))
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = error.localizedDescription
                    self.error = errorMessage
                    self.isLoading = false
                    self.notifyStateChange(.error(errorMessage))
                }
            }
        }
    }

    private func notifyStateChange(_ state: SponsoredDisplayState) {
        // Update binding if available
        sponsoredDisplayState = state

        // Call completion callback if available
        onStateChange?(state)
    }
}

// MARK: - Ad Image View

/// A SwiftUI component for displaying individual sponsored display ads.
/// This component handles image display, event reporting, and click handling.
public struct AdImageView: View {
    let ad: Ad
    let sessionId: String
    let isClickable: Bool
    @State private var hasReportedImpression = false

    public init(ad: Ad, sessionId: String, isClickable: Bool = true) {
        self.ad = ad
        self.sessionId = sessionId
        self.isClickable = isClickable
    }

    public var body: some View {
        Group {
            if let imgUrl = ad.imgUrl, let url = URL(string: imgUrl) {
                if #available(iOS 15, *) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            // Placeholder that maintains layout
                            Rectangle()
                                .fill(Color.clear)
                                .aspectRatio(16/9, contentMode: .fit) // Default aspect ratio
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            // Error state that maintains layout
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(16/9, contentMode: .fit)
                        @unknown default:
                            Rectangle()
                                .fill(Color.clear)
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                    }
                    .onAppear {
                        if !hasReportedImpression {
                            reportImpression()
                        }
                    }
                    .onTapGesture {
                        if isClickable {
                            reportClick()
                            if let redirectUrl = ad.redirect?.url, let url = URL(string: redirectUrl) {
                                #if os(iOS) || os(tvOS)
                                UIApplication.shared.open(url)
                                #elseif os(macOS)
                                NSWorkspace.shared.open(url)
                                #endif
                            }
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)

                }

            } else {
                // No image available - maintain layout with placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)
            }
        }
    }

    private func reportImpression() {
        guard let adId = ad.adId else { return }

        Task {
            do {
                // Send impression event
                try await Gowit.shared.sendImpressionEvent(adId: adId, sessionId: sessionId)
                await MainActor.run {
                    hasReportedImpression = true
                }
            } catch {
                print("Failed to send impression event: \(error)")
            }
        }
    }

    private func reportClick() {
        guard let adId = ad.adId else { return }

        Task {
            do {
                try await Gowit.shared.sendClickEvent(adId: adId, sessionId: sessionId)
            } catch {
                print("Failed to send click event: \(error)")
            }
        }
    }
}

// MARK: - Convenience Views for Common Use Cases

/// A conditional display view that only renders when ads are available
public struct ConditionalDisplayView: View {
    @State private var sponsoredDisplayState: SponsoredDisplayState?

    private let placementId: Int
    private let sessionId: String
    private let isClickable: Bool
    private let fallbackContent: (() -> AnyView)?

    /// Initialize with optional fallback content
    public init<Fallback: View>(
        placementId: Int,
        sessionId: String,
        isClickable: Bool = true,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.placementId = placementId
        self.sessionId = sessionId
        self.isClickable = isClickable
        self.fallbackContent = { AnyView(fallback()) }
    }

    /// Initialize without fallback (renders nothing when no ads)
    public init(
        placementId: Int,
        sessionId: String,
        isClickable: Bool = true
    ) {
        self.placementId = placementId
        self.sessionId = sessionId
        self.isClickable = isClickable
        self.fallbackContent = nil
    }

    public var body: some View {
        Group {
            switch sponsoredDisplayState {
            case .loading:
                // Show nothing during loading to avoid layout shifts
                EmptyView()
            case .loaded:
                // Show the actual display view
                SponsoredDisplayView(placementId: placementId, sessionId: sessionId, isClickable: isClickable)
            case .noAds, .error:
                // Show fallback or nothing
                if let fallbackContent = fallbackContent {
                    fallbackContent()
                } else {
                    EmptyView()
                }
            case .none:
                // Initial state - start loading
                SponsoredDisplayView(placementId: placementId, sessionId: sessionId, isClickable: isClickable, state: $sponsoredDisplayState)
                    .hidden() // Hide during initial load
            }
        }
    }
}

public struct LoadingView: View {
    public init() {}

    public var body: some View {
        ProgressView("Loading ads...")
            .progressViewStyle(CircularProgressViewStyle())
    }
}

public struct ErrorView: View {
    let error: String

    public init(error: String) {
        self.error = error
    }

    public var body: some View {
        Text("Error: \(error)")
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
    }
}

public struct NoAdsView: View {
    public init() {}

    public var body: some View {
        Text("No ads available")
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Backward Compatibility Aliases

/// Backward compatibility alias for SponsoredDisplayView
@available(*, deprecated, renamed: "SponsoredDisplayView")
public typealias BannerView = SponsoredDisplayView

#Preview {
    VStack(spacing: 20) {
        // Single placement display view
        SponsoredDisplayView(placementId: 5, sessionId: "preview-session", isClickable: true)
            .frame(height: 200)

        // Non-clickable display view
        SponsoredDisplayView(placementId: 6, sessionId: "preview-session", isClickable: false)
            .frame(height: 200)

        // Convenience views
        LoadingView()
        ErrorView(error: "Sample error message")
        NoAdsView()
    }
}
