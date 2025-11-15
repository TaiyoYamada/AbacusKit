import Foundation

/// Result of a prediction inference operation
public struct PredictionResult: Sendable {
    /// The predicted value
    public let value: Int
    
    /// Confidence score of the prediction (0.0 to 1.0)
    public let confidence: Double
    
    /// Inference time in milliseconds
    public let inferenceTimeMs: Int
    
    /// Initialize a prediction result
    /// - Parameters:
    ///   - value: The predicted value
    ///   - confidence: Confidence score (0.0 to 1.0)
    ///   - inferenceTimeMs: Inference time in milliseconds
    public init(value: Int, confidence: Double, inferenceTimeMs: Int) {
        self.value = value
        self.confidence = confidence
        self.inferenceTimeMs = inferenceTimeMs
    }
}
