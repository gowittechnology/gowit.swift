import Foundation

// MARK: - AdError

public enum AdError: LocalizedError {
    case http(error: HTTPClientError)
    case serializationError
    case deserializationError(error: Error, data: Data)
    case invalidPlacements
    case invalidAdId
    case configurationError(message: String)
    case networkError(message: String)

    public var errorDescription: String? {
        switch self {
        case .http(let error):
            return "HTTP Error: \(error.localizedDescription)"
        case .serializationError:
            return "Failed to serialize request data"
        case .deserializationError(let error, _):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidPlacements:
            return "Invalid or empty placement configuration"
        case .invalidAdId:
            return "Ad ID is missing or invalid"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .http(let error):
            return "HTTP request failed with error: \(error.localizedDescription)"
        case .serializationError:
            return "Request data could not be encoded to JSON"
        case .deserializationError(let error, _):
            return "Server response could not be parsed: \(error.localizedDescription)"
        case .invalidPlacements:
            return "No valid placements provided for ad request"
        case .invalidAdId:
            return "The ad object does not contain a valid ad ID"
        case .configurationError(let message):
            return "SDK not properly configured: \(message)"
        case .networkError(let message):
            return "Network operation failed: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .http:
            return "Check your network connection and try again"
        case .serializationError:
            return "Verify that your request data is valid"
        case .deserializationError:
            return "The server response format may have changed. Please contact support."
        case .invalidPlacements:
            return "Ensure you provide at least one valid placement"
        case .invalidAdId:
            return "Ensure the ad object has a valid adId before sending events"
        case .configurationError:
            return "Call Gowit.shared.configure() with valid parameters before making requests"
        case .networkError:
            return "Check your internet connection and try again"
        }
    }
}

// MARK: - GowitError

public struct GowitError: Codable, LocalizedError {
    public let message: String
    public let code: String?
    public let details: [String: String]?

    public init(message: String, code: String? = nil, details: [String: String]? = nil) {
        self.message = message
        self.code = code
        self.details = details
    }

    enum CodingKeys: String, CodingKey {
        case message
        case code
        case details
    }

    public var errorDescription: String? {
        return message
    }

    public var failureReason: String? {
        return code != nil ? "Error code: \(code!)" : nil
    }

    public var recoverySuggestion: String? {
        return "Please check your request parameters and try again"
    }
}
