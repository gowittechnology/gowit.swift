import SwiftUI
import WebKit
import Gowit

#if canImport(UIKit)
import UIKit
#endif

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
    weak var delegate: HTMLAdDelegate?
    
    @State private var hasReportedImpression = false
    @State private var showInAppBrowser = false
    @State private var browserURL: URL?
    
    /// Initialize with required parameters and optional configuration
    public init(
        ad: Ad,
        sessionId: String,
        configuration: HTMLAdConfiguration = .default,
        delegate: HTMLAdDelegate? = nil
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
                .onAppear {
                    reportImpressionIfNeeded()
                }
            } else {
                EmptyView()
            }
        }
        #if os(iOS) || os(tvOS)
        .sheet(isPresented: $showInAppBrowser) {
            if let url = browserURL {
                InAppBrowserView(isPresented: $showInAppBrowser, url: url)
            }
        }
        #endif
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
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        #elseif os(macOS)
        let screenWidth = NSScreen.main?.frame.width ?? 800
        #else
        let screenWidth: CGFloat = 800
        #endif
        
        // Don't scale if it fits
        guard originalSize.width > screenWidth else {
            return originalSize
        }
        
        // Scale proportionally
        let scale = screenWidth / originalSize.width
        return CGSize(width: screenWidth, height: originalSize.height * scale)
    }
    
    // MARK: - Event Tracking
    
    private func reportImpressionIfNeeded() {
        guard !hasReportedImpression else { return }
        
        hasReportedImpression = true
        
        Task {
            do {
                if let adId = ad.adId {
                    try await Gowit.shared.sendImpressionEvent(adId: adId, sessionId: sessionId)
                }
            } catch {
                print("Failed to send impression event: \(error)")
                delegate?.htmlAd(ad, didFailWithError: error)
            }
        }
    }
    
    private func reportClick() {
        Task {
            do {
                if let adId = ad.adId {
                    try await Gowit.shared.sendClickEvent(adId: adId, sessionId: sessionId)
                }
            } catch {
                print("Failed to send click event: \(error)")
                delegate?.htmlAd(ad, didFailWithError: error)
            }
        }
    }
    
    // MARK: - Navigation Handling
    
    private func handleNavigationAction(for url: URL) {
        // Notify delegate
        delegate?.htmlAd(ad, willHandleClickOn: url)
        
        // Send click event
        reportClick()
        
        // Handle based on configuration
        switch configuration.clickBehavior {
        case .openDirectly:
            openURL(url)
            
        case .resolveRedirects:
            resolveAndOpenURL(url)
            
        case .notifyDelegate:
            // Let delegate decide
            if let policy = delegate?.htmlAd(ad, decidePolicyFor: url) {
                handleNavigationPolicy(policy, for: url)
            } else {
                // Default if no delegate
                openURL(url)
            }
        }
    }
    
    private func handleNavigationPolicy(_ policy: NavigationPolicy, for url: URL) {
        switch policy {
        case .allow:
            openURL(url)
        case .cancel:
            break // Do nothing
        case .openInAppBrowser:
            openInAppBrowser(url: url)
        case .openExternally:
            openExternally(url: url)
        }
    }
    
    private func resolveAndOpenURL(_ url: URL) {
        guard configuration.resolveBeforeOpening else {
            openURL(url)
            return
        }
        
        Task {
            do {
                let config = RedirectHandlerConfiguration(
                    followRedirects: configuration.followRedirects,
                    maxRedirects: configuration.maxRedirects
                )
                let handler = RedirectHandler(configuration: config)
                let resolution = try await handler.resolveRedirectChain(from: url)
                
                // Notify delegate
                await MainActor.run {
                    delegate?.htmlAd(ad, didResolveRedirectChain: resolution)
                }
                
                // Open the final URL
                await MainActor.run {
                    openURL(resolution.finalURL)
                }
            } catch {
                print("Failed to resolve redirect chain: \(error)")
                await MainActor.run {
                    delegate?.htmlAd(ad, didFailWithError: error)
                    // Fall back to opening original URL
                    openURL(url)
                }
            }
        }
    }
    
    private func openURL(_ url: URL) {
        if configuration.useInAppBrowser {
            // Ask delegate if they want to override
            let shouldUseInApp = delegate?.htmlAd(ad, shouldOpenInAppBrowser: url) ?? true
            
            if shouldUseInApp {
                openInAppBrowser(url: url)
            } else {
                openExternally(url: url)
            }
        } else if configuration.allowExternalBrowser {
            openExternally(url: url)
        }
    }
    
    private func openInAppBrowser(url: URL) {
        browserURL = url
        showInAppBrowser = true
    }
    
    private func openExternally(url: URL) {
        #if os(iOS) || os(tvOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - HTML WebView

#if os(iOS) || os(tvOS)
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
            // Allow initial load, intercept link clicks
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                // Handle the click
                onNavigationAction(url)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
    }
}
#else
// macOS placeholder - WebView implementation can be added later
struct HTMLWebView: View {
    let htmlString: String
    let configuration: HTMLAdConfiguration
    let onNavigationAction: (URL) -> Void
    
    var body: some View {
        Text("HTML ads require iOS/tvOS")
    }
}
#endif

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Sample HTML ad
        let sampleAd = Ad(
            adId: "preview-ad-123",
            creativeId: 1,
            size: "320x100",
            html: """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body { margin: 0; padding: 0; }
                    .ad { 
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        padding: 20px;
                        text-align: center;
                        color: white;
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    }
                    .ad h2 { margin: 0 0 10px 0; }
                    .ad p { margin: 0; }
                    a { color: white; text-decoration: none; }
                </style>
            </head>
            <body>
                <div class="ad">
                    <h2>Premium Product</h2>
                    <p>Click to learn more</p>
                    <a href="https://example.com/product">Shop Now →</a>
                </div>
            </body>
            </html>
            """
        )
        
        Text("Default Configuration")
            .font(.headline)
        
        HTMLAdDisplayView(
            ad: sampleAd,
            sessionId: "preview-session"
        )
        
        Text("With Redirect Resolution")
            .font(.headline)
        
        HTMLAdDisplayView(
            ad: sampleAd,
            sessionId: "preview-session",
            configuration: .withRedirectResolution
        )
        
        Spacer()
    }
    .padding()
}
