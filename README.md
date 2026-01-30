# Gowit Swift SDK

Swift SDK for integrating Gowit's advertising platform into iOS applications. This SDK provides comprehensive functionality for ad serving, and event reporting.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Ad Requests](#ad-requests)
- [Event Reporting](#event-reporting)
- [SwiftUI Components](#swiftui-components)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/gowittechnology/gowit-swift.git", from: "1.0.2")
]
```

### Xcode

1. Open your Xcode project
2. Go to File > Add Package Dependencies
3. Enter the repository URL: `https://github.com/gowittechnology/gowit-swift.git`
4. Select the version and add to your target

## Quick Start

### Basic Setup
```swift
import Gowit

// Configure the SDK with your credentials
Gowit.shared.configure(
    hostname: "https://platform.gowit.com",
    marketplaceId: "MARKETPLACE_UUID"
)
```

```swift
import SwiftUI
import Gowit
@main
struct Demo_AppApp: App {

    init() {
        Gowit.shared.configure(hostname: "https://platform-stage.gowit.com", marketplaceId: "MARKETPLACE_UUID")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

```

### Configuration with Auto-Impression

When auto-impression is enabled, the platform automatically counts ad responses as impressions, eliminating the need for manual impression reporting.
Before setting it to true please consult to Onboarding Team first:

```swift
Gowit.shared.configure(
    hostname: "https://platform.gowit.com",
    marketplaceId: "MARKETPLACE_UUID",
    autoImpressionEnabled: true
)
```

### Request Ads

```swift
// Simple ad request
let response = try await Gowit.shared.getAds(
    placementId: 5,
    sessionId: "user-session-123"
)

if let ads = response.getAds(for: 5) {
    print("Retrieved \(ads.count) ads")
}
```

### Report Events

```swift
// Report impression
try await Gowit.shared.sendImpressionEvent(
    adId: "ad-12345",
    sessionId: "user-session-123"
)

// Report click
try await Gowit.shared.sendClickEvent(
    adId: "ad-12345",
    sessionId: "user-session-123"
)
```

## Ad Requests

### Single Placement Request

```swift
let response = try await Gowit.shared.getAds(
    placementId: 5,
    pageNumber: 0,
    sessionId: "user-session-123"
)
```

### Multiple Placements Request

```swift
let placements = [
    PlacementRequest(placementId: 1, maxAds: 5),
    PlacementRequest(placementId: 2, maxAds: 3),
    PlacementRequest(placementId: 3, maxAds: 10)
]

let response = try await Gowit.shared.getAds(
    placements: placements,
    sessionId: "user-session-123"
)
```

### Builder API (Recommended)

The Builder API provides a fluent interface for constructing ad requests with enhanced readability and flexibility:

#### Basic Builder Usage

```swift
let request = AdRequestBuilder(placementId: 11)
    .with(sessionId: "user-session-123")
    .with(pageNumber: 0)

let response = try await Gowit.shared.getAds(request)
```

#### Builder with Product Context

```swift
let products = [
    ProductRequest(productId: "PROD-001", category: "Electronics > Smartphones"),
    ProductRequest(productId: "PROD-002", category: "Electronics > Accessories")
]

let request = AdRequestBuilder(placementId: 11)
    .with(sessionId: "user-session-123")
    .with(products: products)
    .with(search: "iPhone cases")

let response = try await Gowit.shared.getAds(request)
```

#### Builder with Customer Context

```swift
let customer = Customer(
    id: "customer-123",
    customerId: "external-id-456",
    gender: "Female",
    age: 28,
    city: "San Francisco",
    deviceType: "Mobile"
)

let request = AdRequestBuilder(placementId: 5)
    .with(sessionId: "user-session-123")
    .with(customer: customer)
    .with(search: "summer sandals")
    .with(locationId: "SF-01")
    .with(language: "en")

let response = try await Gowit.shared.getAds(request)
```

### Advanced Placement Filtering

Placement filters use nested arrays where each inner array represents an OR-group, and the outer array applies AND semantics:

```swift
let placements = [
    PlacementRequest(
        placementId: 10,
        filters: [
            ["brand:apple", "brand:samsung"],      // (brand is Apple OR Samsung)
            ["category:electronics"],              // AND (category is Electronics)
            ["price:100-500"]                     // AND (price is 100-500)
        ],
        maxAds: 5
    )
]
```

## Event Reporting

### Supported Event Types

The SDK supports four event types:
- **impression**: When an ad is displayed to the user
- **click**: When a user interacts with an ad
- **sale**: Whenever an order is made

### Basic Event Reporting

```swift
let sessionId = "user-session-123"
let adId = "ad-12345"

// Report impression
try await Gowit.shared.sendImpressionEvent(adId: adId, sessionId: sessionId)

// Report viewable impression
try await Gowit.shared.sendViewableImpressionEvent(adId: adId, sessionId: sessionId)

// Report click
try await Gowit.shared.sendClickEvent(adId: adId, sessionId: sessionId)

// Report sale
let sale = Sale(
    advertiserId: "advertiser-789",
    quantity: 2,
    unitPrice: 49.99,
    productId: "product-456"
)
try await Gowit.shared.sendSaleEvent(sales: [sale], sessionId: sessionId)
```

### Convenience Methods with Ad Objects

```swift
let response = try await Gowit.shared.getAds(placementId: 5, sessionId: "session-123")

if let ads = response.getAds(for: 5) {
    for ad in ads {
        // Report impression using convenience method
        try await Gowit.shared.sendImpressionEvent(for: ad, sessionId: "session-123")

        // Report click using convenience method
        try await Gowit.shared.sendClickEvent(for: ad, sessionId: "session-123")
    }
}
```

### Bulk Sale Reporting

```swift
let sales = [
    Sale(advertiserId: "adv-001", quantity: 1, unitPrice: 99.99, productId: "prod-001"),
    Sale(advertiserId: "adv-002", quantity: 2, unitPrice: 29.99, productId: "prod-002")
]

try await Gowit.shared.sendSaleEvent(sales: sales, sessionId: "session-456")
```

## Supported Ad Types

### Sponsored Display vs Sponsored Product Ads

The SDK supports two main types of ads:

#### Sponsored Display Ads
- Contain `img_url`, or `html`, and `redirect` information
- Ready to display directly to users

##### Image-Based Display Ads
Use `SponsoredDisplayView` for image-based display ads:
```swift
SponsoredDisplayView(placementId: 5, sessionId: sessionId)
```

##### HTML Display Ads

Use `HTMLAdDisplayView` for HTML-based display ads:

```swift
import AdViews

HTMLAdDisplayView(
    ad: ad,
    sessionId: sessionId,
    configuration: .default
)
```

**Configuration Options:**

The SDK provides three preset configurations for different use cases:

| Configuration | Click Behavior | Use Case |
|--------------|---------------|----------|
| `.default` | Opens URL in in-app browser | Standard clickable ads |
| `.delegateHandled` | Resolves redirects, notifies delegate | Custom URL handling, deep linking |

**Basic Usage:**

```swift
// Default configuration - opens in in-app browser
HTMLAdDisplayView(
    ad: htmlAd,
    sessionId: "session-123",
    configuration: .default
)
```

**Custom Configuration:**

```swift
// Create custom configuration
var config = HTMLAdConfiguration.default
config.maxRedirects = 10
config.isScrollEnabled = true

HTMLAdDisplayView(
    ad: htmlAd,
    sessionId: "session-123",
    configuration: config
)
```

**Delegate-Controlled Behavior:**

For advanced use cases like deep link handling or custom URL processing:

```swift
class AdClickHandler: HTMLAdClickDelegate {
    // Called when user clicks the ad
    func adWasClicked(_ ad: Ad, clickedURL: URL) {
        print("Ad clicked: \(clickedURL)")
    }
    
    // Called with final URL after redirect resolution
    func handleAdClick(_ ad: Ad, destinationURL: URL) {
        // Handle deep links
        if destinationURL.scheme == "myapp" {
            handleDeepLink(url: destinationURL)
        } else {
            // Open in Safari or custom browser
            UIApplication.shared.open(destinationURL)
        }
    }
    
    // Optional: Track redirect chain for analytics
    func adClickResolved(_ ad: Ad, result: Result<RedirectResolution, Error>) {
        switch result {
        case .success(let resolution):
            print("Resolved \(resolution.redirectCount) redirects")
            print("Final URL: \(resolution.finalURL)")
        case .failure(let error):
            print("Resolution failed: \(error)")
        }
    }
}

// Use with delegate
let handler = AdClickHandler()
HTMLAdDisplayView(
    ad: htmlAd,
    sessionId: "session-123",
    configuration: .delegateHandled,
    delegate: handler
)
```

**Features:**

- WebView-based HTML rendering with automatic size calculation
- Responsive scaling to fit screen width
- Configurable click handling (in-app browser or delegate-controlled)
- Automatic redirect chain resolution for tracking URLs
- Optional delegate callbacks for analytics and custom URL handling

#### Sponsored Product Ads
- Contain a `product_id` (SKU) for catalog integration
- Require customers to query their catalog for product details

### Ad Type Detection

```swift
let response = try await Gowit.shared.getAds(placementId: 5, sessionId: "session-123")

for ad in response.allAds {
    if ad.isProductAd {
        // Handle product ad - query catalog with ad.sku
        print("Product SKU: \(ad.sku ?? "unknown")")
    } else if ad.isDisplayAd {
        // Handle display ad - show image directly
        print("Display Image: \(ad.displayImageUrl ?? "none")")
    }
}
```

### Product Ad Integration

```swift
// Get all product ads and their SKUs
let productAds = response.allProductAds
let allSKUs = response.allSKUs

// Check specific placement for product ads
if response.hasProductAds(for: 5) {
    let skus = response.getSKUs(for: 5)
    // Query your catalog with these SKUs
}
```

## Rendering Product Ads
The Ad platform returns the product_id (the one used in the integration step) for you to retrieve products metadata, and render your own ProductView with the ultimate flexibility.
Following code block is just a reference, the best setup depends on your specific use-case(s) & scenario(s)

```swift

struct ProductListingView: View {
    @State private var products: [CatalogProduct] = []
    @State private var isLoading = true
    @State private var error: String?

    private let sessionId = UUID().uuidString
    private let placementId = 5 // Your product placement ID

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading products...")
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    productGrid
                }
            }
            .navigationTitle("Products")
            .task {
                await loadProductsWithAds()
            }
        }
    }

    private var productGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(products, id: \.id) { product in
                    ProductCardView(
                        product: product,
                        sessionId: sessionId
                    )
                }
            }
            .padding()
        }
    }

    private func loadProductsWithAds() async {
        isLoading = true
        error = nil

        do {
            // Load organic products and ads in parallel
            async let catalogProducts = fetchCatalogProducts()
            async let adResponse = Gowit.shared.getAds(
                placementId: placementId,
                sessionId: sessionId
            )

            let (organic, ads) = try await (catalogProducts, adResponse)
            let productAds = ads.getProductAds(for: placementId) ?? []

            // Merge products with ads
            let mergedProducts = mergeProductsWithAds(
                catalogProducts: organic,
                productAds: productAds,
                sessionId: sessionId
            )

            await MainActor.run {
                self.products = mergedProducts
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchCatalogProducts() async throws -> [YourCatalogProduct] {
        // Your catalog API call
        // This should return your regular product catalog
        return []
    }
}

struct ProductCardView: View {
    let product: CatalogProduct
    let sessionId: String
    @State private var hasReportedImpression = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            AsyncImage(url: product.imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
            }
            .cornerRadius(8)

            // Sponsored Label (optional)
            if product.isSponsored {
                Text("Sponsored")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let rating = product.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                }

                Text("$\(product.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .onAppear {
            // Report impression for sponsored products
            if product.isSponsored && !hasReportedImpression {
                reportImpression()
            }
        }
        .onTapGesture {
            // Report click for sponsored products
            if product.isSponsored {
                reportClick()
            }

            // Navigate to product details
            navigateToProduct()
        }
    }

    private func reportImpression() {
        guard let adId = product.adId else { return }

        Task {
            do {
                try await Gowit.shared.sendImpressionEvent(
                    adId: adId,
                    sessionId: sessionId
                )
                await MainActor.run {
                    hasReportedImpression = true
                }
            } catch {
                print("Failed to send impression: \(error)")
            }
        }
    }

    private func reportClick() {
        guard let adId = product.adId else { return }

        Task {
            do {
                try await Gowit.shared.sendClickEvent(
                    adId: adId,
                    sessionId: sessionId
                )
            } catch {
                print("Failed to send click: \(error)")
            }
        }
    }

    private func navigateToProduct() {
        // Your navigation logic here
        print("Navigating to product: \(product.name)")
    }
}
```

## SwiftUI Components

### SponsoredDisplayView

The `SponsoredDisplayView` component provides automatic ad display and event reporting (impression and click):

```swift
import AdViews

SponsoredDisplayView(placementId: 5, sessionId: "user-session-123")
    .frame(height: 200)
```

### SponsoredProductView

For displaying product ads with custom product details:

```swift
import AdViews

SponsoredProductView(
    imageUrl: "https://catalog.com/product.jpg",
    title: "Premium Wireless Headphones",
    price: "$199.99",
    rating: 4.5,
    onTap: {
        // Handle product tap
        navigateToProduct()
    }
)
```

### SponsoredProductAdView

Automatic product ad component with SKU integration:

```swift
import AdViews

// With external product details (recommended)
SponsoredProductAdView(
    ad: productAd,
    sessionId: "session-123",
    productImageUrl: catalogImageUrl,
    productTitle: catalogTitle,
    productPrice: catalogPrice,
    productRating: catalogRating,
    onProductQuery: { sku in
        // Query your catalog for this SKU
        loadProductDetails(sku: sku)
    }
)

// Using ad's built-in product information
SponsoredProductAdView(
    ad: productAd,
    sessionId: "session-123"
)
```



## Error Handling

### Comprehensive Error Handling

```swift
do {
    let response = try await Gowit.shared.getAds(
        placementId: 5,
        sessionId: "test-session"
    )

    if response.allAds.isEmpty {
        print("No ads available")
    } else {
        print("Retrieved \(response.allAds.count) ads successfully")
    }

} catch let error as AdError {
    switch error {
    case .invalidPlacements:
        print("Error: Invalid placement configuration")
    case .serializationError:
        print("Error: Failed to serialize request")
    case .configurationError(let message):
        print("Configuration error: \(message)")
    case .invalidAdId:
        print("Error: Invalid ad ID provided")
    case .http(let httpError):
        print("HTTP error: \(httpError)")
    case .deserializationError(let deserializationError, _):
        print("Deserialization error: \(deserializationError)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```


## API Reference

### Core Classes

#### Gowit

The main SDK interface providing ad request and event reporting functionality.

**Configuration Methods:**
- `configure(apiKey:hostname:marketplaceId:)`
- `configure(apiKey:hostname:marketplaceId:autoImpressionEnabled:)`

**Ad Request Methods:**
- `getAds(placementId:pageNumber:sessionId:) -> AdResponse`
- `getAds(placements:pageNumber:sessionId:) -> AdResponse`
- `getAds(_:AdRequestBuilder) -> AdResponse`

**Event Reporting Methods:**
- `sendImpressionEvent(adId:sessionId:)`
- `sendViewableImpressionEvent(adId:sessionId:)`
- `sendClickEvent(adId:sessionId:)`
- `sendSaleEvent(sales:sessionId:)`

#### AdRequestBuilder

Fluent interface for constructing ad requests with enhanced readability.

**Initialization:**
- `init(placementId:Int)`
- `init(placementIds:[Int])`
- `init(placements:[PlacementRequest])`

**Configuration Methods:**
- `with(sessionId:String) -> AdRequestBuilder`
- `with(pageNumber:Int) -> AdRequestBuilder`
- `with(customer:Customer) -> AdRequestBuilder`
- `with(products:[ProductRequest]) -> AdRequestBuilder`
- `with(search:String) -> AdRequestBuilder`
- `with(category:String) -> AdRequestBuilder`

### Data Models

#### AdResponse
Contains the response from ad requests with convenience methods for accessing ads by placement.

**Standard Methods:**
- `getAds(for:Int) -> [Ad]?` - Get ads for specific placement
- `allAds: [Ad]` - Get all ads from all placements
- `hasAds(for:Int) -> Bool` - Check if placement has ads
- `adCount(for:Int) -> Int` - Get ad count for placement

**Product Ad Methods:**
- `allProductAds: [Ad]` - Get all product ads
- `allDisplayAds: [Ad]` - Get all display ads
- `getProductAds(for:Int) -> [Ad]?` - Get product ads for placement
- `getDisplayAds(for:Int) -> [Ad]?` - Get display ads for placement
- `hasProductAds(for:Int) -> Bool` - Check if placement has product ads
- `hasDisplayAds(for:Int) -> Bool` - Check if placement has display ads
- `productAdCount(for:Int) -> Int` - Get product ad count for placement
- `displayAdCount(for:Int) -> Int` - Get display ad count for placement
- `allSKUs: [String]` - Get all unique SKUs from product ads
- `getSKUs(for:Int) -> [String]` - Get SKUs for specific placement

#### Ad
Represents an individual ad with type detection capabilities.

**Ad Type Detection:**
- `isProductAd: Bool` - True if ad contains product_id (SKU)
- `isDisplayAd: Bool` - True if ad contains img_url, html, or redirect
- `sku: String?` - Returns product_id if this is a product ad
- `displayImageUrl: String?` - Returns img_url if this is a display ad
- `clickUrl: String?` - Returns redirect URL if available

#### PlacementRequest
Represents a request for a specific ad placement with optional filtering and limiting.

#### ProductRequest
Simplified model for product context in ad requests.

#### Sale
Model for reporting sales transactions with advertiser, quantity, price, and product information.

#### Customer
Model for providing customer context to improve ad targeting.

### SwiftUI Components

#### SponsoredDisplayView
Automatic display component for sponsored display ads.
- `init(placementId:sessionId:isClickable:onStateChange:)`
- `init(placementId:sessionId:isClickable:state:)`

#### SponsoredProductView
Generic product display component for custom product presentations.
- `init(imageUrl:title:price:rating:onTap:isClickable:)`

#### SponsoredProductAdView
Product ad component with automatic SKU handling and catalog integration.
- `init(ad:sessionId:productImageUrl:productTitle:productPrice:productRating:isClickable:onProductQuery:)`
- `init(ad:sessionId:isClickable:onProductQuery:)`

#### AdImageView
Low-level image display component for sponsored display ads.
- `init(ad:sessionId:isClickable:)`

#### ConditionalDisplayView
Conditional rendering component that only shows when ads are available.
- `init(placementId:sessionId:isClickable:fallback:)`
- `init(placementId:sessionId:isClickable:)`

## Requirements

- iOS 15.0+
- Swift 5.5+

## Support

For technical support and documentation:
- GitHub Issues: [Report Issues](https://github.com/gowittechnology/gowit-swift/issues)
- Documentation: [Official Documentation](https://docs.gowit.com)
- Contact: support@gowit.com

## License

This SDK is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
