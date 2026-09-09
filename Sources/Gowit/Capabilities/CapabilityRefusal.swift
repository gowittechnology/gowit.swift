import Foundation

/// The class a refusal belongs to. A reader branches on `class` before it reads
/// `code`, so that the same invalid tuple gets the same class in every language.
public enum RefusalClass: String, Codable {
    case unauthorized
    case incompatible
    case unsupported
    case invalidContent = "invalid_content"
    case conflict
    /// An upstream outage. NOT `incompatible`: a known absent capability is
    /// incompatibility, while an outage is not a statement about the ad.
    case degraded
}

/// The subset of the platform's closed refusal vocabulary this client can raise
/// locally. The server's vocabulary is wider; a client that meets a code it does not
/// know reports it verbatim rather than reclassifying it.
public enum RefusalCode: String, Codable {
    case missingCapability = "MISSING_CAPABILITY"
    case unsupportedProtocolMajor = "UNSUPPORTED_PROTOCOL_MAJOR"
    case geometryIncompatible = "GEOMETRY_INCOMPATIBLE"
    case noCompatibleVariant = "NO_COMPATIBLE_VARIANT"
}

/// A structured refusal. A refusal names WHAT was wrong; it never carries advertiser
/// copy, media bytes or markup, which is why there is no field that could hold them.
public struct CapabilityRefusal: Error, Codable, Equatable {
    public let refusalClass: RefusalClass
    public let code: RefusalCode
    /// On `MISSING_CAPABILITY`: the tokens the variant required and this runtime did
    /// not declare. Naming them is the difference between a refusal a caller can act
    /// on and one it can only log.
    public let missingCapabilities: [String]?
    /// Optional operator-facing English. Never rendered to an advertiser, never parsed.
    public let message: String?

    public init(
        refusalClass: RefusalClass,
        code: RefusalCode,
        missingCapabilities: [String]? = nil,
        message: String? = nil
    ) {
        self.refusalClass = refusalClass
        self.code = code
        self.missingCapabilities = missingCapabilities
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case refusalClass = "class"
        case code
        case missingCapabilities = "missing_capabilities"
        case message
    }

    public static func missingCapability(_ tokens: [String], message: String? = nil) -> CapabilityRefusal {
        CapabilityRefusal(refusalClass: .incompatible, code: .missingCapability, missingCapabilities: tokens, message: message)
    }

    public static func unsupportedProtocolMajor(_ major: Int) -> CapabilityRefusal {
        CapabilityRefusal(refusalClass: .incompatible, code: .unsupportedProtocolMajor, message: "protocol_major \(major)")
    }
}

extension CapabilityRefusal: LocalizedError {
    public var errorDescription: String? {
        if let tokens = missingCapabilities, !tokens.isEmpty {
            return "\(code.rawValue): \(tokens.joined(separator: ", "))"
        }
        return code.rawValue
    }
}
