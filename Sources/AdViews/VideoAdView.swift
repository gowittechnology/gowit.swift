#if os(iOS)
import SwiftUI
import AVFoundation
import AVKit
import Gowit

// MARK: - Video Ad View

/// A SwiftUI view that displays VAST video ads
/// 
/// Usage:
/// ```swift
/// VideoAdView(
///     vastURL: URL(string: "https://example.com/vast")!,
///     configuration: .default,
///     onAdLoaded: { ad in print("Loaded: \(ad.id)") },
///     onAdCompleted: { print("Completed") }
/// )
/// .frame(height: 250)
/// ```
public struct VideoAdView: View {
    
    // MARK: - Properties
    
    private let vastURL: URL
    private let configuration: VideoAdConfiguration
    
    // Callbacks
    private let onAdLoaded: ((VASTAd) -> Void)?
    private let onAdStarted: (() -> Void)?
    private let onAdCompleted: (() -> Void)?
    private let onAdClicked: ((URL) -> Void)?
    private let onError: ((VASTError) -> Void)?
    private let onStateChanged: ((VideoAdState) -> Void)?
    
    // State
    @StateObject private var viewModel: VideoAdViewModel
    
    // MARK: - Initialization
    
    /// Create a new VideoAdView
    /// - Parameters:
    ///   - vastURL: URL to fetch VAST response from
    ///   - configuration: Configuration for display and behavior
    ///   - onAdLoaded: Called when ad is successfully loaded
    ///   - onAdStarted: Called when video starts playing
    ///   - onAdCompleted: Called when video finishes playing
    ///   - onAdClicked: Called when user taps the video
    ///   - onError: Called when an error occurs
    ///   - onStateChanged: Called when ad state changes
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
    
    // MARK: - Body
    
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
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
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
        .aspectRatio(configuration.aspectRatio, contentMode: .fit)
    }
    
    // MARK: - Helpers
    
    private func getScreenHeight() -> CGFloat {
        return UIScreen.main.bounds.height
    }
    
    // MARK: - Content Views
    
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
    
    // MARK: - Overlay View
    
    private var overlayView: some View {
        ZStack {
            // Ad label
            if configuration.showAdLabel {
                VStack {
                    HStack {
                        adLabelBadge
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            // Mute button
            if configuration.showMuteButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        muteButton
                    }
                }
                .padding(8)
            }
        }
    }
    
    private var adLabelBadge: some View {
        Text(configuration.adLabelText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var muteButton: some View {
        Button(action: {
            viewModel.toggleMute()
        }) {
            Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
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

// MARK: - Video Ad ViewModel

@MainActor
final class VideoAdViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var state: VideoAdState = .idle
    @Published var isMuted: Bool = true
    @Published var player: AVPlayer?
    
    // MARK: - Callbacks
    
    var onAdLoaded: ((VASTAd) -> Void)?
    var onAdStarted: (() -> Void)?
    var onAdCompleted: (() -> Void)?
    var onAdClicked: ((URL) -> Void)?
    var onError: ((VASTError) -> Void)?
    var onStateChanged: ((VideoAdState) -> Void)?
    
    // MARK: - Private Properties
    
    private let vastURL: URL
    private let configuration: VideoAdConfiguration
    private let parser = VASTParser()
    private let eventTracker = VASTEventTracker.shared
    
    private var currentAd: VASTAd?
    private var currentLinear: VASTLinear?
    private var hasStarted = false
    private var hasCompleted = false
    private var isVisible = false
    private var firedQuartiles: Set<VASTTrackingEventType> = []
    private var firedProgress: Set<TimeInterval> = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var pendingPlay = false
    
    // MARK: - Initialization
    
    init(vastURL: URL, configuration: VideoAdConfiguration) {
        self.vastURL = vastURL
        self.configuration = configuration
        self.isMuted = configuration.isMutedByDefault
        
        eventTracker.debugLoggingEnabled = configuration.debugLogging
    }
    
    // MARK: - Lifecycle
    
    func viewDidAppear(geometry: GeometryProxy) {
        loadAd()
    }
    
    func viewDidDisappear() {
        pause()
        isVisible = false
    }
    
    // MARK: - Visibility
    
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
                    pause()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
        
        if let trackingEvents = currentLinear?.trackingEvents {
            if isMuted {
                eventTracker.fireMute(from: trackingEvents)
            } else {
                eventTracker.fireUnmute(from: trackingEvents)
            }
        }
    }
    
    func handleTap() {
        guard let clickThrough = currentLinear?.videoClicks?.clickThrough,
              let url = URL(string: clickThrough) else {
            return
        }
        
        // Fire click tracking
        eventTracker.fireClickTracking(currentLinear?.videoClicks)
        
        // Notify callback
        onAdClicked?(url)
        
        // Open URL
        UIApplication.shared.open(url)
    }
    
    // MARK: - Loading
    
    private func loadAd() {
        guard state == .idle else { return }
        
        updateState(.loading)
        
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                log("Fetching VAST from: \(self.vastURL)")
                let response = try await self.parser.fetchAndParse(
                    url: self.vastURL,
                    maxWrapperDepth: self.configuration.maxWrapperDepth,
                    timeout: self.configuration.requestTimeout
                )
                
                log("VAST parsed - Ads count: \(response.ads.count)")
                
                guard let ad = response.firstAd else {
                    log("Error: No ad found in response")
                    throw VASTError.noAdsFound
                }
                log("Ad ID: \(ad.id)")
                
                guard let inLine = ad.inLine else {
                    log("Error: No InLine in ad")
                    throw VASTError.noAdsFound
                }
                log("InLine - Extensions: \(inLine.extensions.count), Creatives: \(inLine.creatives.count)")
                
                guard let creative = inLine.creatives.first else {
                    log("Error: No creatives found")
                    throw VASTError.noAdsFound
                }
                log("Creative ID: \(creative.id ?? "nil")")
                
                guard let linear = creative.linear else {
                    log("Error: No linear in creative")
                    throw VASTError.noAdsFound
                }
                log("Linear - Duration: \(linear.duration ?? 0)s, MediaFiles: \(linear.mediaFiles.count)")
                
                guard let mediaFile = linear.bestMediaFile() else {
                    log("Error: No suitable media file found")
                    throw VASTError.invalidMediaFile
                }
                log("MediaFile - URL: \(mediaFile.url), Type: \(mediaFile.type ?? "nil"), Size: \(mediaFile.width ?? 0)x\(mediaFile.height ?? 0)")
                
                guard let videoURL = URL(string: mediaFile.url) else {
                    log("Error: Invalid video URL: \(mediaFile.url)")
                    throw VASTError.invalidURL(mediaFile.url)
                }
                log("Video URL valid: \(videoURL)")
                
                await MainActor.run {
                    self.currentAd = ad
                    self.currentLinear = linear
                    
                    // Fire impressions
                    self.eventTracker.fireImpressions(inLine.impressions)
                    
                    // Setup player
                    log("Setting up player...")
                    self.setupPlayer(with: videoURL)
                    
                    self.onAdLoaded?(ad)
                    self.updateState(.ready)
                    log("State updated to .ready, isVisible: \(self.isVisible)")
                    // Note: Auto-play is handled in createPlayer() after async URL resolution
                }
                
            } catch let error as VASTError {
                log("VAST Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.handleError(error)
                }
            } catch {
                log("Unknown Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.handleError(.unknown(error.localizedDescription))
                }
            }
        }
    }
    
    private func setupPlayer(with url: URL) {
        log("Preparing video from URL...")
        
        // The CDN returns fmp4 without Content-Length header, causing CoreMediaErrorDomain -12939
        // Workaround: Download to temporary file first, then play from local file
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // First resolve redirects
                let finalURL = try await self.resolveRedirects(for: url)
                
                // Download to temp file
                let localURL = try await self.downloadVideoToTemp(from: finalURL)
                
                await MainActor.run {
                    self.createPlayer(with: localURL, isLocalFile: true)
                }
            } catch {
                await MainActor.run {
                    self.log("Failed to prepare video: \(error.localizedDescription)")
                    self.handleError(.networkError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Resolve any redirects and return the final URL
    private func resolveRedirects(for url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let finalURL = response.url {
            log("Resolved URL: \(finalURL.absoluteString.prefix(100))...")
            return finalURL
        }
        
        return url
    }
    
    /// Download video to temporary file
    private func downloadVideoToTemp(from url: URL) async throws -> URL {
        log("Downloading video to temporary file...")
        
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
        
        log("Video downloaded to: \(destinationURL.lastPathComponent)")
        return destinationURL
    }
    
    /// Actually create the player with the resolved URL
    private func createPlayer(with url: URL, isLocalFile: Bool = false) {
        log("Creating AVPlayer with \(isLocalFile ? "local file" : "URL"): \(url.lastPathComponent)")
        
        // Configure asset with options that work better for streaming CDN content
        // The issue is fmp4 format without Content-Length header
        let asset = AVURLAsset(url: url, options: [
            // Don't require precise duration - allows streaming without full download
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        
        // Use asset keys that we need - load them asynchronously
        let requiredAssetKeys = ["playable", "hasProtectedContent"]
        
        // Create player item with automatic asset key loading
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: requiredAssetKeys)
        
        // Set preferred forward buffer duration (in seconds) for streaming
        playerItem.preferredForwardBufferDuration = 5.0
        
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = isMuted
        
        // Configure player for streaming
        avPlayer.automaticallyWaitsToMinimizeStalling = true
        
        // Observe player item status for streaming videos that need buffering
        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch item.status {
                case .unknown:
                    self.log("Player item status: unknown (buffering...)")
                    
                case .readyToPlay:
                    self.log("Player item status: readyToPlay")
                    // If play was requested while loading, start playing now
                    if self.pendingPlay {
                        self.pendingPlay = false
                        self.log("Starting deferred playback")
                        self.performPlay()
                    }
                    
                case .failed:
                    // Get detailed error information
                    if let error = item.error {
                        let nsError = error as NSError
                        self.log("Player item failed:")
                        self.log("   - Domain: \(nsError.domain)")
                        self.log("   - Code: \(nsError.code)")
                        self.log("   - Description: \(nsError.localizedDescription)")
                        
                        // Check for underlying error
                        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                            self.log("   - Underlying domain: \(underlyingError.domain)")
                            self.log("   - Underlying code: \(underlyingError.code)")
                            self.log("   - Underlying description: \(underlyingError.localizedDescription)")
                        }
                        
                        // Log all user info keys for debugging
                        for (key, value) in nsError.userInfo {
                            self.log("   - \(key): \(value)")
                        }
                    } else {
                        self.log("Player item failed with unknown error")
                    }
                    self.handleError(.invalidMediaFile)
                    
                @unknown default:
                    self.log("Unknown player item status")
                }
            }
        }
        
        // Observe time for tracking
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }
        
        // Observe end
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnd()
            }
        }
        
        // Also observe for playback failures
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self?.log("Playback failed to end: \(error.localizedDescription)")
                }
            }
        }
        
        self.player = avPlayer
        
        // Check if we should auto-play now that player is set up
        log("Player created, checking auto-play conditions...")
        if self.isVisible && self.configuration.autoPlay {
            log("Conditions met, requesting play")
            self.play()
        }
    }
    
    // MARK: - Playback Control
    
    private func play() {
        guard let player = player else { 
            log("Warning: play() called but player is nil")
            return 
        }
        
        guard let playerItem = player.currentItem else {
            log("Warning: play() called but player has no currentItem")
            return
        }
        
        // Check if player item is ready for playback
        switch playerItem.status {
        case .readyToPlay:
            log("Player item ready, starting playback immediately")
            performPlay()
            
        case .unknown:
            log("Player item not ready yet, deferring playback...")
            pendingPlay = true
            // Update state to indicate we're still preparing
            updateState(.loading)
            
        case .failed:
            log("Player item failed: \(playerItem.error?.localizedDescription ?? "unknown error")")
            handleError(.invalidMediaFile)
            
        @unknown default:
            log("Unknown player item status, attempting playback anyway")
            performPlay()
        }
    }
    
    /// Actually perform playback (called when player item is ready)
    private func performPlay() {
        guard let player = player else { return }
        
        log("performPlay() - calling player.play()")
        player.play()
        updateState(.playing)
        
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
    
    private func pause() {
        guard let player = player, state == .playing else { return }
        
        player.pause()
        updateState(.paused)
        
        // Fire pause tracking
        if let trackingEvents = currentLinear?.trackingEvents {
            eventTracker.firePause(from: trackingEvents)
        }
    }
    
    // MARK: - Time Updates
    
    private func handleTimeUpdate(_ time: CMTime) {
        guard let duration = player?.currentItem?.duration,
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
    
    private func handlePlaybackEnd() {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        // Fire complete tracking
        if let trackingEvents = currentLinear?.trackingEvents {
            eventTracker.fireComplete(from: trackingEvents)
        }
        
        onAdCompleted?()
        
        updateState(.completed)
        
        // Handle post-ad behavior
        switch configuration.postAdBehavior {
        case .replay:
            replayAd()
            
        case .refreshAd:
            refreshAd()
            
        case .showLastFrame:
            // Do nothing, keep showing last frame
            break
            
        case .hide:
            updateState(.hidden)
        }
    }
    
    private func replayAd() {
        player?.seek(to: .zero)
        hasCompleted = false
        firedQuartiles = []
        firedProgress = []
        
        updateState(.ready)
        
        if isVisible && configuration.autoPlay {
            play()
        }
    }
    
    private func refreshAd() {
        cleanup()
        
        currentAd = nil
        currentLinear = nil
        hasStarted = false
        hasCompleted = false
        firedQuartiles = []
        firedProgress = []
        
        updateState(.idle)
        loadAd()
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: VASTError) {
        log("Error: \(error.localizedDescription)")
        
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
    
    // MARK: - State Management
    
    private func updateState(_ newState: VideoAdState) {
        state = newState
        onStateChanged?(newState)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        
        // Cancel status observer
        statusObserver?.invalidate()
        statusObserver = nil
        pendingPlay = false
        
        player?.pause()
        player = nil
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if configuration.debugLogging {
            print("[VideoAdView] \(message)")
        }
    }
}

// MARK: - Video Player Representable

struct VideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer?
    let videoGravity: AVLayerVideoGravity
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.videoGravity = videoGravity
        if let player = player {
            view.player = player
        }
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Only update if the player has changed
        if uiView.playerLayer.player !== player {
            uiView.player = player
            // Force a layout update to ensure the video layer displays correctly
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
        }
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set { 
            playerLayer.player = newValue
            // Ensure the layer is visible and properly configured
            playerLayer.isHidden = false
        }
    }
    
    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure the player layer fills the entire view
        playerLayer.frame = bounds
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var startPoint: UnitPoint = .init(x: -1.8, y: -1.2)
    @State private var endPoint: UnitPoint = .init(x: 0, y: -0.2)
    
    private let gradientColors = [
        Color.gray.opacity(0.2),
        Color.gray.opacity(0.4),
        Color.gray.opacity(0.5),
        Color.gray.opacity(0.4),
        Color.gray.opacity(0.2)
    ]
    
    var body: some View {
        ZStack {
            // Base background
            Color.gray.opacity(0.15)
            
            // Shimmer gradient overlay
            LinearGradient(
                colors: gradientColors,
                startPoint: startPoint,
                endPoint: endPoint
            )
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                startPoint = .init(x: 1, y: 1)
                endPoint = .init(x: 2.2, y: 2.2)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VideoAdView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            VideoAdView(
                vastURL: URL(string: "https://example.com/vast")!,
                configuration: .default
            )
            .frame(height: 250)
            .padding()
        }
    }
}
#endif

#endif // os(iOS)
