import Foundation
import Gowit

// MARK: - VAST Validator

/// Helper to validate VAST responses and extract necessary components
struct VASTValidator {

    private let logger: (String) -> Void

    init(logger: @escaping (String) -> Void) {
        self.logger = logger
    }

    /// Result of VAST validation
    struct ValidationResult {
        let ad: VASTAd
        let linear: VASTLinear
        let videoURL: URL
    }

    /// Validate VAST response and extract necessary components
    func validate(_ response: VASTResponse) throws -> ValidationResult {
        logger("VAST parsed - Ads count: \(response.ads.count)")

        guard let ad = response.firstAd else {
            logger("Error: No ad found in response")
            throw VASTError.noAdsFound
        }
        logger("Ad ID: \(ad.id)")

        guard let inLine = ad.inLine else {
            logger("Error: No InLine in ad")
            throw VASTError.noAdsFound
        }
        logger("InLine - Extensions: \(inLine.extensions.count), Creatives: \(inLine.creatives.count)")

        guard let creative = inLine.creatives.first else {
            logger("Error: No creatives found")
            throw VASTError.noAdsFound
        }
        logger("Creative ID: \(creative.id ?? "nil")")

        guard let linear = creative.linear else {
            logger("Error: No linear in creative")
            throw VASTError.noAdsFound
        }
        logger("Linear - Duration: \(linear.duration ?? 0)s, MediaFiles: \(linear.mediaFiles.count)")

        guard let mediaFile = linear.bestMediaFile() else {
            logger("Error: No suitable media file found")
            throw VASTError.invalidMediaFile
        }
        logger("MediaFile - URL: \(mediaFile.url), Type: \(mediaFile.type ?? "nil"), Size: \(mediaFile.width ?? 0)x\(mediaFile.height ?? 0)")

        guard let videoURL = URL(string: mediaFile.url) else {
            logger("Error: Invalid video URL: \(mediaFile.url)")
            throw VASTError.invalidURL(mediaFile.url)
        }
        logger("Video URL valid: \(videoURL)")

        return ValidationResult(ad: ad, linear: linear, videoURL: videoURL)
    }
}
