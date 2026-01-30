import Foundation

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
    
    /// Timeout for each HTTP request
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
public enum RedirectHandlerError: Error {
    case tooManyRedirects
    case invalidRedirectLocation
    case timeout
    case networkError(Error)
    case invalidResponse
}

/// Utility class for handling URL redirects and tracking chains
public class RedirectHandler {
    private let configuration: RedirectHandlerConfiguration
    
    public init(configuration: RedirectHandlerConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Resolve a redirect chain by following all redirects until a final destination is reached
    /// - Parameter url: The original URL to resolve
    /// - Returns: A RedirectResolution containing information about the redirect chain
    /// - Throws: RedirectHandlerError if resolution fails
    public func resolveRedirectChain(from url: URL) async throws -> RedirectResolution {
        guard configuration.followRedirects else {
            // If not following redirects, just return the original URL
            return RedirectResolution(
                originalURL: url,
                finalURL: url,
                redirectCount: 0,
                isTrackerURL: false
            )
        }
        
        var currentURL = url
        var redirectCount = 0
        
        // Follow redirects until we reach a non-redirect response
        while redirectCount < configuration.maxRedirects {
            let nextURL = try await followSingleRedirect(url: currentURL)
            
            if let redirectURL = nextURL {
                // This was a redirect, continue following
                currentURL = redirectURL
                redirectCount += 1
            } else {
                // No more redirects, we've reached the final destination
                let isTrackerURL = redirectCount > 0
                return RedirectResolution(
                    originalURL: url,
                    finalURL: currentURL,
                    redirectCount: redirectCount,
                    isTrackerURL: isTrackerURL
                )
            }
        }
        
        // Exceeded max redirects
        throw RedirectHandlerError.tooManyRedirects
    }
    
    /// Follow a single redirect step
    /// - Parameter url: The URL to check for redirects
    /// - Returns: The redirect URL if this is a redirect, or nil if not
    private func followSingleRedirect(url: URL) async throws -> URL? {
        GowitLogger.debug("Checking URL: \(url.absoluteString)")
        
        // Create a custom URL session that doesn't follow redirects
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.httpShouldSetCookies = false
        
        // Create delegate to prevent automatic redirect following
        let delegate = NoRedirectDelegate()
        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        
        // Use GET method since some servers don't support HEAD (return 405)
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                GowitLogger.error("Invalid response type for URL: \(url.absoluteString)")
                throw RedirectHandlerError.invalidResponse
            }
            
            GowitLogger.debug("Status code: \(httpResponse.statusCode)")
            
            // Check if this is a redirect status code
            if isRedirectStatusCode(httpResponse.statusCode) {
                // Extract the Location header
                guard let locationString = httpResponse.value(forHTTPHeaderField: "Location") else {
                    GowitLogger.error("No Location header found for redirect")
                    throw RedirectHandlerError.invalidRedirectLocation
                }
                
                guard let redirectURL = URL(string: locationString, relativeTo: url)?.absoluteURL else {
                    GowitLogger.error("Invalid Location URL: \(locationString)")
                    throw RedirectHandlerError.invalidRedirectLocation
                }
                
                GowitLogger.debug("Redirect to: \(redirectURL.absoluteString)")
                return redirectURL
            } else if httpResponse.statusCode == 200 {
                // Success - this is the final destination
                GowitLogger.debug("Final destination reached (200)")
                return nil
            } else {
                // Other status codes (4xx, 5xx) - treat as final destination
                GowitLogger.debug("Non-redirect status: \(httpResponse.statusCode)")
                return nil
            }
        } catch let error as RedirectHandlerError {
            throw error
        } catch {
            GowitLogger.error("Network error during redirect resolution", error: error)
            throw RedirectHandlerError.networkError(error)
        }
    }
    
    /// Check if a status code indicates a redirect
    private func isRedirectStatusCode(_ code: Int) -> Bool {
        return code == 301 || code == 302 || code == 303 || code == 307 || code == 308
    }
}

// MARK: - URLSession Delegate to Prevent Auto-Redirect

private class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Return nil to prevent automatic redirect following
        completionHandler(nil)
    }
}
