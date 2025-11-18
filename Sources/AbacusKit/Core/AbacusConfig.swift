import Foundation

/// Configuration for AbacusKit SDK
///
/// This configuration object contains all necessary settings for initializing
/// and running the AbacusKit inference engine.
///
/// ## Usage
///
/// ```swift
/// let config = AbacusConfig(
///     versionURL: URL(string: "https://s3.amazonaws.com/bucket/version.json")!,
///     modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
/// )
/// ```
public struct AbacusConfig: Sendable {
    /// URL to the version.json file on S3
    ///
    /// This URL should point to a JSON file containing:
    /// - `version`: Integer version number
    /// - `model_url`: Presigned S3 URL to download the model zip
    /// - `updated_at`: ISO8601 timestamp (optional)
    public let versionURL: URL
    
    /// Local directory URL for storing downloaded models
    ///
    /// Models will be downloaded, extracted, and cached in this directory.
    /// Ensure the app has write permissions to this location.
    public let modelDirectoryURL: URL
    
    /// Whether to force model update even if cached version matches
    ///
    /// Default is `false`. Set to `true` to always download the latest model.
    public let forceUpdate: Bool
    
    /// Initialize AbacusConfig
    /// - Parameters:
    ///   - versionURL: URL to version.json on S3
    ///   - modelDirectoryURL: Local directory for model storage
    ///   - forceUpdate: Whether to force model update (default: false)
    public init(
        versionURL: URL,
        modelDirectoryURL: URL,
        forceUpdate: Bool = false
    ) {
        self.versionURL = versionURL
        self.modelDirectoryURL = modelDirectoryURL
        self.forceUpdate = forceUpdate
    }
    
    /// Validate the configuration
    /// - Throws: AbacusError.invalidConfiguration if validation fails
    func validate() throws {
        guard let scheme = versionURL.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            throw AbacusError.invalidConfiguration(
                reason: "versionURL must use http or https scheme"
            )
        }
        
        guard modelDirectoryURL.isFileURL else {
            throw AbacusError.invalidConfiguration(
                reason: "modelDirectoryURL must be a file URL"
            )
        }
    }
}
