import Foundation

/// Configuration for AbacusKit SDK
public struct AbacusConfig: Sendable {
    /// URL to the version.json file on S3
    public let versionURL: URL
    
    /// Local directory URL for storing downloaded models
    public let modelDirectoryURL: URL
    
    /// Initialize AbacusConfig
    /// - Parameters:
    ///   - versionURL: URL to version.json on S3
    ///   - modelDirectoryURL: Local directory for model storage
    public init(versionURL: URL, modelDirectoryURL: URL) {
        self.versionURL = versionURL
        self.modelDirectoryURL = modelDirectoryURL
    }
}
