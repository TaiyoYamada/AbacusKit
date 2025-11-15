import Foundation

/// Metadata about the AbacusKit SDK and current model state
public struct AbacusMetadata: Sendable {
    /// Version of the AbacusKit SDK
    public let sdkVersion: String
    
    /// Currently loaded model version number
    public let modelVersion: Int?
    
    /// Timestamp of the last model update check
    public let lastUpdateCheck: Date?
    
    /// Get the current metadata
    public static var current: AbacusMetadata {
        // SDK version - should match Package.swift version
        let sdkVersion = "1.0.0"
        
        // Model version and last check would be retrieved from ModelCache
        // For now, return default values
        return AbacusMetadata(
            sdkVersion: sdkVersion,
            modelVersion: nil,
            lastUpdateCheck: nil
        )
    }
    
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
