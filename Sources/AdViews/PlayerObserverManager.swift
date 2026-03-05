import Foundation
import AVFoundation
import Gowit

// MARK: - Player Observer Manager

/// Manages AVPlayer observers for status, time updates, and playback events
@MainActor
final class PlayerObserverManager {

    // MARK: - Properties

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?

    // MARK: - Callbacks

    var onStatusChange: ((AVPlayerItem.Status) -> Void)?
    var onTimeUpdate: ((CMTime, CMTime?) -> Void)?
    var onPlaybackEnd: (() -> Void)?
    var onPlaybackFailed: ((Error?) -> Void)?

    // MARK: - Setup Observers

    /// Setup all observers for a player
    func setupObservers(for player: AVPlayer) {
        guard let playerItem = player.currentItem else { return }

        // Observe player item status
        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                self?.onStatusChange?(item.status)
            }
        }

        // Observe time for tracking
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let duration = player.currentItem?.duration
                self.onTimeUpdate?(time, duration)
            }
        }

        // Observe playback end
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onPlaybackEnd?()
            }
        }

        // Observe playback failures
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.onPlaybackFailed?(error)
            }
        }
    }

    // MARK: - Cleanup

    /// Remove all observers (must be called explicitly on @MainActor)
    func cleanup(from player: AVPlayer?) {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }

        if let observer = failureObserver {
            NotificationCenter.default.removeObserver(observer)
            failureObserver = nil
        }

        statusObserver?.invalidate()
        statusObserver = nil
    }
}
