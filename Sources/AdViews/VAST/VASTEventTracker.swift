import Foundation

// MARK: - VAST Event Tracker

/// Fire-and-forget event tracker for VAST events
/// All tracking requests are sent asynchronously and failures are silently logged
public final class VASTEventTracker: @unchecked Sendable {
    
    /// Shared singleton instance
    public static let shared = VASTEventTracker()
    
    /// Enable/disable debug logging
    public var debugLoggingEnabled: Bool = false
    
    /// Timeout for tracking requests
    public var timeout: TimeInterval = 10
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Impression Tracking
    
    /// Fire all impression URLs for an InLine ad
    public func fireImpressions(_ impressions: [VASTImpression]) {
        for impression in impressions {
            fireURL(impression.url, eventType: "impression")
        }
    }
    
    /// Fire impression URL
    public func fireImpression(_ impression: VASTImpression) {
        fireURL(impression.url, eventType: "impression")
    }
    
    // MARK: - Error Tracking
    
    /// Fire error URLs with error code
    public func fireErrors(_ errorURLs: [String], errorCode: Int) {
        for urlString in errorURLs {
            // Replace [ERRORCODE] macro with actual error code
            let resolvedURL = urlString.replacingOccurrences(of: "[ERRORCODE]", with: String(errorCode))
            fireURL(resolvedURL, eventType: "error")
        }
    }
    
    /// Fire error URL with error code
    public func fireError(_ errorURL: String, errorCode: Int) {
        let resolvedURL = errorURL.replacingOccurrences(of: "[ERRORCODE]", with: String(errorCode))
        fireURL(resolvedURL, eventType: "error")
    }
    
    // MARK: - Viewable Impression Tracking
    
    /// Fire viewable impression URLs
    public func fireViewable(_ viewableImpression: VASTViewableImpression?) {
        guard let vi = viewableImpression else { return }
        for url in vi.viewable {
            fireURL(url, eventType: "viewable")
        }
    }
    
    /// Fire not viewable URLs
    public func fireNotViewable(_ viewableImpression: VASTViewableImpression?) {
        guard let vi = viewableImpression else { return }
        for url in vi.notViewable {
            fireURL(url, eventType: "notViewable")
        }
    }
    
    /// Fire view undetermined URLs
    public func fireViewUndetermined(_ viewableImpression: VASTViewableImpression?) {
        guard let vi = viewableImpression else { return }
        for url in vi.viewUndetermined {
            fireURL(url, eventType: "viewUndetermined")
        }
    }
    
    // MARK: - Tracking Events
    
    /// Fire a specific tracking event
    public func fireTrackingEvent(_ event: VASTTrackingEventType, from trackingEvents: [VASTTrackingEvent]) {
        let matchingEvents = trackingEvents.filter { $0.event == event }
        for tracking in matchingEvents {
            fireURL(tracking.url, eventType: event.rawValue)
        }
    }
    
    /// Fire start event
    public func fireStart(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.start, from: trackingEvents)
    }
    
    /// Fire complete event
    public func fireComplete(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.complete, from: trackingEvents)
    }
    
    /// Fire first quartile event (25%)
    public func fireFirstQuartile(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.firstQuartile, from: trackingEvents)
    }
    
    /// Fire midpoint event (50%)
    public func fireMidpoint(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.midpoint, from: trackingEvents)
    }
    
    /// Fire third quartile event (75%)
    public func fireThirdQuartile(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.thirdQuartile, from: trackingEvents)
    }
    
    /// Fire mute event
    public func fireMute(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.mute, from: trackingEvents)
    }
    
    /// Fire unmute event
    public func fireUnmute(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.unmute, from: trackingEvents)
    }
    
    /// Fire pause event
    public func firePause(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.pause, from: trackingEvents)
    }
    
    /// Fire resume event
    public func fireResume(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.resume, from: trackingEvents)
    }
    
    /// Fire skip event
    public func fireSkip(from trackingEvents: [VASTTrackingEvent]) {
        fireTrackingEvent(.skip, from: trackingEvents)
    }
    
    // MARK: - Click Tracking
    
    /// Fire click tracking URLs
    public func fireClickTracking(_ videoClicks: VASTVideoClicks?) {
        guard let clicks = videoClicks else { return }
        for url in clicks.clickTracking {
            fireURL(url, eventType: "clickTracking")
        }
    }
    
    /// Fire custom click URLs
    public func fireCustomClick(_ videoClicks: VASTVideoClicks?) {
        guard let clicks = videoClicks else { return }
        for url in clicks.customClick {
            fireURL(url, eventType: "customClick")
        }
    }
    
    // MARK: - Progress Tracking
    
    /// Check and fire progress tracking events based on current time
    /// - Parameters:
    ///   - currentTime: Current playback time in seconds
    ///   - duration: Total video duration in seconds
    ///   - trackingEvents: All tracking events
    ///   - firedProgress: Set of already fired progress offsets
    /// - Returns: Updated set of fired progress offsets
    public func checkProgressEvents(
        currentTime: TimeInterval,
        duration: TimeInterval,
        trackingEvents: [VASTTrackingEvent],
        firedProgress: inout Set<TimeInterval>
    ) {
        let progressEvents = trackingEvents.filter { $0.event == .progress }
        
        for event in progressEvents {
            guard let offset = event.offset,
                  !firedProgress.contains(offset),
                  currentTime >= offset else { continue }
            
            fireURL(event.url, eventType: "progress")
            firedProgress.insert(offset)
        }
    }
    
    // MARK: - Quartile Tracking Helper
    
    /// Track quartile events based on playback progress
    /// - Parameters:
    ///   - currentTime: Current playback time in seconds
    ///   - duration: Total video duration in seconds
    ///   - trackingEvents: All tracking events
    ///   - firedQuartiles: Set of already fired quartile events
    /// - Returns: Updated set of fired quartile events
    public func checkQuartileEvents(
        currentTime: TimeInterval,
        duration: TimeInterval,
        trackingEvents: [VASTTrackingEvent],
        firedQuartiles: inout Set<VASTTrackingEventType>
    ) {
        guard duration > 0 else { return }
        
        let progress = currentTime / duration
        
        // First quartile (25%)
        if progress >= 0.25 && !firedQuartiles.contains(.firstQuartile) {
            fireFirstQuartile(from: trackingEvents)
            firedQuartiles.insert(.firstQuartile)
        }
        
        // Midpoint (50%)
        if progress >= 0.50 && !firedQuartiles.contains(.midpoint) {
            fireMidpoint(from: trackingEvents)
            firedQuartiles.insert(.midpoint)
        }
        
        // Third quartile (75%)
        if progress >= 0.75 && !firedQuartiles.contains(.thirdQuartile) {
            fireThirdQuartile(from: trackingEvents)
            firedQuartiles.insert(.thirdQuartile)
        }
    }
    
    // MARK: - Private Methods
    
    private func fireURL(_ urlString: String, eventType: String) {
        guard let url = URL(string: urlString) else {
            logDebug("Invalid URL for \(eventType): \(urlString)")
            return
        }
        
        logDebug("Firing \(eventType): \(urlString)")
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = timeout
                request.cachePolicy = .reloadIgnoringLocalCacheData
                
                let (_, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    logDebug("\(eventType) response: \(httpResponse.statusCode)")
                }
            } catch {
                logDebug("\(eventType) error: \(error.localizedDescription)")
            }
        }
    }
    
    private func logDebug(_ message: String) {
        if debugLoggingEnabled {
            print("[VASTEventTracker] \(message)")
        }
    }
}
