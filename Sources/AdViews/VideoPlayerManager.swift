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
    var onAudioTrackDetected: ((Bool) -> Void)?

    // MARK: - Initialization

    init(configuration: VideoAdConfiguration, logger: @escaping (String) -> Void) {
        self.configuration = configuration
        self.logger = logger
    }

    // MARK: - Player Setup

    /// Prepare and create a player from a video URL, using the disk cache when enabled.
    func setupPlayer(with url: URL, isMuted: Bool) {
        logger("Preparing video from URL...")

        Task {
            do {
                let localURL = try await resolveLocalURL(for: url)

                let player = createPlayer(with: localURL, isMuted: isMuted)

                // Use the async API (iOS 15+) to avoid blocking the main thread while
                // AVAsset loads track metadata for the first time.
                let audioTracks = try? await player.currentItem?.asset.loadTracks(withMediaType: .audio)
                let hasAudio = audioTracks?.isEmpty == false
                logger("Audio track detection: hasAudio=\(hasAudio)")
                onAudioTrackDetected?(hasAudio)

                onPlayerReady?(player)

            } catch {
                logger("Failed to prepare video: \(error.localizedDescription)")
                onError?(.networkError(error.localizedDescription))
            }
        }
    }

    // MARK: - Local URL Resolution

    /// Returns a local file URL ready for AVPlayer, hitting the disk cache first.
    ///
    /// **Cache enabled (default):**
    /// - HIT  → return cached file immediately, no network activity.
    /// - MISS → resolve redirects, download, store in cache, return cached URL.
    ///
    /// **Cache disabled:**
    /// - Always resolves redirects and downloads to a temporary file.
    private func resolveLocalURL(for url: URL) async throws -> URL {
        if configuration.videoCacheEnabled {
            if let cached = await VideoAdCache.shared.cachedFileURL(for: url) {
                logger("Cache HIT — serving from disk, no download needed")
                return cached
            }
            logger("Cache MISS — downloading...")
        }

        // The CDN returns fmp4 without Content-Length, causing CoreMediaErrorDomain -12939.
        // Workaround: download to a local file first, then play from disk.
        let finalURL = try await resolveRedirects(for: url)
        let downloadedURL = try await downloadVideo(from: finalURL)

        if configuration.videoCacheEnabled {
            let cachedURL = await VideoAdCache.shared.store(localFile: downloadedURL, for: url)
            logger("Video stored in disk cache")
            return cachedURL
        }

        // Cache disabled: move to a stable temp path so the URLSession temp isn't recycled
        return try moveToStableTemp(downloadedURL)
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

    /// Download a video and return the URLSession-managed temporary file URL.
    private func downloadVideo(from url: URL) async throws -> URL {
        logger("Downloading video...")
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VASTError.networkError("Failed to download video")
        }

        return tempURL
    }

    /// Move a URLSession temporary file to a stable path so AVPlayer can use it
    /// even after the URLSession session cleans up its own temp files.
    private func moveToStableTemp(_ url: URL) throws -> URL {
        let fileName = "vast_video_\(UUID().uuidString).mp4"
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: url, to: destinationURL)
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
