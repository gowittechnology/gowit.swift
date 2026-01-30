import Foundation
import AVFoundation
import Gowit

// MARK: - Video Player Manager

/// Manages AVPlayer creation, configuration, and URL resolution for video ads
@MainActor
final class VideoPlayerManager {

    // MARK: - Properties

    private let configuration: VideoAdConfiguration
    private let logger: (String) -> Void

    // MARK: - Callbacks

    var onPlayerReady: ((AVPlayer) -> Void)?
    var onError: ((VASTError) -> Void)?
    var onStatusChange: ((AVPlayerItem.Status) -> Void)?

    // MARK: - Initialization

    init(configuration: VideoAdConfiguration, logger: @escaping (String) -> Void) {
        self.configuration = configuration
        self.logger = logger
    }

    // MARK: - Player Setup

    /// Prepare and create player from video URL
    func setupPlayer(with url: URL, isMuted: Bool) {
        logger("Preparing video from URL...")

        // The CDN returns fmp4 without Content-Length header, causing CoreMediaErrorDomain -12939
        // Workaround: Download to temporary file first, then play from local file
        Task {
            do {
                // First resolve redirects
                let finalURL = try await resolveRedirects(for: url)

                // Download to temp file
                let localURL = try await downloadVideoToTemp(from: finalURL)

                // Create player
                let player = createPlayer(with: localURL, isMuted: isMuted)
                onPlayerReady?(player)

            } catch {
                logger("Failed to prepare video: \(error.localizedDescription)")
                onError?(.networkError(error.localizedDescription))
            }
        }
    }

    // MARK: - URL Resolution

    /// Resolve any redirects and return the final URL
    private func resolveRedirects(for url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        if let finalURL = response.url {
            logger("Resolved URL: \(finalURL.absoluteString.prefix(100))...")
            return finalURL
        }

        return url
    }

    /// Download video to temporary file
    private func downloadVideoToTemp(from url: URL) async throws -> URL {
        logger("Downloading video to temporary file...")

        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VASTError.networkError("Failed to download video")
        }

        // Move to a more predictable temp location
        let fileName = "vast_video_\(UUID().uuidString).mp4"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Remove existing file if any
        try? FileManager.default.removeItem(at: destinationURL)

        // Move downloaded file
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        logger("Video downloaded to: \(destinationURL.lastPathComponent)")
        return destinationURL
    }

    // MARK: - Player Creation

    /// Create AVPlayer with the resolved URL
    private func createPlayer(with url: URL, isMuted: Bool) -> AVPlayer {
        logger("Creating AVPlayer with local file: \(url.lastPathComponent)")

        // Configure asset
        let asset = createAsset(from: url)

        // Create player item
        let playerItem = createPlayerItem(from: asset)

        // Create and configure player
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = isMuted
        player.automaticallyWaitsToMinimizeStalling = true

        return player
    }

    /// Create AVURLAsset with appropriate options
    private func createAsset(from url: URL) -> AVURLAsset {
        return AVURLAsset(url: url, options: [
            // Don't require precise duration - allows streaming without full download
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
    }

    /// Create AVPlayerItem with automatic asset key loading
    private func createPlayerItem(from asset: AVURLAsset) -> AVPlayerItem {
        // Use asset keys that we need - load them asynchronously
        let requiredAssetKeys = ["playable", "hasProtectedContent"]

        // Create player item with automatic asset key loading
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: requiredAssetKeys)

        // Set preferred forward buffer duration (in seconds) for streaming
        playerItem.preferredForwardBufferDuration = 5.0

        return playerItem
    }
}
