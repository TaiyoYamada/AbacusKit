import Foundation
import Logging

/// SwiftLog wrapper for structured logging throughout AbacusKit
///
/// This logger provides a consistent logging interface across all modules
/// using the official SwiftLog framework for structured, production-grade logging.
///
/// ## Usage
///
/// ```swift
/// let logger = Logger.make(category: "MyModule")
/// logger.info("Operation started")
/// logger.error("Operation failed", metadata: ["error": "\(error)"])
/// ```
public struct Logger: Sendable {
    private let logger: Logging.Logger
    
    private init(logger: Logging.Logger) {
        self.logger = logger
    }
    
    /// Create a logger for a specific category
    /// - Parameter category: The category/module name for this logger
    /// - Returns: Configured logger instance
    public static func make(category: String) -> Logger {
        var logger = Logging.Logger(label: "com.abacuskit.\(category)")
        logger.logLevel = .info
        return Logger(logger: logger)
    }
    
    /// Log an info-level message
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    public func info(
        _ message: String,
        metadata: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.info(
            Logging.Logger.Message(stringLiteral: message),
            metadata: convertMetadata(metadata),
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Log a debug-level message
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    public func debug(
        _ message: String,
        metadata: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.debug(
            Logging.Logger.Message(stringLiteral: message),
            metadata: convertMetadata(metadata),
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Log a warning-level message
    /// - Parameters:
    ///   - message: The message to log
    ///   - metadata: Optional metadata dictionary
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    public func warning(
        _ message: String,
        metadata: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.warning(
            Logging.Logger.Message(stringLiteral: message),
            metadata: convertMetadata(metadata),
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Log an error-level message
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error object
    ///   - metadata: Optional metadata dictionary
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    public func error(
        _ message: String,
        error: Error? = nil,
        metadata: [String: String]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        var fullMetadata = metadata ?? [:]
        if let error = error {
            fullMetadata["error"] = String(describing: error)
        }
        
        logger.error(
            Logging.Logger.Message(stringLiteral: message),
            metadata: convertMetadata(fullMetadata),
            file: file,
            function: function,
            line: line
        )
    }
    
    private func convertMetadata(_ metadata: [String: String]?) -> Logging.Logger.Metadata? {
        guard let metadata = metadata else { return nil }
        return metadata.mapValues { Logging.Logger.MetadataValue.string($0) }
    }
}
