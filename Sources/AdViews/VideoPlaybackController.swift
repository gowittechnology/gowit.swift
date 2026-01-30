import Foundation
import AVFoundation
import Gowit

// MARK: - Video Playback Controller

/// Manages video playback state, controls, and event tracking
@MainActor
final class VideoPlaybackController {

    // MARK: - Properties

    private let configuration: VideoAdConfiguration
    private let eventTracker = VASTEventTracker.shared
    private let logger: (String) -> Void

    private var hasStarted = false
    private var hasCompleted = false
    private var firedQuartiles: Set<VASTTrackingEventType> = []
    private var firedProgress: Set<TimeInterval> = []
    private var pendingPlay = false

    // MARK: - References

    var currentAd: VASTAd?
    var currentLinear: VASTLinear?

    // MARK: - Callbacks

    var onStateChange: ((VideoAdState) -> Void)?
    var onAdStarted: (() -> Void)?
    var onAdCompleted: (() -> Void)?
    var onError: ((VASTError) -> Void)?
    var onReplay: (() -> Void)?
    var onRefresh: (() -> Void)?

    // MARK: - Initialization

    init(configuration: VideoAdConfiguration, logger: @escaping (String) -> Void) {
        self.configuration = configuration
        self.logger = logger

        eventTracker.debugLoggingEnabled = configuration.debugLogging
    }

    // MARK: - Playback State

    var isPendingPlay: Bool {
        get { pendingPlay }
        set { pendingPlay = newValue }
    }

    func resetPlaybackState() {
        hasStarted = false
        hasCompleted = false
        firedQuartiles = []
        firedProgress = []
        pendingPlay = false
    }

    // MARK: - Playback Control

    /// Request playback start
    func play(player: AVPlayer?, currentState: VideoAdState) {
        guard let player = player else {
            logger("Warning: play() called but player is nil")
            return
        }

        guard let playerItem = player.currentItem else {
            logger("Warning: play() called but player has no currentItem")
            return
        }

        // Check if player item is ready for playback
        switch playerItem.status {
        case .readyToPlay:
            logger("Player item ready, starting playback immediately")
            performPlay(player: player)

        case .unknown:
            logger("Player item not ready yet, deferring playback...")
            pendingPlay = true
            onStateChange?(.loading)

        case .failed:
            logger("Player item failed: \(playerItem.error?.localizedDescription ?? "unknown error")")
            onError?(.invalidMediaFile)

        @unknown default:
            logger("Unknown player item status, attempting playback anyway")
            performPlay(player: player)
        }
    }

    /// Actually perform playback (called when player item is ready)
    func performPlay(player: AVPlayer) {
        logger("performPlay() - calling player.play()")
        player.play()
        onStateChange?(.playing)

        if !hasStarted {
            hasStarted = true

            // Fire start tracking
            if let trackingEvents = currentLinear?.trackingEvents {
                eventTracker.fireStart(from: trackingEvents)
            }

            // Fire viewable impression
            if let inLine = currentAd?.inLine {
                eventTracker.fireViewable(inLine.viewableImpression)
            }

            onAdStarted?()
        } else {
            // Resume tracking
            if let trackingEvents = currentLinear?.trackingEvents {
                eventTracker.fireResume(from: trackingEvents)
            }
        }
    }

    /// Pause playback
    func pause(player: AVPlayer?, currentState: VideoAdState) {
        guard let player = player, currentState == .playing else { return }

        player.pause()
        onStateChange?(.paused)

        // Fire pause tracking
        if let trackingEvents = currentLinear?.trackingEvents {
            eventTracker.firePause(from: trackingEvents)
        }
    }

    // MARK: - Time Updates

    /// Handle periodic time updates for tracking events
    func handleTimeUpdate(time: CMTime, playerDuration: CMTime?) {
        guard let duration = playerDuration,
              duration.isNumeric,
              let trackingEvents = currentLinear?.trackingEvents else {
            return
        }

        let currentTime = time.seconds
        let totalDuration = duration.seconds

        // Check quartile events
        eventTracker.checkQuartileEvents(
            currentTime: currentTime,
            duration: totalDuration,
            trackingEvents: trackingEvents,
            firedQuartiles: &firedQuartiles
        )

        // Check progress events
        eventTracker.checkProgressEvents(
            currentTime: currentTime,
            duration: totalDuration,
            trackingEvents: trackingEvents,
            firedProgress: &firedProgress
        )
    }

    // MARK: - Playback End

    /// Handle playback completion
    func handlePlaybackEnd() {
        guard !hasCompleted else { return }
        hasCompleted = true

        // Fire complete tracking
        if let trackingEvents = currentLinear?.trackingEvents {
            eventTracker.fireComplete(from: trackingEvents)
        }

        onAdCompleted?()
        onStateChange?(.completed)

        // Handle post-ad behavior
        handlePostAdBehavior()
    }

    private func handlePostAdBehavior() {
        switch configuration.postAdBehavior {
        case .replay:
            onReplay?()

        case .refreshAd:
            onRefresh?()

        case .showLastFrame:
            // Do nothing, keep showing last frame
            break

        case .hide:
            onStateChange?(.hidden)
        }
    }

    /// Reset for replay
    func prepareForReplay() {
        hasCompleted = false
        firedQuartiles = []
        firedProgress = []
    }

    // MARK: - Mute Control

    func toggleMute(player: AVPlayer?, isMuted: Bool) -> Bool {
        let newMutedState = !isMuted
        player?.isMuted = newMutedState

        if let trackingEvents = currentLinear?.trackingEvents {
            if newMutedState {
                eventTracker.fireMute(from: trackingEvents)
            } else {
                eventTracker.fireUnmute(from: trackingEvents)
            }
        }

        return newMutedState
    }

    // MARK: - Click Handling

    func handleClick() -> URL? {
        guard let clickThrough = currentLinear?.videoClicks?.clickThrough,
              let url = URL(string: clickThrough) else {
            return nil
        }

        // Fire click tracking
        eventTracker.fireClickTracking(currentLinear?.videoClicks)

        return url
    }
}
