# Changelog

All notable changes to the Gowit Swift SDK are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-11-03

### Added
- `AdContext`: one value for the request context — `customer`, `language`, `locationId`,
  `regionId`, `search`, `category`, `categoryId`, `products`, `filters`, `pageNumber`, `sessionId`.
- App-wide default context: `Gowit.shared.defaultContext`. Applied to every ad request and every
  `SponsoredDisplayView`. More specific values win; `customer` is merged field by field
  (`Customer.merge(_:over:)`); arrays are replaced.
- `Gowit.shared.getAds(placement:context:sessionId:)` for single-placement requests with context.
- `SponsoredDisplayView(placement:context:sessionId:isClickable:onAdClick:onStateChange:)` and
  `SponsoredDisplayView(placement:context:sessionId:isClickable:onAdClick:state:)`.
  The view now sends the full request context.
- Click interception: `onAdClick: (Ad, URL?) -> Bool` on `SponsoredDisplayView` and `AdImageView`.
  Return `true` to handle navigation in the app; `false` keeps the default behavior
  (`UIApplication.shared.open`). The click event is recorded in both cases.
- `AdRequestBuilder.with(context:)`.
- `Customer`: `id`, `environmentType`, `ip`, `segments`, `userAgent`.
- `Product` and `ProductRequest`: `categories` and `categoryIdStructures` for products that belong
  to several categories.
- `Customer`, `Product` and `AdContext` conform to `Equatable`.
- Tests for context merging and the request body sent to `/server/v2/sdk/ads`.

### Changed
- `getAds(placements:pageNumber:sessionId:)` and `getAds(_:)` apply the default context.
- `SponsoredDisplayView(placementId:sessionId:...)` initializers keep working and now also apply
  the default context.

### Fixed
- `Product` is encoded as `id` instead of `product_id`. Product context sent from iOS was
  previously ignored by the server.
- `language` set on `AdRequestBuilder` is now sent with the request (it was dropped in `getAds(_:)`).
- The test target links again: it now depends on `AdViews`, which `VASTParserTests` uses.

## [1.0.4] - 2026-07-01
### Changed
- SDK impression and click events send `no_redirect=1`.

## [1.0.3] - 2026-07-01
### Fixed
- Corrected the SDK ad endpoint.

## Between 1.0.2 and 1.0.3
- Corrected `configure` usage (SUP-1603).
- Proportionally larger mute button hit area (SUP-1589).
- Disk cache for video ad files.
- Configurable mute button corner, size and padding.
- `ad.trigger.click` to record a click when an ad extension is tapped.
- `VideoAdView` aspect ratio handling.

## [1.0.2] - 2026-01-30
### Added
- VAST video ad support and HTML display ad support.

## [1.0.0] - 2025-09-08
### Added
- Initial release: configuration, ad requests with placements and filters, SwiftUI
  `SponsoredDisplayView` and `SponsoredProductView`, impression, click and sale events.

[1.1.0]: https://github.com/gowittechnology/gowit-swift/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/gowittechnology/gowit-swift/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/gowittechnology/gowit-swift/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/gowittechnology/gowit-swift/releases/tag/v1.0.2
