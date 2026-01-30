import SwiftUI
import WebKit
import Gowit

/// A SwiftUI component for displaying HTML ads with WebView rendering
///
/// This component handles:
/// - HTML rendering in a WKWebView
/// - Automatic size calculation and scaling
/// - Auto-impression tracking
/// - Click event interception and handling
/// - Configurable redirect resolution
/// - In-app browser support
///
/// # Example Usage
///
/// Basic usage with default configuration:
/// ```swift
/// HTMLAdDisplayView(
///     ad: ad,
///     sessionId: sessionId
/// )
/// ```
///
/// With redirect resolution:
/// ```swift
/// HTMLAdDisplayView(
///     ad: ad,
///     sessionId: sessionId,
///     configuration: .withRedirectResolution
/// )
/// ```
///
/// With custom delegate:
/// ```swift
/// HTMLAdDisplayView(
///     ad: ad,
///     sessionId: sessionId,
///     configuration: config,
///     delegate: myDelegate
/// )
/// ```
public struct HTMLAdDisplayView: View {
    let ad: Ad
    let sessionId: String
    let configuration: HTMLAdConfiguration
    weak var delegate: HTMLAdClickDelegate?
    
    @State private var hasReportedImpression = false
    @State private var browserURL: IdentifiableURL?
    
    /// Initialize with required parameters and optional configuration
    public init(
        ad: Ad,
        sessionId: String,
        configuration: HTMLAdConfiguration = .default,
        delegate: HTMLAdClickDelegate? = nil
    ) {
        self.ad = ad
        self.sessionId = sessionId
        self.configuration = configuration
        self.delegate = delegate
    }
    
    public var body: some View {
        Group {
            if let html = ad.html, !html.isEmpty {
                let size = parseAdSize()
                let scaledSize = calculateScaledSize(originalSize: size)
                
                HTMLWebView(
                    htmlString: html,
                    configuration: configuration,
                    onNavigationAction: handleNavigationAction
                )
                .frame(width: scaledSize.width, height: scaledSize.height)
            } else {
                EmptyView()
            }
        }
        .sheet(item: $browserURL) { identifiableURL in
            InAppBrowserView(url: identifiableURL.url)
                .onAppear {
                    GowitLogger.debug("Browser sheet appeared with URL: \(identifiableURL.url.absoluteString)")
                }
        }
    }
    
    // MARK: - Size Calculation
    
    private func parseAdSize() -> CGSize {
        guard let sizeString = ad.size else {
            return CGSize(width: 300, height: 250)
        }
        
        let components = sizeString.split(separator: "x")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]) else {
            return CGSize(width: 300, height: 250)
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func calculateScaledSize(originalSize: CGSize) -> CGSize {
        let screenWidth = UIScreen.main.bounds.width    
        // Don't scale if it fits
        guard originalSize.width > screenWidth else {
            return originalSize
        }
        
        // Scale proportionally
        let scale = screenWidth / originalSize.width
        return CGSize(width: screenWidth, height: originalSize.height * scale)
    }

    
    // MARK: - Navigation Handling
    
    private func handleNavigationAction(for url: URL) {
        Gowit Logger.debug("Navigation action detected")
        GowitLogger.debug("URL: \(url.absoluteString)")
        GowitLogger.debug("Click behavior: \(configuration.clickBehavior)")
        
        // Always notify delegate of click
        delegate?.adWasClicked(ad, clickedURL: url)
        
        // Handle based on behavior
        switch configuration.clickBehavior {
        case .openInApp:
            GowitLogger.debug("Mode: openInApp - opening browser directly")
            // Simple - just open in in-app browser
            // The browser will follow redirects naturally
            openInAppBrowser(url: url)
            
        case .handleByDelegate:
            GowitLogger.debug("Mode: handleByDelegate - resolving redirects first")
            // Resolve redirects and notify delegate
            resolveAndNotifyDelegate(url: url)
        }
    }
    
    private func resolveAndNotifyDelegate(url: URL) {
        GowitLogger.debug("Starting redirect resolution for: \(url.absoluteString)")
        Task {
            do {
                let config = RedirectHandlerConfiguration(
                    followRedirects: true,
                    maxRedirects: configuration.maxRedirects
                )
                let handler = RedirectHandler(configuration: config)
                let resolution = try await handler.resolveRedirectChain(from: url)
                
                GowitLogger.debug("Redirect resolution successful")
                GowitLogger.debug("Original URL: \(resolution.originalURL.absoluteString)")
                GowitLogger.debug("Final URL: \(resolution.finalURL.absoluteString)")
                GowitLogger.debug("Redirect count: \(resolution.redirectCount)")
                
                await MainActor.run {
                    // Notify success with details (optional callback)
                    delegate?.adClickResolved(ad, result: .success(resolution))
                    
                    // Give delegate the final URL (main callback)
                    delegate?.handleAdClick(ad, destinationURL: resolution.finalURL)
                }
            } catch {
                GowitLogger.error("Redirect resolution failed: \(error)")
                await MainActor.run {
                    // Notify failure (optional callback)
                    delegate?.adClickResolved(ad, result: .failure(error))
                }
            }
        }
    }
    
    private func openInAppBrowser(url: URL) {
        GowitLogger.debug("Opening in-app browser")
        GowitLogger.debug("URL: \(url.absoluteString)")
        browserURL = IdentifiableURL(url: url)
    }
}

// MARK: - Identifiable URL Wrapper

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - HTML WebView
struct HTMLWebView: UIViewRepresentable {
    let htmlString: String
    let configuration: HTMLAdConfiguration
    let onNavigationAction: (URL) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = configuration.allowsInlineMediaPlayback
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = configuration.isScrollEnabled
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update coordinator's callback
        context.coordinator.onNavigationAction = onNavigationAction
        
        // Load HTML if not already loaded
        if webView.isLoading == false && webView.url == nil {
            webView.loadHTMLString(htmlString, baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigationAction: onNavigationAction)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var onNavigationAction: (URL) -> Void
        
        init(onNavigationAction: @escaping (URL) -> Void) {
            self.onNavigationAction = onNavigationAction
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            GowitLogger.debug("decidePolicyFor called")
            GowitLogger.debug("Navigation type: \(navigationAction.navigationType.rawValue)")
            GowitLogger.debug("URL: \(navigationAction.request.url?.absoluteString ?? "nil")")
            GowitLogger.debug("Target frame main: \(navigationAction.targetFrame?.isMainFrame ?? false)")
            
            // Allow initial load, intercept link clicks
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                GowitLogger.debug("Link click detected!")
                // Handle the click
                onNavigationAction(url)
                decisionHandler(.cancel)
                return
            }
            
            GowitLogger.debug("Allowing navigation")
            decisionHandler(.allow)
        }
    }
}
