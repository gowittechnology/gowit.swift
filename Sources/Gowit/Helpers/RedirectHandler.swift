import Foundation
import WebKit

/// Represents the result of following a redirect chain
public struct RedirectResolution {
    /// The original URL that was clicked
    public let originalURL: URL

    /// The final destination URL after following all redirects
    public let finalURL: URL

    /// Number of redirects followed
    public let redirectCount: Int

    /// Whether the original URL appears to be a tracking URL (based on redirect behavior)
    public let isTrackerURL: Bool

    public init(originalURL: URL, finalURL: URL, redirectCount: Int, isTrackerURL: Bool) {
        self.originalURL = originalURL
        self.finalURL = finalURL
        self.redirectCount = redirectCount
        self.isTrackerURL = isTrackerURL
    }
}

/// Configuration for redirect handling behavior
public struct RedirectHandlerConfiguration {
    /// Whether to follow redirects
    public var followRedirects: Bool

    /// Maximum number of redirects to follow before giving up
    public var maxRedirects: Int

    /// Timeout for redirect resolution
    public var timeout: TimeInterval

    /// Default configuration
    public static let `default` = RedirectHandlerConfiguration(
        followRedirects: true,
        maxRedirects: 10,
        timeout: 10.0
    )

    public init(followRedirects: Bool = true, maxRedirects: Int = 10, timeout: TimeInterval = 10.0) {
        self.followRedirects = followRedirects
        self.maxRedirects = maxRedirects
        self.timeout = timeout
    }
}

/// Errors that can occur during redirect handling
public enum RedirectHandlerError: Error, LocalizedError {
    case tooManyRedirects
    case invalidResponse
    case invalidRedirectLocation
    case networkError(Error)
    case timeout
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .tooManyRedirects:
            return "Too many redirects"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .invalidRedirectLocation:
            return "Invalid redirect location"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Redirect resolution timeout"
        case .unknown(let message):
            return message
        }
    }
}

/// Handler for resolving URL redirect chains using WKWebView
/// This preserves cookies, user-agent, and handles all redirect types (HTTP, JavaScript, meta refresh)
@MainActor
public class RedirectHandler: NSObject {

    private let configuration: RedirectHandlerConfiguration
    private var webView: WKWebView?
    private var redirectCount = 0
    private var originalURL: URL?
    private var completion: ((Result<RedirectResolution, RedirectHandlerError>) -> Void)?
    private var timeoutTimer: Timer?

    public init(configuration: RedirectHandlerConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    /// Resolve the full redirect chain from the given URL
    /// - Parameter url: The starting URL (typically a tracking URL)
    /// - Returns: RedirectResolution containing the final destination and chain info
    public func resolveRedirectChain(from url: URL) async throws -> RedirectResolution {
        return try await withCheckedThrowingContinuation { continuation in
            self.startResolving(url: url) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func startResolving(url: URL, completion: @escaping (Result<RedirectResolution, RedirectHandlerError>) -> Void) {
        GowitLogger.debug("Starting redirect resolution for: \(url.absoluteString)")

        // Ensure cleanup from any previous attempt
        cleanup()

        self.originalURL = url
        self.redirectCount = 0
        self.completion = completion

        // Create configuration with shared process pool for better stability
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent() // Don't persist cookies/data
        config.suppressesIncrementalRendering = true // Don't render, just resolve

        // Disable media playback to reduce resource usage
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        // Set timeout
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: configuration.timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }

        // Load URL
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        webView.load(request)
    }

    private func finishResolving(finalURL: URL) {
        GowitLogger.debug("Redirect resolution complete. Final URL: \(finalURL.absoluteString)")
        GowitLogger.debug("Redirect count: \(redirectCount)")

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        guard let originalURL = originalURL else {
            completion?(.failure(.unknown("Original URL not set")))
            cleanup()
            return
        }

        let resolution = RedirectResolution(
            originalURL: originalURL,
            finalURL: finalURL,
            redirectCount: redirectCount,
            isTrackerURL: redirectCount > 0
        )

        completion?(.success(resolution))
        cleanup()
    }

    private func finishWithError(_ error: RedirectHandlerError) {
        GowitLogger.error("Redirect resolution failed", error: error)

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        completion?(.failure(error))
        cleanup()
    }

    private func handleTimeout() {
        GowitLogger.error("Redirect resolution timeout")
        finishWithError(.timeout)
    }

    private func cleanup() {
        // Stop loading first
        webView?.stopLoading()

        // Remove delegate
        webView?.navigationDelegate = nil

        // Load about:blank to release resources
        if let webView = webView {
            webView.load(URLRequest(url: URL(string: "about:blank")!))
        }

        // Clear reference
        webView = nil
        completion = nil
        originalURL = nil
        redirectCount = 0
    }

    deinit {
        // Ensure cleanup on deallocation
        timeoutTimer?.invalidate()
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }
}

// MARK: - WKNavigationDelegate

extension RedirectHandler: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        GowitLogger.debug("Navigation to: \(url.absoluteString)")

        // Check redirect limit
        if redirectCount >= configuration.maxRedirects {
            GowitLogger.error("Max redirects exceeded")
            decisionHandler(.cancel)
            finishWithError(.tooManyRedirects)
            return
        }

        // Count this as a redirect if it's not the first navigation
        if redirectCount > 0 || url != originalURL {
            redirectCount += 1
            GowitLogger.debug("Redirect #\(redirectCount)")
        }

        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Navigation finished - this is the final URL
        guard let finalURL = webView.url else {
            finishWithError(.invalidResponse)
            return
        }

        GowitLogger.debug("Navigation finished at: \(finalURL.absoluteString)")
        finishResolving(finalURL: finalURL)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        GowitLogger.error("Navigation failed", error: error)
        finishWithError(.networkError(error))
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        GowitLogger.error("Provisional navigation failed", error: error)
        finishWithError(.networkError(error))
    }
}
