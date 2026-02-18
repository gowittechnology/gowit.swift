import SwiftUI
import AVFoundation
import AVKit
import Gowit

public struct VideoAdView: View {
    private let vastURL: URL
    private let configuration: VideoAdConfiguration
    private let onAdLoaded: ((VASTAd) -> Void)?
    private let onAdStarted: (() -> Void)?
    private let onAdCompleted: (() -> Void)?
    private let onAdClicked: ((URL) -> Void)?
    private let onError: ((VASTError) -> Void)?
    private let onStateChanged: ((VideoAdState) -> Void)?
    @StateObject private var viewModel: VideoAdViewModel

    public init(
        vastURL: URL,
        configuration: VideoAdConfiguration = .default,
        onAdLoaded: ((VASTAd) -> Void)? = nil,
        onAdStarted: (() -> Void)? = nil,
        onAdCompleted: (() -> Void)? = nil,
        onAdClicked: ((URL) -> Void)? = nil,
        onError: ((VASTError) -> Void)? = nil,
        onStateChanged: ((VideoAdState) -> Void)? = nil
    ) {
        self.vastURL = vastURL
        self.configuration = configuration
        self.onAdLoaded = onAdLoaded
        self.onAdStarted = onAdStarted
        self.onAdCompleted = onAdCompleted
        self.onAdClicked = onAdClicked
        self.onError = onError
        self.onStateChanged = onStateChanged

        _viewModel = StateObject(wrappedValue: VideoAdViewModel(
            vastURL: vastURL,
            configuration: configuration
        ))
    }
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content based on state
                contentView
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Overlays
                if viewModel.state == .playing || viewModel.state == .paused || viewModel.state == .ready {
                    overlayView
                }
            }
            .onAppear {
                setupCallbacks()
                viewModel.viewDidAppear(geometry: geometry)
            }
            .onDisappear {
                viewModel.viewDidDisappear()
            }
            .onChange(of: geometry.frame(in: .global)) { newFrame in
                viewModel.updateVisibility(frame: newFrame, screenHeight: getScreenHeight())
            }
            .onTapGesture {
                handleTap()
            }
        }
        // Note: Aspect ratio is not enforced - parent container controls sizing
    }
    private func getScreenHeight() -> CGFloat {
        return UIScreen.main.bounds.height
    }
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView

        case .ready, .playing, .paused, .completed:
            videoPlayerView

        case .error(let message):
            if configuration.debugLogging {
                errorView(message: message)
            } else {
                // Fail silently - show nothing
                Color.clear
            }

        case .noAd:
            // No ad available - show nothing
            Color.clear

        case .hidden:
            // Hidden state
            Color.clear
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        switch configuration.loadingBehavior {
        case .hidden:
            Color.clear

        case .systemImage(let name):
            ZStack {
                Color.black.opacity(0.1)
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
            }

        case .text(let text):
            ZStack {
                Color.black.opacity(0.1)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

        case .placeholder(let color):
            color

        case .shimmer:
            ShimmerView()
        }
    }

    private var videoPlayerView: some View {
        VideoPlayerRepresentable(
            player: viewModel.player,
            videoGravity: .resizeAspectFill
        )
    }

    private func errorView(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.1)
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    private var overlayView: some View {
        VStack {
            HStack(spacing: 8) {
                if configuration.showAdLabel {
                    adLabelBadge
                }
                
                if viewModel.shouldShowMuteButton {
                    muteButton
                        .opacity(viewModel.effectiveMuteButtonOpacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isMuteButtonVisible)
                }
                
                Spacer()
            }
            Spacer()
        }
        .padding(.leading, 14)
        .padding(.top, 14)
    }

    private var adLabelBadge: some View {
        Text(configuration.adLabelText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.6))
            .clipShape(Rectangle())
    }

    private var muteButton: some View {
        Button(action: {
            viewModel.toggleMute()
        }, label: {
            Image(viewModel.isMuted ? "unmute-icon" : "mute-icon", bundle: .module)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
        })
        .buttonStyle(PlainButtonStyle())
    }
    private func setupCallbacks() {
        viewModel.onAdLoaded = onAdLoaded
        viewModel.onAdStarted = onAdStarted
        viewModel.onAdCompleted = onAdCompleted
        viewModel.onAdClicked = onAdClicked
        viewModel.onError = onError
        viewModel.onStateChanged = onStateChanged
    }

    private func handleTap() {
        viewModel.handleTap()
    }
}
@MainActor
final class VideoAdViewModel: ObservableObject {
    @Published var state: VideoAdState = .idle
    @Published var isMuted: Bool = true
    @Published var player: AVPlayer?
    @Published var hasAudioTrack: Bool = true
    @Published var isMuteButtonVisible: Bool = false
    private var muteButtonHideTimer: Timer?
    var onAdLoaded: ((VASTAd) -> Void)?
    var onAdStarted: (() -> Void)?
    var onAdCompleted: (() -> Void)?
    var onAdClicked: ((URL) -> Void)?
    var onError: ((VASTError) -> Void)?
    var onStateChanged: ((VideoAdState) -> Void)?
    private let vastURL: URL
    private let configuration: VideoAdConfiguration
    private let parser = VASTParser()
    private let eventTracker = VASTEventTracker.shared

    // Helpers
    private lazy var validator = VASTValidator(logger: { message in GowitLogger.debug(message) })

    // Helpers
    private lazy var playerManager = VideoPlayerManager(
        configuration: configuration,
        logger: { message in GowitLogger.debug(message) }
    )

    private lazy var playbackController = VideoPlaybackController(
        configuration: configuration,
        logger: { message in GowitLogger.debug(message) }
    )

    private var currentAd: VASTAd?
    private var currentLinear: VASTLinear?
    private var isVisible = false
    private lazy var observerManager = PlayerObserverManager()
    init(vastURL: URL, configuration: VideoAdConfiguration) {
        self.vastURL = vastURL
        self.configuration = configuration
        self.isMuted = configuration.isMutedByDefault

        eventTracker.debugLoggingEnabled = configuration.debugLogging
        GowitLogger.isDebugEnabled = configuration.debugLogging
        setupPlaybackControllerCallbacks()
        setupObserverCallbacks()
    }
    func viewDidAppear(geometry: GeometryProxy) {
        loadAd()
    }

    func viewDidDisappear() {
        playbackController.pause(player: player, currentState: state)
        isVisible = false
        cancelMuteButtonTimer()
    }
    func updateVisibility(frame: CGRect, screenHeight: CGFloat) {
        let visibleHeight = min(frame.maxY, screenHeight) - max(frame.minY, 0)
        let visibleRatio = max(0, visibleHeight / frame.height)

        let shouldBeVisible = visibleRatio >= configuration.visibilityThreshold

        if shouldBeVisible != isVisible {
            isVisible = shouldBeVisible

            if isVisible {
                if configuration.autoPlay && (state == .ready || state == .paused) {
                    play()
                }
            } else {
                if state == .playing {
                    playbackController.pause(player: player, currentState: state)
                }
            }
        }

        // Show mute button on any scroll while video is visible
        if isVisible {
            showMuteButtonBriefly()
        }
    }
    func toggleMute() {
        isMuted = playbackController.toggleMute(player: player, isMuted: isMuted)
        showMuteButtonBriefly()
    }

    /// Whether the mute button should be visible based on configuration and audio track presence
    var shouldShowMuteButton: Bool {
        switch configuration.muteButtonBehavior {
        case .alwaysShow:
            return true
        case .alwaysHide:
            return false
        case .automatic:
            return hasAudioTrack
        }
    }

    /// Opacity for the mute button — always 1 for alwaysShow, timer-driven for automatic
    var effectiveMuteButtonOpacity: Double {
        switch configuration.muteButtonBehavior {
        case .alwaysShow:
            return 1
        case .automatic:
            return isMuteButtonVisible ? 1 : 0
        case .alwaysHide:
            return 0
        }
    }

    /// Briefly show the mute button, then auto-hide after 3 seconds
    func showMuteButtonBriefly() {
        guard shouldShowMuteButton else { return }
        isMuteButtonVisible = true
        scheduleMuteButtonHide()
    }

    private func scheduleMuteButtonHide() {
        cancelMuteButtonTimer()
        muteButtonHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isMuteButtonVisible = false
            }
        }
    }

    private func cancelMuteButtonTimer() {
        muteButtonHideTimer?.invalidate()
        muteButtonHideTimer = nil
    }

    func handleTap() {
        // Show mute button briefly on any tap (standard video controls pattern)
        showMuteButtonBriefly()

        if let url = playbackController.handleClick() {
            onAdClicked?(url)
        }
    }
    private func loadAd() {
        guard state == .idle else { return }

        updateState(.loading)

        Task { [weak self] in
            guard let self = self else { return }

            do {
                GowitLogger.debug("Fetching VAST from: \(self.vastURL)")
                let response = try await self.parser.fetchAndParse(
                    url: self.vastURL,
                    maxWrapperDepth: self.configuration.maxWrapperDepth,
                    timeout: self.configuration.requestTimeout
                )

                // Validate and extract components
                let result = try self.validator.validate(response)

                await MainActor.run {
                    self.currentAd = result.ad
                    self.currentLinear = result.linear
                    self.playbackController.currentAd = result.ad
                    self.playbackController.currentLinear = result.linear

                    // Fire impressions
                    if let inLine = result.ad.inLine {
                        self.eventTracker.fireImpressions(inLine.impressions)
                    }

                    // Setup player
                    GowitLogger.debug("Setting up player...")
                    self.setupPlayer(with: result.videoURL)

                    self.onAdLoaded?(result.ad)
                    self.updateState(.ready)
                    GowitLogger.debug("State updated to .ready, isVisible: \(self.isVisible)")
                }

            } catch let error as VASTError {
                GowitLogger.debug("VAST Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.handleError(error)
                }
            } catch {
                GowitLogger.debug("Unknown Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.handleError(.unknown(error.localizedDescription))
                }
            }
        }
    }
    private func setupPlayer(with url: URL) {
        playerManager.onAudioTrackDetected = { [weak self] hasAudio in
            self?.hasAudioTrack = hasAudio
            GowitLogger.debug("Audio track detected: \(hasAudio)")
        }

        playerManager.onPlayerReady = { [weak self] (player: AVPlayer) in
            guard let self = self else { return }
            self.observerManager.setupObservers(for: player)
            self.player = player

            GowitLogger.debug("Player created, checking auto-play conditions...")
            if self.isVisible && self.configuration.autoPlay {
                GowitLogger.debug("Conditions met, requesting play")
                self.play()
            }
        }

        playerManager.onError = { [weak self] error in
            self?.handleError(error)
        }

        playerManager.setupPlayer(with: url, isMuted: isMuted)
    }
    private func setupObserverCallbacks() {
        observerManager.onStatusChange = { [weak self] status in
            guard let self = self, let playerItem = self.player?.currentItem else { return }
            self.handlePlayerItemStatus(status, item: playerItem)
        }

        observerManager.onTimeUpdate = { [weak self] time, duration in
            self?.playbackController.handleTimeUpdate(time: time, playerDuration: duration)
        }

        observerManager.onPlaybackEnd = { [weak self] in
            self?.playbackController.handlePlaybackEnd()
        }

        observerManager.onPlaybackFailed = { [weak self] error in
            GowitLogger.error("Playback failed to end", error: error)
        }
    }

    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status, item: AVPlayerItem) {
        switch status {
        case .unknown:
            GowitLogger.debug("Player item status: unknown (buffering...)")

        case .readyToPlay:
            GowitLogger.debug("Player item status: readyToPlay")
            if playbackController.isPendingPlay {
                playbackController.isPendingPlay = false
                GowitLogger.debug("Starting deferred playback")
                if let player = player {
                    playbackController.performPlay(player: player)
                }
            }

        case .failed:
            if let error = item.error {
                GowitLogger.error("Player item failed", error: error)
            } else {
                GowitLogger.error("Player item failed with unknown error")
            }
            handleError(.invalidMediaFile)

        @unknown default:
            GowitLogger.debug("Unknown player item status")
        }
    }

    private func play() {
        playbackController.play(player: player, currentState: state)
    }
    private func setupPlaybackControllerCallbacks() {
        playbackController.onStateChange = { [weak self] newState in
            self?.updateState(newState)
        }

        playbackController.onAdStarted = { [weak self] in
            self?.onAdStarted?()
        }

        playbackController.onAdCompleted = { [weak self] in
            self?.onAdCompleted?()
        }

        playbackController.onError = { [weak self] error in
            self?.handleError(error)
        }

        playbackController.onReplay = { [weak self] in
            self?.replayAd()
        }

        playbackController.onRefresh = { [weak self] in
            self?.refreshAd()
        }
    }

    private func replayAd() {
        player?.seek(to: .zero)
        playbackController.prepareForReplay()
        updateState(.ready)

        if isVisible && configuration.autoPlay {
            play()
        }
    }

    private func refreshAd() {
        cleanup()

        currentAd = nil
        currentLinear = nil
        playbackController.resetPlaybackState()

        updateState(.idle)
        loadAd()
    }
    private func handleError(_ error: VASTError) {
        GowitLogger.debug("Error: \(error.localizedDescription)")

        // Fire error tracking
        if let inLine = currentAd?.inLine {
            eventTracker.fireErrors(inLine.errors, errorCode: error.vastErrorCode)
        }

        onError?(error)

        if case .noAdsFound = error {
            updateState(.noAd)
        } else {
            updateState(.error(error.localizedDescription))
        }
    }
    private func updateState(_ newState: VideoAdState) {
        state = newState
        onStateChanged?(newState)
    }
    private func cleanup() {
        observerManager.cleanup(from: player)
        player?.pause()
        player = nil
    }
}
