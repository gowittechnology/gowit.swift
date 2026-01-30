import Foundation

/// Defines how clicks on HTML ads should be handled
public enum HTMLClickBehavior {
    /// Automatically open the URL in the in-app browser
    /// The browser will follow redirects naturally
    case openInApp
    
    /// Resolve redirects and pass the final destination URL to the delegate
    /// The delegate decides what to do with the URL
    case handleByDelegate
}

/// Configuration options for HTML ad display and behavior
public struct HTMLAdConfiguration {
    // MARK: - Click Handling
    
    /// How clicks on the ad should be handled
    public var clickBehavior: HTMLClickBehavior
    
    // MARK: - Redirect Options
    
    /// Maximum number of redirects to follow when resolving URLs
    public var maxRedirects: Int
    
    // MARK: - WebView Options
    
    /// Whether the WebView should allow inline media playback
    public var allowsInlineMediaPlayback: Bool
    
    /// Whether the WebView should be scrollable
    public var isScrollEnabled: Bool
    
    // MARK: - Presets
    
    /// Default configuration: automatic opening in in-app browser
    public static let `default` = HTMLAdConfiguration(
        clickBehavior: .openInApp,
        maxRedirects: 10,
        allowsInlineMediaPlayback: true,
        isScrollEnabled: false
    )
    
    /// Configuration for delegate-controlled behavior
    public static let delegateHandled = HTMLAdConfiguration(
        clickBehavior: .handleByDelegate,
        maxRedirects: 10,
        allowsInlineMediaPlayback: true,
        isScrollEnabled: false
    )
    
    // MARK: - Initialization
    
    public init(
        clickBehavior: HTMLClickBehavior = .openInApp,
        maxRedirects: Int = 10,
        allowsInlineMediaPlayback: Bool = true,
        isScrollEnabled: Bool = false
    ) {
        self.clickBehavior = clickBehavior
        self.maxRedirects = maxRedirects
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.isScrollEnabled = isScrollEnabled
    }
}
