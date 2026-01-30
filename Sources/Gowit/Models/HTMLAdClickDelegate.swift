import Foundation

/// Delegate protocol for HTML ad click events
///
/// This delegate provides callbacks for ad click lifecycle events.
/// All methods have default implementations and are optional to implement.
///
/// The `handleAdClick` method is only called when `clickBehavior` is set to `.handleByDelegate`.
/// The `adClickResolved` method is optional and useful for analytics and debugging.
public protocol HTMLAdClickDelegate: AnyObject {
    /// Called when user clicks on the ad, before any redirect resolution
    ///
    /// This is always called regardless of the `clickBehavior` setting.
    /// Useful for tracking ad click events.
    ///
    /// - Parameters:
    ///   - ad: The ad that was clicked
    ///   - clickedURL: The initial URL that was clicked
    func adWasClicked(_ ad: Ad, clickedURL: URL)

    /// Called only when `clickBehavior` is `.handleByDelegate`
    ///
    /// This provides the final destination URL after resolving all redirects.
    /// The URL provided is the first response with a 200 status code.
    /// Implementation should decide what to do with the URL (open in browser, deep link, etc.).
    ///
    /// - Parameters:
    ///   - ad: The ad that was clicked
    ///   - destinationURL: The final destination URL after following all redirects
    func handleAdClick(_ ad: Ad, destinationURL: URL)

    /// Called only when `clickBehavior` is `.handleByDelegate`
    ///
    /// This optional method provides detailed information about the redirect resolution.
    /// Useful for analytics, debugging, and tracking redirect chains.
    ///
    /// - Parameters:
    ///   - ad: The ad that was clicked
    ///   - result: Success with `RedirectResolution` details, or failure with an `Error`
    func adClickResolved(_ ad: Ad, result: Result<RedirectResolution, Error>)
}

// MARK: - Default Implementations

public extension HTMLAdClickDelegate {
    /// Default implementation: does nothing
    func adWasClicked(_ ad: Ad, clickedURL: URL) {
        // Default: no action
    }

    /// Default implementation: does nothing
    /// 
    /// **Important**: You should implement this method to handle the URL appropriately
    /// for your platform (e.g., open in Safari, handle deep links, etc.)
    func handleAdClick(_ ad: Ad, destinationURL: URL) {
        // Default: no action - implement this in your app
    }

    /// Default implementation: does nothing
    func adClickResolved(_ ad: Ad, result: Result<RedirectResolution, Error>) {
        // Default: no action
    }
}
