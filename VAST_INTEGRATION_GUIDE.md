# VAST Video Ad Integration Guide

This guide covers the integration of VAST (Video Ad Serving Template) video ads into your iOS application using the Gowit Swift SDK.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration Options](#configuration-options)
- [Event Callbacks](#event-callbacks)
- [Product Extensions](#product-extensions)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [API Reference](#api-reference)

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the Gowit Swift SDK to your project:

```swift
dependencies: [
    .package(url: "https://github.com/gowittechnology/gowit-swift.git", from: "1.0.2")
]
```

### Xcode

1. Open your Xcode project
2. Go to **File > Add Package Dependencies**
3. Enter the repository URL: `https://github.com/gowittechnology/gowit-swift.git`
4. Select the version and add to your target

## Quick Start

### Basic Implementation

```swift
import SwiftUI
import AdViews

struct ContentView: View {
    // Your VAST tag URL
    private let vastURL = URL(string: "https://your-ad-server.com/vast")!
    
    var body: some View {
        VideoAdView(
            vastURL: vastURL,
            configuration: .default,
            onAdStarted: {
                print("Ad started playing")
            },
            onAdCompleted: {
                print("Ad completed")
            }
        )
        .frame(height: 220)
        .padding()
    }
}
```

### With Full Configuration

```swift
VideoAdView(
    vastURL: vastURL,
    configuration: VideoAdConfiguration(
        loadingBehavior: .shimmer,
        postAdBehavior: .replay,
        isMutedByDefault: true,
        showMuteButton: true,
        showAdLabel: true,
        adLabelText: "Ad",
        cornerRadius: 12
    ),
    onAdLoaded: { ad in
        print("Ad loaded: \(ad.id)")
    },
    onAdStarted: {
        print("Playback started")
    },
    onAdCompleted: {
        print("Playback completed")
    },
    onAdClicked: { url in
        print("User clicked: \(url)")
    },
    onError: { error in
        print("Error: \(error.localizedDescription)")
    }
)
.frame(height: 220)
```

## Configuration Options

### VideoAdConfiguration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `loadingBehavior` | `LoadingBehavior` | `.hidden` | What to display while loading |
| `postAdBehavior` | `PostAdBehavior` | `.replay` | What to do after ad finishes |
| `isMutedByDefault` | `Bool` | `true` | Start video muted |
| `visibilityThreshold` | `CGFloat` | `0.5` | Minimum visibility to auto-play (0.0-1.0) |
| `autoPlay` | `Bool` | `true` | Auto-play when visible |
| `showMuteButton` | `Bool` | `true` | Show mute/unmute button |
| `showAdLabel` | `Bool` | `true` | Show "Ad" label |
| `adLabelText` | `String` | `"Ad"` | Custom label text |
| `cornerRadius` | `CGFloat` | `8` | Corner radius |
| `maxWrapperDepth` | `Int` | `5` | Max VAST wrapper redirects |
| `requestTimeout` | `TimeInterval` | `30` | Network timeout (seconds) |
| `aspectRatio` | `CGFloat` | `16/9` | Video aspect ratio |
| `debugLogging` | `Bool` | `false` | Enable console logging |

### Loading Behaviors

```swift
// Hide until ready
.loadingBehavior: .hidden

// Show SF Symbol while loading
.loadingBehavior: .systemImage(name: "play.circle")

// Show text while loading
.loadingBehavior: .text("Loading ad...")

// Show colored placeholder
.loadingBehavior: .placeholder(.gray.opacity(0.2))

// Show shimmer animation
.loadingBehavior: .shimmer
```

### Post-Ad Behaviors

```swift
// Loop the video
.postAdBehavior: .replay

// Fetch new ad from same URL
.postAdBehavior: .refreshAd

// Freeze on last frame
.postAdBehavior: .showLastFrame

// Hide the view
.postAdBehavior: .hide
```

### Preset Configurations

```swift
// Default configuration
VideoAdConfiguration.default

// Continuous loop playback
VideoAdConfiguration.continuous

// Single play, show last frame
VideoAdConfiguration.singlePlay

// Refresh ad after completion
VideoAdConfiguration.refreshing

// Custom loading image
VideoAdConfiguration.withLoadingImage(systemName: "play.circle.fill")

// Custom loading text
VideoAdConfiguration.withLoadingText("Loading...")
```

## Event Callbacks

### Available Callbacks

| Callback | Parameters | Description |
|----------|------------|-------------|
| `onAdLoaded` | `VASTAd` | Ad successfully loaded |
| `onAdStarted` | - | Video playback started |
| `onAdCompleted` | - | Video playback finished |
| `onAdClicked` | `URL` | User tapped the video |
| `onError` | `VASTError` | An error occurred |
| `onStateChanged` | `VideoAdState` | State changed |

### State Tracking

Monitor the ad state for custom UI updates:

```swift
VideoAdView(
    vastURL: vastURL,
    configuration: .default,
    onStateChanged: { state in
        switch state {
        case .idle:
            print("Idle - not loaded")
        case .loading:
            print("Loading VAST and video")
        case .ready:
            print("Ready to play")
        case .playing:
            print("Currently playing")
        case .paused:
            print("Paused")
        case .completed:
            print("Playback completed")
        case .error(let message):
            print("Error: \(message)")
        case .noAd:
            print("No ad available")
        case .hidden:
            print("Hidden")
        }
    }
)
```

## Product Extensions

The SDK supports VAST product extensions, allowing you to access product metadata from the ad response:

```swift
VideoAdView(
    vastURL: vastURL,
    configuration: .default,
    onAdLoaded: { ad in
        // Access product extensions
        if let products = ad.inLine?.extensions, !products.isEmpty {
            for product in products {
                print("Brand: \(product.brand ?? "N/A")")
                print("Name: \(product.name ?? "N/A")")
                print("Price: \(product.price ?? 0)")
                print("Image: \(product.imageURL ?? "N/A")")
                print("SKU: \(product.sku ?? "N/A")")
                print("Rating: \(product.rating ?? 0)")
            }
        }
    }
)
```

### VASTProduct Properties

| Property | Type | Description |
|----------|------|-------------|
| `advertiserID` | `String?` | Advertiser identifier |
| `brand` | `String?` | Product brand |
| `name` | `String?` | Product name |
| `price` | `Double?` | Product price |
| `imageURL` | `String?` | Product image URL |
| `pdpURL` | `String?` | Product detail page URL |
| `sku` | `String?` | Product SKU |
| `rating` | `Double?` | Product rating |
| `stockCount` | `Int?` | Stock count |

## Customization

### Visibility-Based Playback

The video automatically pauses when scrolled out of view and resumes when visible:

```swift
VideoAdConfiguration(
    visibilityThreshold: 0.5,  // 50% visible to play
    autoPlay: true
)
```

### Disable Auto-Play

```swift
VideoAdConfiguration(
    autoPlay: false  // User must trigger playback
)
```

### Custom Aspect Ratio

```swift
VideoAdConfiguration(
    aspectRatio: 4.0 / 3.0  // 4:3 aspect ratio
)
```

### Silent Ads

```swift
VideoAdConfiguration(
    isMutedByDefault: true,
    showMuteButton: false  // Hide mute button
)
```

## Troubleshooting

### Enable Debug Logging

```swift
VideoAdConfiguration(
    debugLogging: true
)
```

This will output detailed logs:

```
[VideoAdView] Fetching VAST from: https://...
[VideoAdView] VAST parsed - Ads count: 1
[VideoAdView] MediaFile - URL: https://..., Type: video/mp4
[VideoAdView] Player item status: readyToPlay
[VideoAdView] performPlay() - calling player.play()
```

### Common Issues

#### Video Not Playing

1. Check that the VAST URL is accessible
2. Enable `debugLogging` to see detailed errors
3. Verify the video format is supported (MP4 recommended)

#### No Ad Displayed

The `onError` callback will be called with `VASTError.noAdsFound` if:
- The VAST response contains no ads
- All ads failed to load

```swift
onError: { error in
    if case .noAdsFound = error {
        // Hide ad view or show fallback content
    }
}
```

#### Network Errors

```swift
onError: { error in
    switch error {
    case .networkError(let message):
        print("Network issue: \(message)")
    case .timeout:
        print("Request timed out")
    default:
        print("Other error: \(error)")
    }
}
```

## API Reference

### VideoAdView

```swift
public struct VideoAdView: View {
    public init(
        vastURL: URL,
        configuration: VideoAdConfiguration = .default,
        onAdLoaded: ((VASTAd) -> Void)? = nil,
        onAdStarted: (() -> Void)? = nil,
        onAdCompleted: (() -> Void)? = nil,
        onAdClicked: ((URL) -> Void)? = nil,
        onError: ((VASTError) -> Void)? = nil,
        onStateChanged: ((VideoAdState) -> Void)? = nil
    )
}
```

### VASTError

| Case | Description |
|------|-------------|
| `.networkError(String)` | Network request failed |
| `.parsingError(String)` | Failed to parse VAST XML |
| `.noAdsFound` | No ads in response |
| `.wrapperDepthExceeded(Int)` | Too many wrapper redirects |
| `.invalidMediaFile` | No valid video file |
| `.invalidURL(String)` | Invalid URL in response |
| `.timeout` | Request timed out |
| `.unknown(String)` | Unknown error |

### VideoAdState

| Case | Description |
|------|-------------|
| `.idle` | Initial state |
| `.loading` | Loading VAST/video |
| `.ready` | Ready to play |
| `.playing` | Currently playing |
| `.paused` | Paused |
| `.completed` | Finished playing |
| `.error(String)` | Error occurred |
| `.noAd` | No ad available |
| `.hidden` | Hidden after completion |

### VideoAdDelegate Protocol

For UIKit integration, implement the delegate protocol:

```swift
public protocol VideoAdDelegate: AnyObject {
    func videoAdDidLoad(_ ad: VASTAd)
    func videoAdDidStart()
    func videoAdDidComplete()
    func videoAdDidClick(url: URL)
    func videoAdDidFail(error: VASTError)
    func videoAdStateDidChange(_ state: VideoAdState)
}
```

## VAST Tracking Events

The SDK automatically fires VAST tracking events:

| Event | When Fired |
|-------|-----------|
| Impression | When ad is loaded |
| Start | When playback begins |
| FirstQuartile | At 25% completion |
| Midpoint | At 50% completion |
| ThirdQuartile | At 75% completion |
| Complete | At 100% completion |
| Pause | When paused |
| Resume | When resumed |
| Mute | When muted |
| Unmute | When unmuted |
| Click | When user taps |

## Support

- GitHub Issues: [Report Issues](https://github.com/gowittechnology/gowit-swift/issues)
- Documentation: [Official Documentation](https://docs.gowit.com)
- Contact: support@gowit.com
