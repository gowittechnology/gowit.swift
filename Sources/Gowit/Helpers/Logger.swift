import Foundation

/// Logger utility for the Gowit SDK
/// By default, only errors are logged. Enable debug mode for detailed logs.
public enum GowitLogger {
    
    /// Enable detailed debug logging throughout the SDK
    /// - Note: Set to true during development, false in production
    public static var isDebugEnabled = false
    
    /// Log levels for categorizing messages
    public enum Level {
        case debug
        case error
        
        var prefix: String {
            switch self {
            case .debug: return "[Gowit:Debug]"
            case .error: return "[Gowit:Error]"
            }
        }
    }
    
    /// Log a debug message (only if debug mode is enabled)
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    public static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isDebugEnabled else { return }
        let fileName = (file as NSString).lastPathComponent
        print("\(Level.debug.prefix) [\(fileName):\(line)] \(message)")
    }
    
    /// Log an error message (always logged)
    /// - Parameters:
    ///   - message: The error message to log
    ///   - error: Optional error object
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    public static func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "\(Level.error.prefix) [\(fileName):\(line)] \(message)"
        if let error = error {
            logMessage += " - \(error.localizedDescription)"
        }
        print(logMessage)
    }
}
