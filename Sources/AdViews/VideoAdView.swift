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
                let response = try await self.parser.fetchAndParse(
                    url: self.vastURL,
                    maxWrapperDepth: self.configuration.maxWrapperDepth,
                    timeout: self.configuration.requestTimeout
                )
                
                guard let ad = response.firstAd,
                      let inLine = ad.inLine,
                      let creative = inLine.creatives.first,
                      let linear = creative.linear,
                      let mediaFile = linear.bestMediaFile(),
                      let videoURL = URL(string: mediaFile.url) else {
                    throw VASTError.noAdsFound
                }
                
                await MainActor.run {
                    self.currentAd = ad
                    self.currentLinear = linear
                    
                    // Fire impressions
                    self.eventTracker.fireImpressions(inLine.impressions)
                    
                    // Setup player
                    self.setupPlayer(with: videoURL)
                    
                    self.onAdLoaded?(ad)
                    self.updateState(.ready)
                    
                    // Auto-play if visible
                    if self.isVisible && self.configuration.autoPlay {
                        self.play()
                    }
                }
                
            } catch let error as VASTError {
                await MainActor.run {
                    self.handleError(error)
                }
            } catch {
                await MainActor.run {
                    self.handleError(.unknown(error.localizedDescription))
                }
            }
        }
    }
    
    private func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = isMuted
        
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
        
        self.player = avPlayer
    }
    
    // MARK: - Playback Control
    
    private func play() {
        guard let player = player else { return }
        
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
        view.player = player
        view.videoGravity = videoGravity
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
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
        set { playerLayer.player = newValue }
    }
    
    var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.gray.opacity(0.2),
                Color.gray.opacity(0.4),
                Color.gray.opacity(0.2)
            ]),
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
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
