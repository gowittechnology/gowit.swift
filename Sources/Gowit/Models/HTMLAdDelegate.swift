import Foundation

/// Delegate protocol for HTML ad lifecycle events
///
/// All methods are optional and have default implementations.
/// Implement only the methods you need for your use case.
public protocol HTMLAdDelegate: AnyObject {
    /// Called when the ad is about to handle a click, before any navigation occurs
    /// - Parameters:
    ///   - ad: The ad that was clicked
    ///   - url: The URL that was clicked
    func htmlAd(_ ad: Ad, willHandleClickOn url: URL)
    
    /// Called after a redirect chain has been resolved
    /// - Parameters:
    ///   - ad: The ad that contained the redirect
    ///   - resolution: Information about the redirect chain
    func htmlAd(_ ad: Ad, didResolveRedirectChain resolution: RedirectResolution)
    
    /// Asks the delegate whether to open a URL in the in-app browser
    /// - Parameters:
    ///   - ad: The ad containing the URL
    ///   - url: The URL to potentially open
    /// - Returns: `true` to use in-app browser, `false` to use system browser
    func htmlAd(_ ad: Ad, shouldOpenInAppBrowser url: URL) -> Bool
    
    /// Called when the ad fails to load or render
    /// - Parameters:
    ///   - ad: The ad that failed
    ///   - error: The error that occurred
    func htmlAd(_ ad: Ad, didFailWithError error: Error)
    
    /// Asks the delegate to decide the navigation policy for a URL
    /// - Parameters:
    ///   - ad: The ad requesting navigation
    ///   - url: The URL to navigate to
    /// - Returns: The navigation policy to apply
    func htmlAd(_ ad: Ad, decidePolicyFor url: URL) -> NavigationPolicy
}

// MARK: - Default Implementations

public extension HTMLAdDelegate {
    func htmlAd(_ ad: Ad, willHandleClickOn url: URL) {
        // Default: do nothing
    }
    
    func htmlAd(_ ad: Ad, didResolveRedirectChain resolution: RedirectResolution) {
        // Default: do nothing
    }
    
    func htmlAd(_ ad: Ad, shouldOpenInAppBrowser url: URL) -> Bool {
        // Default: use in-app browser
        return true
    }
    
    func htmlAd(_ ad: Ad, didFailWithError error: Error) {
        // Default: print error
        print("HTML Ad Error: \(error.localizedDescription)")
    }
    
    func htmlAd(_ ad: Ad, decidePolicyFor url: URL) -> NavigationPolicy {
        // Default: open in-app browser
        return .openInAppBrowser
    }
}
