import Foundation

/// Errors that can occur during AbacusKit operations
public enum AbacusError: Error {
    /// Model has not been loaded yet
    case modelNotLoaded
    
    /// Model download from S3 failed
    case downloadFailed(underlying: Error)
    
    /// Model file is corrupted or incompatible
    case invalidModel(reason: String)
    
    /// Inference execution failed
    case inferenceFailed(underlying: Error)
    
    /// Input preprocessing failed
    case preprocessingFailed(reason: String)
}

extension AbacusError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model has not been loaded. Please call configure() before performing inference."
        
        case .downloadFailed(let underlying):
            return "Failed to download model from S3: \(underlying.localizedDescription)"
        
        case .invalidModel(let reason):
            return "Model file is invalid or incompatible: \(reason)"
        
        case .inferenceFailed(let underlying):
            return "Inference execution failed: \(underlying.localizedDescription)"
        
        case .preprocessingFailed(let reason):
            return "Input preprocessing failed: \(reason)"
        }
    }
}
