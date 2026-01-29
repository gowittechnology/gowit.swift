import Foundation

/// Defines how clicks on HTML ads should be handled
public enum ClickBehavior {
    /// Open the URL directly without any preprocessing
    case openDirectly
    
    /// Follow redirect chains and resolve to the final destination before opening
    case resolveRedirects
    
    /// Notify the delegate and let them decide what to do
    case notifyDelegate
}

/// Navigation policy decision for HTML ad clicks
public enum NavigationPolicy {
    /// Allow the navigation to proceed
    case allow
    
    /// Cancel the navigation
    case cancel
    
    /// Open the URL in the in-app browser
    case openInAppBrowser
    
    /// Open the URL in the external system browser
    case openExternally
}

/// Configuration options for HTML ad display and behavior
public struct HTMLAdConfiguration {
    // MARK: - Click Handling
    
    /// How clicks on the ad should be handled
    public var clickBehavior: ClickBehavior
    
    // MARK: - Redirect Options
    
    /// Whether to follow redirect chains
    public var followRedirects: Bool
    
    /// Maximum number of redirects to follow
    public var maxRedirects: Int
    
    /// Whether to resolve redirects before opening the URL
    public var resolveBeforeOpening: Bool
    
    // MARK: - Browser Options
    
    /// Whether to use the in-app browser instead of external browser
    public var useInAppBrowser: Bool
    
    /// Whether to allow opening URLs in external browser as fallback
    public var allowExternalBrowser: Bool
    
    // MARK: - WebView Options
    
    /// Whether the WebView should allow inline media playback
    public var allowsInlineMediaPlayback: Bool
    
    /// Whether the WebView should be scrollable
    public var isScrollEnabled: Bool
    
    // MARK: - Presets
    
    /// Default configuration: direct opening with in-app browser
    public static let `default` = HTMLAdConfiguration(
        clickBehavior: .openDirectly,
        followRedirects: false,
        maxRedirects: 10,
        resolveBeforeOpening: false,
        useInAppBrowser: true,
        allowExternalBrowser: true,
        allowsInlineMediaPlayback: true,
        isScrollEnabled: false
    )
    
    /// Configuration for tracking URL resolution
    public static let withRedirectResolution = HTMLAdConfiguration(
        clickBehavior: .resolveRedirects,
        followRedirects: true,
        maxRedirects: 10,
        resolveBeforeOpening: true,
        useInAppBrowser: true,
        allowExternalBrowser: true,
        allowsInlineMediaPlayback: true,
        isScrollEnabled: false
    )
    
    /// Configuration for delegate-controlled behavior
    public static let delegateControlled = HTMLAdConfiguration(
        clickBehavior: .notifyDelegate,
        followRedirects: false,
        maxRedirects: 10,
        resolveBeforeOpening: false,
        useInAppBrowser: false,
        allowExternalBrowser: true,
        allowsInlineMediaPlayback: true,
        isScrollEnabled: false
    )
    
    // MARK: - Initialization
    
    public init(
        clickBehavior: ClickBehavior = .openDirectly,
        followRedirects: Bool = false,
        maxRedirects: Int = 10,
        resolveBeforeOpening: Bool = false,
        useInAppBrowser: Bool = true,
        allowExternalBrowser: Bool = true,
        allowsInlineMediaPlayback: Bool = true,
        isScrollEnabled: Bool = false
    ) {
        self.clickBehavior = clickBehavior
        self.followRedirects = followRedirects
        self.maxRedirects = maxRedirects
        self.resolveBeforeOpening = resolveBeforeOpening
        self.useInAppBrowser = useInAppBrowser
        self.allowExternalBrowser = allowExternalBrowser
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.isScrollEnabled = isScrollEnabled
    }
}
