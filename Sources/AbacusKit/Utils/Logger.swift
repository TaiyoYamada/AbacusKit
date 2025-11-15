import Foundation

/// Logging utility for AbacusKit with conditional debug compilation
struct Logger {
    
    /// Log level enumeration
    enum Level: String {
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
    }
    
    /// Log category for organizing messages
    private let category: String
    
    /// Initialize logger with a category
    /// - Parameter category: Category name for log messages (e.g., "Networking", "ML", "Storage")
    init(category: String) {
        self.category = category
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error object to include
    ///   - file: Source file (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, file: file, function: function, line: line)
    }
    
    /// Internal logging method
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: Log level
    ///   - file: Source file
    ///   - function: Function name
    ///   - line: Line number
    private func log(
        _ message: String,
        level: Level,
        file: String,
        function: String,
        line: Int
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        
        print("[\(timestamp)] [\(level.rawValue)] [\(category)] [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
}

// MARK: - Static Loggers

extension Logger {
    /// Logger for Core layer
    static let core = Logger(category: "Core")
    
    /// Logger for ML layer
    static let ml = Logger(category: "ML")
    
    /// Logger for Networking layer
    static let networking = Logger(category: "Networking")
    
    /// Logger for Storage layer
    static let storage = Logger(category: "Storage")
    
    /// Logger for Utils layer
    static let utils = Logger(category: "Utils")
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
