import SwiftUI
import Gowit

// MARK: - Sponsored Product View

/// A SwiftUI component for displaying sponsored product ads.
/// This component is designed for product ads that contain a product_id (SKU).
/// Customers can use the SKU to query their catalog and get product details.
public struct SponsoredProductView: View {
    let imageUrl: String?
    let title: String
    let price: String?
    let rating: Double?
    let onTap: (() -> Void)?
    let isClickable: Bool

    public init(
        imageUrl: String?,
        title: String,
        price: String? = nil,
        rating: Double? = nil,
        onTap: (() -> Void)? = nil,
        isClickable: Bool = true
    ) {
        self.imageUrl = imageUrl
        self.title = title
        self.price = price
        self.rating = rating
        self.onTap = onTap
        self.isClickable = isClickable
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            Group {
                if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1, contentMode: .fit)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }

            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Rating
                if let rating = rating, rating > 0 {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Text("(\(rating, specifier: "%.1f"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Price
                if let price = price {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .onTapGesture {
            if isClickable {
                onTap?()
            }
        }
    }
}

public struct SponsoredProductDetails {
    public let imageUrl: String?
    public let title: String
    public let price: String?
    public let rating: Double?

    public init(imageUrl: String?, title: String, price: String?, rating: Double?) {
        self.imageUrl = imageUrl
        self.title = title
        self.price = price
        self.rating = rating
    }
}

/// A convenient wrapper for displaying sponsored product ads from Ad objects.
/// This component automatically extracts product information and handles SKU-based queries.
public struct SponsoredProductAdView: View {
    let ad: Ad
    let sessionId: String
    let isClickable: Bool
    let productDetails: SponsoredProductDetails?
    let onProductQuery: ((String) -> Void)?
    @State private var hasReportedImpression = false

    /// Initialize with product details provided externally (recommended approach).
    /// The customer should query their catalog using the SKU and provide the details.
    public init(
        ad: Ad,
        sessionId: String,
        productImageUrl: String?,
        productTitle: String,
        productPrice: String? = nil,
        productRating: Double? = nil,
        isClickable: Bool = true,
        onProductQuery: ((String) -> Void)? = nil
    ) {
        self.ad = ad
        self.sessionId = sessionId
        self.isClickable = isClickable
        self.productDetails = SponsoredProductDetails(
                    imageUrl: productImageUrl,
                    title: productTitle,
                    price: productPrice,
                    rating: productRating
                )
        self.onProductQuery = onProductQuery
    }

    public var body: some View {
        Group {
            if ad.isProductAd {
                let imageUrl = productDetails?.imageUrl
                let title = productDetails?.title ?? "Product"
                let price = productDetails?.price
                let rating = productDetails?.rating

                SponsoredProductView(
                    imageUrl: imageUrl,
                    title: title,
                    price: price,
                    rating: rating,
                    onTap: {
                        handleProductTap()
                    },
                    isClickable: isClickable
                )
                .onAppear {
                    if !hasReportedImpression {
                        reportImpression()
                    }
                }
            } else {
                // Not a product ad - show fallback or nothing
                Text("Not a product ad")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }

    private func handleProductTap() {
        // Report click event
        reportClick()

        // Trigger product query with SKU if callback is provided
        if let sku = ad.sku {
            onProductQuery?(sku)
        }

        // Handle redirect if available
        if let redirectUrl = ad.clickUrl, let url = URL(string: redirectUrl) {
            UIApplication.shared.open(url)
        }
    }

    private func reportImpression() {
        guard let adId = ad.adId else { return }

        Task {
            do {
                try await Gowit.shared.sendImpressionEvent(adId: adId, sessionId: sessionId)
                await MainActor.run {
                    hasReportedImpression = true
                }
            } catch {
                print("Failed to send impression event: \(error)")
            }
        }
    }

    private func reportClick() {
        guard let adId = ad.adId else { return }

        Task {
            do {
                try await Gowit.shared.sendClickEvent(adId: adId, sessionId: sessionId)
            } catch {
                print("Failed to send click event: \(error)")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Basic SponsoredProductView
        SponsoredProductView(
            imageUrl: "https://example.com/product.jpg",
            title: "Premium Wireless Headphones",
            price: "$199.99",
            rating: 4.5
        )
        .frame(width: 200)

        // SponsoredProductView without rating
        SponsoredProductView(
            imageUrl: "https://example.com/product2.jpg",
            title: "Gaming Keyboard Pro",
            price: "$89.99"
        )
        .frame(width: 200)

        // SponsoredProductView without image
        SponsoredProductView(
            imageUrl: nil,
            title: "Bluetooth Speaker",
            price: "$59.99",
            rating: 4.2
        )
        .frame(width: 200)
    }
}
