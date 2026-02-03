// AbacusKit - SorobanLane
// Swift 6.2

import CoreGraphics
import Foundation

/// Represents a complete lane (single digit column) on a soroban.
///
/// A `SorobanLane` encapsulates all information about a single digit position
/// on the soroban, including the calculated digit value, its location in the
/// image, and the raw inference results used to determine bead states.
///
/// ## Overview
///
/// Each lane corresponds to one column of beads on the soroban and represents
/// a single digit (0-9). The lane contains:
///
/// - A ``SorobanDigit`` with the calculated value and bead states
/// - The region of interest (ROI) in the original image
/// - Raw prediction data from the neural network
///
/// ## Example
///
/// ```swift
/// for lane in result.lanes {
///     print("Position \(lane.position): \(lane.value)")
///     print("Confidence: \(lane.confidence)")
///     print("Bounding box: \(lane.roi)")
/// }
/// ```
public struct SorobanLane: Sendable, Equatable {
    /// The digit information for this lane.
    ///
    /// Contains the calculated value, bead states, and confidence
    /// for this single digit position.
    public let digit: SorobanDigit

    /// The region of interest in the original image coordinates.
    ///
    /// This rectangle indicates where this lane was detected in the
    /// input camera frame. Useful for overlaying recognition results
    /// on the camera preview.
    public let roi: CGRect

    /// The processing time for this lane in milliseconds.
    ///
    /// Represents the time taken to extract and process this individual
    /// lane, excluding shared preprocessing time.
    public let processingTimeMs: Double

    /// The raw inference predictions for each bead in this lane.
    ///
    /// Contains 5 ``CellPrediction`` items: one for the upper bead,
    /// followed by four for the lower beads (top to bottom).
    public let rawPredictions: [CellPrediction]

    /// Creates a new soroban lane.
    ///
    /// - Parameters:
    ///   - digit: The digit information including calculated value.
    ///   - roi: The bounding box in original image coordinates.
    ///   - processingTimeMs: Optional processing time in milliseconds.
    ///   - rawPredictions: Optional raw inference outputs for each bead.
    public init(
        digit: SorobanDigit,
        roi: CGRect,
        processingTimeMs: Double = 0,
        rawPredictions: [CellPrediction] = []
    ) {
        self.digit = digit
        self.roi = roi
        self.processingTimeMs = processingTimeMs
        self.rawPredictions = rawPredictions
    }

    /// The position of this lane (0 = rightmost digit).
    ///
    /// Convenience accessor that returns ``SorobanDigit/position``.
    public var position: Int {
        digit.position
    }

    /// The numeric value of this lane (0-9).
    ///
    /// Convenience accessor that returns ``SorobanDigit/value``.
    public var value: Int {
        digit.value
    }

    /// The confidence score for this lane (0.0-1.0).
    ///
    /// Convenience accessor that returns ``SorobanDigit/confidence``.
    public var confidence: Float {
        digit.confidence
    }
}

// MARK: - CellPrediction

/// Represents the inference result for a single bead.
///
/// Contains the predicted bead state along with the raw probability
/// distribution from the neural network classifier.
///
/// ## Overview
///
/// Each bead on the soroban is classified into one of three states:
/// - `.upper`: The bead is in the upper position (not counted)
/// - `.lower`: The bead is in the lower position (counted)
/// - `.empty`: The bead state could not be determined
///
/// The `probabilities` array contains the softmax outputs for each class,
/// allowing you to assess the certainty of the prediction.
///
/// ## Example
///
/// ```swift
/// let prediction = CellPrediction(
///     predictedClass: .lower,
///     probabilities: [0.1, 0.85, 0.05]  // [upper, lower, empty]
/// )
/// print(prediction.confidence)  // 0.85
/// ```
public struct CellPrediction: Sendable, Equatable {
    /// The predicted bead state.
    ///
    /// This is the class with the highest probability in the
    /// ``probabilities`` array.
    public let predictedClass: CellState

    /// The probability distribution across all classes.
    ///
    /// Contains softmax probabilities for each class in order:
    /// `[upper, lower, empty]`. Values sum to 1.0.
    public let probabilities: [Float]

    /// The confidence of this prediction.
    ///
    /// Returns the maximum probability in the distribution,
    /// which corresponds to the probability of the predicted class.
    public var confidence: Float {
        probabilities.max() ?? 0
    }

    /// Creates a new cell prediction.
    ///
    /// - Parameters:
    ///   - predictedClass: The predicted bead state.
    ///   - probabilities: The softmax probability distribution.
    public init(predictedClass: CellState, probabilities: [Float]) {
        self.predictedClass = predictedClass
        self.probabilities = probabilities
    }
}
