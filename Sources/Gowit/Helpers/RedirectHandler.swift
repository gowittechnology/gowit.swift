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
        // Create a URL request with HEAD method to avoid downloading content
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "HEAD"
        
        // Don't automatically follow redirects - we want to handle them manually
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedirectHandlerError.invalidResponse
            }
            
            // Check if this is a redirect status code
            if isRedirectStatusCode(httpResponse.statusCode) {
                // Extract the Location header
                guard let locationString = httpResponse.value(forHTTPHeaderField: "Location"),
                      let redirectURL = URL(string: locationString, relativeTo: url)?.absoluteURL else {
                    throw RedirectHandlerError.invalidRedirectLocation
                }
                
                return redirectURL
            } else {
                // Not a redirect, this is the final destination
                return nil
            }
        } catch let error as RedirectHandlerError {
            throw error
        } catch {
            throw RedirectHandlerError.networkError(error)
        }
    }
    
    /// Check if a status code indicates a redirect
    private func isRedirectStatusCode(_ code: Int) -> Bool {
        return code == 301 || code == 302 || code == 303 || code == 307 || code == 308
    }
}
