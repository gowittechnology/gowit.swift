import SwiftUI

// MARK: - Video Ad Configuration

/// Configuration options for VideoAdView behavior and appearance
public struct VideoAdConfiguration: Sendable {

    // MARK: - Loading Behavior

    /// Defines what to display while the video is loading
    public enum LoadingBehavior: Sendable, Equatable {
        /// Hide the view completely until video is ready
        case hidden

        /// Show a system image (SF Symbol) while loading
        case systemImage(name: String)

        /// Show custom text while loading
        case text(String)

        /// Show a colored placeholder
        case placeholder(Color)

        /// Show a shimmer/skeleton loading effect
        case shimmer
    }

    // MARK: - Post-Ad Behavior

    /// Defines what happens after the video ad finishes playing
    public enum PostAdBehavior: Sendable, Equatable {
        /// Replay the same video
        case replay

        /// Request a new ad from the same URL
        case refreshAd

        /// Show the last frame and stop
        case showLastFrame

        /// Hide the view after completion
        case hide
    }

    // MARK: - Mute Button Behavior

    /// Controls mute button visibility
    public enum MuteButtonBehavior: Sendable, Equatable {
        /// Always show the mute button
        case alwaysShow

        /// Never show the mute button
        case alwaysHide

        /// Show only when the video has an audio track (default)
        case automatic
    }

    // MARK: - Mute Button Corner

    /// Defines which corner of the video view the mute button is anchored to
    public enum MuteButtonCorner: Sendable, Equatable {
        /// Top-left corner (default)
        case topLeading

        /// Top-right corner
        case topTrailing

        /// Bottom-left corner
        case bottomLeading

        /// Bottom-right corner
        case bottomTrailing
    }

    // MARK: - Properties

    /// What to display while loading (default: hidden)
    public var loadingBehavior: LoadingBehavior

    /// What to do after ad finishes (default: replay)
    public var postAdBehavior: PostAdBehavior

    /// Whether video is muted by default (default: true)
    public var isMutedByDefault: Bool

    /// Minimum visibility ratio to start/continue playback (default: 0.5 = 50%)
    public var visibilityThreshold: CGFloat

    /// Whether to auto-play when visible (default: true)
    public var autoPlay: Bool

    /// Mute button visibility behavior (default: .automatic — shows only when video has audio)
    public var muteButtonBehavior: MuteButtonBehavior

    /// Corner of the video view where the mute button is anchored (default: .topLeading)
    public var muteButtonCorner: MuteButtonCorner

    /// Size of the mute button in points — width and height are equal (default: 30)
    public var muteButtonSize: CGFloat

    /// Distance of the mute button from the nearest edges in points (default: 14)
    public var muteButtonPadding: CGFloat

    /// Whether to show the mute/unmute button
    /// - Warning: This property is deprecated. Use `muteButtonBehavior` instead.
    @available(*, deprecated, message: "Use muteButtonBehavior instead")
    public var showMuteButton: Bool {
        get { muteButtonBehavior != .alwaysHide }
        set { muteButtonBehavior = newValue ? .automatic : .alwaysHide }
    }

    /// Whether to show a "Sponsored" or "Ad" label (default: true)
    public var showAdLabel: Bool

    /// Custom text for the ad label (default: "Ad")
    public var adLabelText: String

    /// Corner radius for the video view (default: 0)
    public var cornerRadius: CGFloat

    /// Maximum wrapper redirect depth (default: 5)
    public var maxWrapperDepth: Int

    /// Request timeout in seconds (default: 30)
    public var requestTimeout: TimeInterval

    /// Aspect ratio for the video (default: 16:9)
    /// - Warning: This property is deprecated and no longer enforced by VideoAdView.
    ///            Manage video view sizing at the parent container level instead.
    @available(*, deprecated, message: "aspectRatio is no longer enforced by VideoAdView. Manage sizing at the parent container level instead.")
    public var aspectRatio: CGFloat

    /// Enable debug logging (default: false)
    public var debugLogging: Bool

    // MARK: - Initialization

    /// Create a configuration with default values
    public init(
        loadingBehavior: LoadingBehavior = .hidden,
        postAdBehavior: PostAdBehavior = .replay,
        isMutedByDefault: Bool = true,
        visibilityThreshold: CGFloat = 0.5,
        autoPlay: Bool = true,
        muteButtonBehavior: MuteButtonBehavior = .automatic,
        muteButtonCorner: MuteButtonCorner = .topLeading,
        muteButtonSize: CGFloat = 30,
        muteButtonPadding: CGFloat = 14,
        showAdLabel: Bool = true,
        adLabelText: String = "Ad",
        cornerRadius: CGFloat = 0,
        maxWrapperDepth: Int = 5,
        requestTimeout: TimeInterval = 30,
        aspectRatio: CGFloat = 16.0 / 9.0,
        debugLogging: Bool = false
    ) {
        self.loadingBehavior = loadingBehavior
        self.postAdBehavior = postAdBehavior
        self.isMutedByDefault = isMutedByDefault
        self.visibilityThreshold = visibilityThreshold
        self.autoPlay = autoPlay
        self.muteButtonBehavior = muteButtonBehavior
        self.muteButtonCorner = muteButtonCorner
        self.muteButtonSize = muteButtonSize
        self.muteButtonPadding = muteButtonPadding
        self.showAdLabel = showAdLabel
        self.adLabelText = adLabelText
        self.cornerRadius = cornerRadius
        self.maxWrapperDepth = maxWrapperDepth
        self.requestTimeout = requestTimeout
        self.aspectRatio = aspectRatio
        self.debugLogging = debugLogging
    }

    // MARK: - Preset Configurations

    /// Default configuration for most use cases
    public static let `default` = VideoAdConfiguration()

    /// Configuration for continuous ad playback
    public static let continuous = VideoAdConfiguration(
        postAdBehavior: .replay,
        isMutedByDefault: true
    )

    /// Configuration for single-play ads
    public static let singlePlay = VideoAdConfiguration(
        postAdBehavior: .showLastFrame,
        isMutedByDefault: true
    )

    /// Configuration for refresh-on-complete ads
    public static let refreshing = VideoAdConfiguration(
        postAdBehavior: .refreshAd,
        isMutedByDefault: true
    )

    /// Configuration with logo loading state
    public static func withLoadingImage(systemName: String) -> VideoAdConfiguration {
        var config = VideoAdConfiguration()
        config.loadingBehavior = .systemImage(name: systemName)
        return config
    }

    /// Configuration with text loading state
    public static func withLoadingText(_ text: String) -> VideoAdConfiguration {
        var config = VideoAdConfiguration()
        config.loadingBehavior = .text(text)
        return config
    }
}

// MARK: - MuteButtonCorner Layout Helpers (internal)

extension VideoAdConfiguration.MuteButtonCorner {
    /// The SwiftUI `Alignment` that corresponds to this corner
    var swiftUIAlignment: Alignment {
        switch self {
        case .topLeading:    return .topLeading
        case .topTrailing:   return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    /// `EdgeInsets` that push the button away from its two anchored edges by `padding` points
    func edgeInsets(padding: CGFloat) -> EdgeInsets {
        switch self {
        case .topLeading:
            return EdgeInsets(top: padding, leading: padding, bottom: 0, trailing: 0)
        case .topTrailing:
            return EdgeInsets(top: padding, leading: 0, bottom: 0, trailing: padding)
        case .bottomLeading:
            return EdgeInsets(top: 0, leading: padding, bottom: padding, trailing: 0)
        case .bottomTrailing:
            return EdgeInsets(top: 0, leading: 0, bottom: padding, trailing: padding)
        }
    }
}

// MARK: - Video Ad State

/// Represents the current state of the video ad
public enum VideoAdState: Sendable, Equatable {
    /// Initial state, not yet loaded
    case idle

    /// Loading VAST response
    case loading

    /// Video is ready to play
    case ready

    /// Video is currently playing
    case playing

    /// Video is paused (not visible or user action)
    case paused

    /// Video playback completed
    case completed

    /// Error occurred
    case error(String)

    /// No ad available
    case noAd

    /// Hidden state (for hide post-behavior)
    case hidden
}

// MARK: - Video Ad Delegate

/// Protocol for receiving video ad events
public protocol VideoAdDelegate: AnyObject {
    /// Called when the ad is successfully loaded
    func videoAdDidLoad(_ ad: VASTAd)

    /// Called when the video starts playing
    func videoAdDidStart()

    /// Called when the video completes
    func videoAdDidComplete()

    /// Called when the user clicks on the ad
    func videoAdDidClick(url: URL)

    /// Called when an error occurs
    func videoAdDidFail(error: VASTError)

    /// Called when the ad state changes
    func videoAdStateDidChange(_ state: VideoAdState)
}

/// Default implementations for optional delegate methods
public extension VideoAdDelegate {
    func videoAdDidLoad(_ ad: VASTAd) {}
    func videoAdDidStart() {}
    func videoAdDidComplete() {}
    func videoAdDidClick(url: URL) {}
    func videoAdDidFail(error: VASTError) {}
    func videoAdStateDidChange(_ state: VideoAdState) {}
}
