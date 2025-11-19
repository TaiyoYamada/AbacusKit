import Foundation

/// Model version information from remote server
///
/// This structure represents the version.json file format
/// that contains model metadata and download information.
///
/// ## JSON Format
///
/// ```json
/// {
///   "version": 1,
///   "model_url": "https://s3.amazonaws.com/bucket/model.zip",
///   "updated_at": "2024-01-01T00:00:00Z"
/// }
/// ```
public struct ModelVersion: Codable, Sendable, Equatable {
    /// Version number of the model
    ///
    /// This is an integer that increments with each model update.
    /// Higher numbers represent newer versions.
    public let version: Int

    /// URL to download the model file
    ///
    /// This should be a presigned S3 URL pointing to a zip archive
    /// containing the CoreML model (.mlmodel or .mlmodelc).
    public let modelURL: URL

    /// Timestamp when the model was last updated
    ///
    /// This is optional and used for informational purposes.
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case version
        case modelURL = "model_url"
        case updatedAt = "updated_at"
    }

    /// Initialize a model version
    /// - Parameters:
    ///   - version: Version number
    ///   - modelURL: Download URL
    ///   - updatedAt: Update timestamp (optional)
    public init(version: Int, modelURL: URL, updatedAt: Date? = nil) {
        self.version = version
        self.modelURL = modelURL
        self.updatedAt = updatedAt
    }
}
