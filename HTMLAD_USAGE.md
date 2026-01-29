# HTML Ad Display - Usage Guide

This guide demonstrates how to use the HTML ad display components in the GoWit Swift SDK.

## Overview

The HTML ad display feature allows you to render ads with HTML content in a WebView, with full control over click behavior, redirect handling, and browser options.

## Components

### HTMLAdDisplayView
Main component for displaying HTML ads with automatic event tracking.

### InAppBrowserView  
Safari-style in-app browser for opening ad destinations.

### HTMLAdConfiguration
Configuration model for customizing ad behavior.

### HTMLAdDelegate
Protocol for receiving lifecycle callbacks.

### RedirectHandler
Utility for following redirect chains and resolving tracking URLs.

---

## Basic Usage

### 1. Simple HTML Ad Display

```swift
import AdViews

struct MyView: View {
    let ad: Ad
    let sessionId: String
    
    var body: some View {
        HTMLAdDisplayView(
            ad: ad,
            sessionId: sessionId
        )
    }
}
```

This will:
- Render the HTML in a WebView
- Automatically send impression events
- Send click events when the ad is clicked
- Open links in the in-app browser

---

## Advanced Usage

### 2. With Redirect Resolution

Follow redirect chains to resolve tracking URLs before opening:

```swift
HTMLAdDisplayView(
    ad: ad,
    sessionId: sessionId,
    configuration: .withRedirectResolution
)
```

This will:
- Follow 302/301 redirects
- Resolve to the final destination URL
- Then open the final URL in the browser

---

### 3. Custom Configuration

```swift
var config = HTMLAdConfiguration.default
config.clickBehavior = .resolveRedirects
config.useInAppBrowser = true
config.followRedirects = true
config.maxRedirects = 10

HTMLAdDisplayView(
    ad: ad,
    sessionId: sessionId,
    configuration: config
)
```

---

### 4. With Delegate Callbacks

```swift
class AdViewController: UIViewController, HTMLAdDelegate {
    let sessionId = UUID().uuidString
    
    func setupAdView() {
        let adView = HTMLAdDisplayView(
            ad: myAd,
            sessionId: sessionId,
            configuration: .delegateControlled,
            delegate: self
        )
        // Add to view hierarchy
    }
    
    // MARK: - HTMLAdDelegate
    
    func htmlAd(_ ad: Ad, willHandleClickOn url: URL) {
        print("Ad clicked: \(url)")
        // Track in your analytics
    }
    
    func htmlAd(_ ad: Ad, didResolveRedirectChain resolution: RedirectResolution) {
        print("Resolved from \(resolution.originalURL)")
        print("Final destination: \(resolution.finalURL)")
        print("Redirect count: \(resolution.redirectCount)")
        print("Is tracker: \(resolution.isTrackerURL)")
    }
    
    func htmlAd(_ ad: Ad, shouldOpenInAppBrowser url: URL) -> Bool {
        // Open external domains in Safari
        return !url.host?.contains("external.com") ?? true
    }
    
    func htmlAd(_ ad: Ad, didFailWithError error: Error) {
        print("Error: \(error)")
        // Show error to user
    }
    
    func htmlAd(_ ad: Ad, decidePolicyFor url: URL) -> NavigationPolicy {
        // Custom logic to decide how to handle each URL
        if url.host?.contains("trusted.com") == true {
            return .openInAppBrowser
        } else {
            return .openExternally
        }
    }
}
```

---

## Configuration Options

### Click Behavior

```swift
public enum ClickBehavior {
    case openDirectly           // Open immediately
    case resolveRedirects       // Follow 302s first
    case notifyDelegate         // Let delegate decide
}
```

### Preset Configurations

#### Default
```swift
.default
// - Opens links directly
// - Uses in-app browser
// - No redirect resolution
```

#### With Redirect Resolution
```swift
.withRedirectResolution
// - Follows redirect chains
// - Resolves to final URL
// - Opens in in-app browser
```

#### Delegate Controlled
```swift
.delegateControlled
// - All decisions via delegate
// - Maximum flexibility
```

---

## In-App Browser

The in-app browser is automatically shown when configured. You can also use it standalone:

```swift
@State private var showBrowser = false
@State private var browserURL: URL?

Button("Open Link") {
    browserURL = URL(string: "https://example.com")!
    showBrowser = true
}
.sheet(isPresented: $showBrowser) {
    if let url = browserURL {
        InAppBrowserView(isPresented: $showBrowser, url: url)
    }
}
```

Features:
- Back/forward navigation
- Refresh button
- Close button
- Progress indicator
- Full WebKit support

---

## Redirect Handling

### Manual Redirect Resolution

You can also use the `RedirectHandler` directly:

```swift
let handler = RedirectHandler()

Task {
    do {
        let resolution = try await handler.resolveRedirectChain(
            from: trackingURL
        )
        
        print("Original: \(resolution.originalURL)")
        print("Final: \(resolution.finalURL)")
        print("Redirects: \(resolution.redirectCount)")
        
        // Open the final URL
        await openURL(resolution.finalURL)
    } catch {
        print("Failed to resolve: \(error)")
    }
}
```

### Custom Configuration

```swift
var config = RedirectHandlerConfiguration.default
config.maxRedirects = 15
config.timeout = 15.0

let handler = RedirectHandler(configuration: config)
```

---

## Complete Integration Example

```swift
import SwiftUI
import AdViews
import Gowit

struct HomeView: View {
    @State private var adResponse: AdResponse?
    @State private var isLoading = false
    
    private let sessionId = UUID().uuidString
    private let placementId = 4
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Your content
                Text("Featured Content")
                
                // HTML Ad
                if let ad = adResponse?.getAds(for: placementId)?.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sponsored")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HTMLAdDisplayView(
                            ad: ad,
                            sessionId: sessionId,
                            configuration: .withRedirectResolution
                        )
                    }
                    .padding()
                }
                
                // More content
                Text("More Content")
            }
        }
        .task {
            await loadAds()
        }
    }
    
    private func loadAds() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await Gowit.shared.getAds(
                placementId: placementId,
                sessionId: sessionId
            )
            
            await MainActor.run {
                self.adResponse = response
            }
        } catch {
            print("Failed to load ads: \(error)")
        }
    }
}
```

---

## Best Practices

### 1. Session Management
Use a consistent session ID throughout the user's session:
```swift
let sessionId = UUID().uuidString
// Use this sessionId for all ad requests and events in this session
```

### 2. Error Handling
Always implement the error callback:
```swift
func htmlAd(_ ad: Ad, didFailWithError error: Error) {
    // Log error
    // Show fallback content
    // Retry if appropriate
}
```

### 3. Redirect Resolution
Use redirect resolution for tracking URLs:
```swift
// If your ads use tracking URLs like:
// http://tracking.example.com/click?redirect=https://destination.com

// Use this configuration:
.withRedirectResolution
```

### 4. Privacy
The redirect handler uses HEAD requests to minimize data transfer and respect user privacy.

---

## Troubleshooting

### Ad Not Displaying
- Check that `ad.html` is not nil or empty
- Verify the HTML is valid
- Check console for error messages

### Clicks Not Working
- Ensure the HTML contains clickable elements (e.g., `<a>` tags)
- Check that the URL scheme is supported (http/https)
- Verify click events are being sent (check network logs)

### In-App Browser Not Showing
- Check that `configuration.useInAppBrowser` is `true`
- Verify the URL is valid
- Ensure the sheet presentation is working

### Redirects Not Resolving
- Check network connectivity
- Verify the redirect chain is less than `maxRedirects`
- Check that the server is returning proper redirect status codes (301, 302, etc.)

---

## API Reference

### HTMLAdDisplayView

```swift
init(
    ad: Ad,
    sessionId: String,
    configuration: HTMLAdConfiguration = .default,
    delegate: HTMLAdDelegate? = nil
)
```

### HTMLAdConfiguration

Properties:
- `clickBehavior: ClickBehavior`
- `followRedirects: Bool`
- `maxRedirects: Int`
- `resolveBeforeOpening: Bool`
- `useInAppBrowser: Bool`
- `allowExternalBrowser: Bool`
- `allowsInlineMediaPlayback: Bool`
- `isScrollEnabled: Bool`

Presets:
- `.default`
- `.withRedirectResolution`
- `.delegateControlled`

### HTMLAdDelegate

Methods (all optional):
- `htmlAd(_:willHandleClickOn:)`
- `htmlAd(_:didResolveRedirectChain:)`
- `htmlAd(_:shouldOpenInAppBrowser:) -> Bool`
- `htmlAd(_:didFailWithError:)`
- `htmlAd(_:decidePolicyFor:) -> NavigationPolicy`

### RedirectHandler

```swift
init(configuration: RedirectHandlerConfiguration = .default)

func resolveRedirectChain(from url: URL) async throws -> RedirectResolution
```

### RedirectResolution

Properties:
- `originalURL: URL`
- `finalURL: URL`
- `redirectCount: Int`
- `isTrackerURL: Bool`
