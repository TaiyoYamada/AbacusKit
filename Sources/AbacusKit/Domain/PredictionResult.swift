import Foundation

/// Result of a prediction inference operation
///
/// This structure contains the output of a single inference operation,
/// including the predicted value, confidence score, and performance metrics.
public struct PredictionResult: Sendable, Equatable {
    /// The predicted value
    ///
    /// This is the primary output of the model inference.
    public let value: Int

    /// Confidence score of the prediction (0.0 to 1.0)
    ///
    /// Higher values indicate greater confidence in the prediction.
    /// A value of 1.0 represents maximum confidence.
    public let confidence: Double

    /// Inference time in milliseconds
    ///
    /// This measures the time taken for the inference operation,
    /// useful for performance monitoring and optimization.
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

extension PredictionResult: CustomStringConvertible {
    public var description: String {
        "PredictionResult(value: \(value), confidence: \(confidence), inferenceTimeMs: \(inferenceTimeMs))"
    }
}
