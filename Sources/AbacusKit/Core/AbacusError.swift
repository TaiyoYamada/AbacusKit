import Foundation

/// Errors that can occur during AbacusKit operations
///
/// All possible error cases are represented here following the principle
/// of explicit error handling and type safety.
public enum AbacusError: Error, Sendable {
    /// Configuration has not been completed
    case notConfigured

    /// Model has not been loaded yet
    case modelNotLoaded

    /// Failed to fetch version information from remote
    case versionCheckFailed(underlying: Error)

    /// Model download from S3 failed
    case downloadFailed(underlying: Error)

    /// Model extraction from zip failed
    case extractionFailed(underlying: Error)

    /// Model file is corrupted or incompatible
    case invalidModel(reason: String)

    /// CoreML model loading failed
    case modelLoadFailed(underlying: Error)

    /// Inference execution failed
    case inferenceFailed(underlying: Error)

    /// Input preprocessing failed
    case preprocessingFailed(reason: String)

    /// File storage operation failed
    case storageFailed(reason: String)

    /// Invalid configuration provided
    case invalidConfiguration(reason: String)
}

extension AbacusError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            "AbacusKit has not been configured. Please call configure() first."

        case .modelNotLoaded:
            "Model has not been loaded. Please call configure() before performing inference."

        case .versionCheckFailed(let underlying):
            "Failed to check model version: \(underlying.localizedDescription)"

        case .downloadFailed(let underlying):
            "Failed to download model from S3: \(underlying.localizedDescription)"

        case .extractionFailed(let underlying):
            "Failed to extract model archive: \(underlying.localizedDescription)"

        case .invalidModel(let reason):
            "Model file is invalid or incompatible: \(reason)"

        case .modelLoadFailed(let underlying):
            "Failed to load CoreML model: \(underlying.localizedDescription)"

        case .inferenceFailed(let underlying):
            "Inference execution failed: \(underlying.localizedDescription)"

        case .preprocessingFailed(let reason):
            "Input preprocessing failed: \(reason)"

        case .storageFailed(let reason):
            "File storage operation failed: \(reason)"

        case .invalidConfiguration(let reason):
            "Invalid configuration: \(reason)"
        }
    }
}
