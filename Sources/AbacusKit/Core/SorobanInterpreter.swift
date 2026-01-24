// AbacusKit - SorobanInterpreter
// Swift 6.2

import CoreGraphics
import Foundation

/// Interprets soroban bead states and calculates numeric values.
///
/// `SorobanInterpreter` converts classified bead states from neural network
/// inference into numeric digit values according to standard soroban
/// counting rules.
///
/// ## Soroban Counting Rules
///
/// Each soroban digit consists of:
/// - 1 upper bead worth 5 points (when in lower position)
/// - 4 lower beads worth 1 point each (when in lower position)
///
/// The digit value (0-9) is the sum of all counted beads.
///
/// ## Usage
///
/// The interpreter is typically used internally by ``AbacusRecognizer``,
/// but can be used directly for custom processing pipelines:
///
/// ```swift
/// let interpreter = SorobanInterpreter()
///
/// // Calculate a single digit value
/// let value = interpreter.calculateDigitValue(
///     upperBead: .lower,      // 5 points
///     lowerBeads: [.lower, .lower, .upper, .upper]  // 2 points
/// )
/// print(value)  // 7
///
/// // Calculate total value from lanes
/// let total = interpreter.interpret(lanes: recognitionResult.lanes)
/// ```
public struct SorobanInterpreter: Sendable {
    /// Creates a new soroban interpreter.
    public init() {}

    /// Calculates the total numeric value from a list of lanes.
    ///
    /// The lanes are sorted by position and combined according to their
    /// positional significance (ones, tens, hundreds, etc.).
    ///
    /// - Parameter lanes: An array of recognition lanes (any order).
    /// - Returns: The combined integer value represented by all lanes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // For lanes representing digits [1, 2, 3] (positions 2, 1, 0)
    /// let value = interpreter.interpret(lanes: lanes)
    /// // Returns 123
    /// ```
    public func interpret(lanes: [SorobanLane]) -> Int {
        guard !lanes.isEmpty else {
            return 0
        }

        // Sort by position (rightmost = 0, increasing to the left)
        let sortedLanes = lanes.sorted { $0.position < $1.position }

        var value = 0
        var multiplier = 1

        for lane in sortedLanes {
            value += lane.value * multiplier
            multiplier *= 10
        }

        return value
    }

    /// Calculates a single digit value from bead states.
    ///
    /// Applies standard soroban counting rules:
    /// - Upper bead in lower position: 5 points
    /// - Each lower bead in lower position: 1 point
    ///
    /// - Parameters:
    ///   - upperBead: The state of the upper bead.
    ///   - lowerBeads: The states of the four lower beads.
    /// - Returns: The digit value (0-9).
    public func calculateDigitValue(upperBead: CellState, lowerBeads: [CellState]) -> Int {
        var value = 0

        // Upper bead in lower position = 5 points
        if upperBead == .lower {
            value += 5
        }

        // Each lower bead in lower position = 1 point
        for bead in lowerBeads {
            if bead == .lower {
                value += 1
            }
        }

        return min(9, value)
    }

    /// Constructs lane objects from raw inference predictions.
    ///
    /// This method takes the raw cell predictions from neural network
    /// inference and assembles them into structured ``SorobanLane`` objects.
    ///
    /// - Parameters:
    ///   - predictions: Raw cell predictions (5 per lane: 1 upper + 4 lower).
    ///   - laneCount: The number of lanes to construct.
    ///   - boundingBoxes: Bounding boxes for each lane in image coordinates.
    /// - Returns: An array of constructed lanes, or empty if inputs are invalid.
    ///
    /// - Precondition: `predictions.count` must equal `laneCount * 5`.
    /// - Precondition: `boundingBoxes.count` must equal `laneCount`.
    public func buildLanes(
        from predictions: [CellPrediction],
        laneCount: Int,
        boundingBoxes: [CGRect]
    ) -> [SorobanLane] {
        guard predictions.count == laneCount * 5,
              boundingBoxes.count == laneCount else
        {
            return []
        }

        var lanes: [SorobanLane] = []

        for i in 0..<laneCount {
            let startIndex = i * 5
            let cellPredictions = Array(predictions[startIndex..<startIndex + 5])

            let upperBead = cellPredictions[0].predictedClass
            let lowerBeads = cellPredictions[1...4].map { $0.predictedClass }

            let confidence = cellPredictions.map { $0.confidence }.min() ?? 0

            let digit = SorobanDigit(
                position: laneCount - 1 - i,
                upperBead: upperBead,
                lowerBeads: Array(lowerBeads),
                confidence: confidence,
                boundingBox: boundingBoxes[i],
                probabilities: cellPredictions.map { $0.probabilities }
            )

            let lane = SorobanLane(
                digit: digit,
                roi: boundingBoxes[i],
                rawPredictions: cellPredictions
            )

            lanes.append(lane)
        }

        return lanes
    }

    /// Validates recognition results against quality thresholds.
    ///
    /// A result is valid if all lanes have confidence at or above the
    /// specified threshold and contain no empty bead states.
    ///
    /// - Parameters:
    ///   - lanes: The lanes to validate.
    ///   - threshold: The minimum acceptable confidence score.
    /// - Returns: `true` if all lanes meet the quality criteria.
    public func validate(lanes: [SorobanLane], threshold: Float) -> Bool {
        lanes.allSatisfy { $0.confidence >= threshold && $0.digit.isValid }
    }
}
