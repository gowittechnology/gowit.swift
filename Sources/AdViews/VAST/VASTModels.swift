import Foundation

// MARK: - VAST Response

/// Root VAST response containing one or more ads
public struct VASTResponse: Sendable {
    /// VAST version
    public let version: String
    
    /// List of ads in the response
    public let ads: [VASTAd]
    
    /// Returns the first available ad
    public var firstAd: VASTAd? {
        ads.first
    }
    
    /// Returns true if no ads are available
    public var isEmpty: Bool {
        ads.isEmpty
    }
    
    public init(version: String, ads: [VASTAd]) {
        self.version = version
        self.ads = ads
    }
}

// MARK: - VAST Ad

/// Represents a single ad unit which can be InLine or Wrapper
public struct VASTAd: Sendable {
    /// Unique identifier for the ad
    public let id: String
    
    /// Sequence number for ad ordering
    public let sequence: Int?
    
    /// InLine ad content (mutually exclusive with wrapper)
    public let inLine: VASTInLine?
    
    /// Wrapper ad content (mutually exclusive with inLine)
    public let wrapper: VASTWrapper?
    
    /// Returns true if this is an InLine ad
    public var isInLine: Bool {
        inLine != nil
    }
    
    /// Returns true if this is a Wrapper ad
    public var isWrapper: Bool {
        wrapper != nil
    }
    
    public init(id: String, sequence: Int? = nil, inLine: VASTInLine? = nil, wrapper: VASTWrapper? = nil) {
        self.id = id
        self.sequence = sequence
        self.inLine = inLine
        self.wrapper = wrapper
    }
}

// MARK: - VAST InLine

/// InLine ad containing the actual ad content
public struct VASTInLine: Sendable {
    /// Ad system information
    public let adSystem: VASTAdSystem?
    
    /// Ad title
    public let adTitle: String?
    
    /// Impression tracking URLs
    public let impressions: [VASTImpression]
    
    /// Error tracking URLs
    public let errors: [String]
    
    /// Viewable impression tracking
    public let viewableImpression: VASTViewableImpression?
    
    /// Creative elements
    public let creatives: [VASTCreative]
    
    public init(
        adSystem: VASTAdSystem? = nil,
        adTitle: String? = nil,
        impressions: [VASTImpression] = [],
        errors: [String] = [],
        viewableImpression: VASTViewableImpression? = nil,
        creatives: [VASTCreative] = []
    ) {
        self.adSystem = adSystem
        self.adTitle = adTitle
        self.impressions = impressions
        self.errors = errors
        self.viewableImpression = viewableImpression
        self.creatives = creatives
    }
}

// MARK: - VAST Wrapper

/// Wrapper ad that redirects to another VAST tag
public struct VASTWrapper: Sendable {
    /// Ad system information
    public let adSystem: VASTAdSystem?
    
    /// URI to the wrapped VAST tag
    public let vastAdTagURI: String
    
    /// Impression tracking URLs (fired in addition to wrapped ad)
    public let impressions: [VASTImpression]
    
    /// Error tracking URLs
    public let errors: [String]
    
    /// Viewable impression tracking
    public let viewableImpression: VASTViewableImpression?
    
    /// Creative elements (tracking additions)
    public let creatives: [VASTCreative]
    
    public init(
        adSystem: VASTAdSystem? = nil,
        vastAdTagURI: String,
        impressions: [VASTImpression] = [],
        errors: [String] = [],
        viewableImpression: VASTViewableImpression? = nil,
        creatives: [VASTCreative] = []
    ) {
        self.adSystem = adSystem
        self.vastAdTagURI = vastAdTagURI
        self.impressions = impressions
        self.errors = errors
        self.viewableImpression = viewableImpression
        self.creatives = creatives
    }
}

// MARK: - Ad System

/// Information about the ad serving system
public struct VASTAdSystem: Sendable {
    /// Name of the ad system
    public let name: String
    
    /// Version of the ad system
    public let version: String?
    
    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

// MARK: - Impression

/// Impression tracking URL
public struct VASTImpression: Sendable {
    /// Optional identifier
    public let id: String?
    
    /// Tracking URL
    public let url: String
    
    public init(id: String? = nil, url: String) {
        self.id = id
        self.url = url
    }
}

// MARK: - Viewable Impression

/// ViewableImpression tracking for viewability measurement
public struct VASTViewableImpression: Sendable {
    /// ID of the viewable impression
    public let id: String?
    
    /// URLs to fire when ad becomes viewable
    public let viewable: [String]
    
    /// URLs to fire when ad is not viewable
    public let notViewable: [String]
    
    /// URLs to fire when viewability is undetermined
    public let viewUndetermined: [String]
    
    public init(
        id: String? = nil,
        viewable: [String] = [],
        notViewable: [String] = [],
        viewUndetermined: [String] = []
    ) {
        self.id = id
        self.viewable = viewable
        self.notViewable = notViewable
        self.viewUndetermined = viewUndetermined
    }
}

// MARK: - Creative

/// Creative container
public struct VASTCreative: Sendable {
    /// Creative identifier
    public let id: String?
    
    /// Sequence number
    public let sequence: Int?
    
    /// Ad ID reference
    public let adId: String?
    
    /// Linear video content
    public let linear: VASTLinear?
    
    public init(
        id: String? = nil,
        sequence: Int? = nil,
        adId: String? = nil,
        linear: VASTLinear? = nil
    ) {
        self.id = id
        self.sequence = sequence
        self.adId = adId
        self.linear = linear
    }
}

// MARK: - Linear

/// Linear video ad content
public struct VASTLinear: Sendable {
    /// Video duration in seconds
    public let duration: TimeInterval?
    
    /// Media files for playback
    public let mediaFiles: [VASTMediaFile]
    
    /// Click-through and tracking
    public let videoClicks: VASTVideoClicks?
    
    /// Tracking events
    public let trackingEvents: [VASTTrackingEvent]
    
    /// Skip offset in seconds (nil if not skippable)
    public let skipOffset: TimeInterval?
    
    /// Returns the best media file for the given criteria
    public func bestMediaFile(preferredWidth: Int = 640, preferredType: String = "video/mp4") -> VASTMediaFile? {
        // Prefer MP4 files
        let mp4Files = mediaFiles.filter { $0.type == preferredType }
        let candidates = mp4Files.isEmpty ? mediaFiles : mp4Files
        
        // Sort by width closest to preferred
        return candidates.min { file1, file2 in
            let diff1 = abs((file1.width ?? 0) - preferredWidth)
            let diff2 = abs((file2.width ?? 0) - preferredWidth)
            return diff1 < diff2
        }
    }
    
    public init(
        duration: TimeInterval? = nil,
        mediaFiles: [VASTMediaFile] = [],
        videoClicks: VASTVideoClicks? = nil,
        trackingEvents: [VASTTrackingEvent] = [],
        skipOffset: TimeInterval? = nil
    ) {
        self.duration = duration
        self.mediaFiles = mediaFiles
        self.videoClicks = videoClicks
        self.trackingEvents = trackingEvents
        self.skipOffset = skipOffset
    }
}

// MARK: - Media File

/// Video media file information
public struct VASTMediaFile: Sendable {
    /// Video URL
    public let url: String
    
    /// Delivery method (progressive, streaming)
    public let delivery: String?
    
    /// MIME type
    public let type: String?
    
    /// Video width in pixels
    public let width: Int?
    
    /// Video height in pixels
    public let height: Int?
    
    /// Codec information
    public let codec: String?
    
    /// Bitrate in kbps
    public let bitrate: Int?
    
    /// Minimum bitrate in kbps
    public let minBitrate: Int?
    
    /// Maximum bitrate in kbps
    public let maxBitrate: Int?
    
    /// Whether the media is scalable
    public let scalable: Bool?
    
    /// Whether aspect ratio should be maintained
    public let maintainAspectRatio: Bool?
    
    public init(
        url: String,
        delivery: String? = nil,
        type: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        codec: String? = nil,
        bitrate: Int? = nil,
        minBitrate: Int? = nil,
        maxBitrate: Int? = nil,
        scalable: Bool? = nil,
        maintainAspectRatio: Bool? = nil
    ) {
        self.url = url
        self.delivery = delivery
        self.type = type
        self.width = width
        self.height = height
        self.codec = codec
        self.bitrate = bitrate
        self.minBitrate = minBitrate
        self.maxBitrate = maxBitrate
        self.scalable = scalable
        self.maintainAspectRatio = maintainAspectRatio
    }
}

// MARK: - Video Clicks

/// Video click-through and tracking
public struct VASTVideoClicks: Sendable {
    /// Click-through URL (the destination when user clicks)
    public let clickThrough: String?
    
    /// Click tracking URLs (fired when user clicks)
    public let clickTracking: [String]
    
    /// Custom click URLs
    public let customClick: [String]
    
    public init(
        clickThrough: String? = nil,
        clickTracking: [String] = [],
        customClick: [String] = []
    ) {
        self.clickThrough = clickThrough
        self.clickTracking = clickTracking
        self.customClick = customClick
    }
}

// MARK: - Tracking Event

/// Tracking event type
public enum VASTTrackingEventType: String, Sendable, CaseIterable {
    case start
    case firstQuartile
    case midpoint
    case thirdQuartile
    case complete
    case mute
    case unmute
    case pause
    case resume
    case rewind
    case skip
    case playerExpand
    case playerCollapse
    case progress
    case creativeView
    case acceptInvitation
    case adExpand
    case adCollapse
    case minimize
    case close
    case overlayViewDuration
    case otherAdInteraction
}

/// Tracking event with URL
public struct VASTTrackingEvent: Sendable {
    /// Event type
    public let event: VASTTrackingEventType
    
    /// Tracking URL
    public let url: String
    
    /// Offset for progress events (in seconds)
    public let offset: TimeInterval?
    
    public init(event: VASTTrackingEventType, url: String, offset: TimeInterval? = nil) {
        self.event = event
        self.url = url
        self.offset = offset
    }
}

// MARK: - VAST Error

/// Errors that can occur during VAST processing
public enum VASTError: Error, LocalizedError, Sendable {
    case networkError(String)
    case parsingError(String)
    case noAdsFound
    case wrapperDepthExceeded(Int)
    case invalidMediaFile
    case invalidClickThrough
    case invalidURL(String)
    case timeout
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .noAdsFound:
            return "No ads found in VAST response"
        case .wrapperDepthExceeded(let depth):
            return "Wrapper depth exceeded maximum of \(depth)"
        case .invalidMediaFile:
            return "No valid media file found"
        case .invalidClickThrough:
            return "Invalid click-through URL"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .timeout:
            return "Request timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    /// VAST error code for tracking
    public var vastErrorCode: Int {
        switch self {
        case .networkError:
            return 900 // Undefined error
        case .parsingError:
            return 100 // XML parsing error
        case .noAdsFound:
            return 303 // No ads VAST response
        case .wrapperDepthExceeded:
            return 302 // Wrapper limit reached
        case .invalidMediaFile:
            return 401 // File not found
        case .invalidClickThrough:
            return 900 // Undefined error
        case .invalidURL:
            return 900 // Undefined error
        case .timeout:
            return 301 // Time-out of VAST URI
        case .unknown:
            return 900 // Undefined error
        }
    }
}
