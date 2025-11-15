import Foundation

/// Model version information from S3
public struct ModelVersion: Codable, Sendable {
    /// Version number of the model
    public let version: Int
    
    /// URL to download the model file
    public let modelURL: URL
    
    /// Timestamp when the model was last updated
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case version
        case modelURL = "model_url"
        case updatedAt = "updated_at"
    }
}
