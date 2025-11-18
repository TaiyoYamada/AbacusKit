import Foundation

/// Metadata about the AbacusKit SDK and current model state
///
/// This structure provides information about the SDK version,
/// loaded model, and update status.
public struct AbacusMetadata: Sendable, Equatable {
    /// Version of the AbacusKit SDK
    ///
    /// This follows semantic versioning (e.g., "1.0.0").
    public let sdkVersion: String
    
    /// Currently loaded model version number
    ///
    /// This is `nil` if no model has been loaded yet.
    public let modelVersion: Int?
    
    /// Timestamp of the last model update check
    ///
    /// This is `nil` if no update check has been performed yet.
    public let lastUpdateCheck: Date?
    
    /// Initialize metadata
    /// - Parameters:
    ///   - sdkVersion: Version of the SDK
    ///   - modelVersion: Currently loaded model version
    ///   - lastUpdateCheck: Timestamp of last update check
    public init(sdkVersion: String, modelVersion: Int?, lastUpdateCheck: Date?) {
        self.sdkVersion = sdkVersion
        self.modelVersion = modelVersion
        self.lastUpdateCheck = lastUpdateCheck
    }
}

extension AbacusMetadata: CustomStringConvertible {
    public var description: String {
        let modelVersionStr = modelVersion.map { "\($0)" } ?? "none"
        let lastCheckStr = lastUpdateCheck?.iso8601String ?? "never"
        return "AbacusMetadata(sdkVersion: \(sdkVersion), modelVersion: \(modelVersionStr), lastUpdateCheck: \(lastCheckStr))"
    }
}
