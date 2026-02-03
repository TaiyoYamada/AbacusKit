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
    /// Each lane's value is multiplied by 10^position to correctly place
    /// the digit, regardless of whether positions are contiguous or in order.
    ///
    /// - Parameter lanes: An array of recognition lanes (any order).
    /// - Returns: The combined integer value, or 0 if overflow occurs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // For lanes representing digits at positions 0 and 2
    /// // position 0: value 3 (ones place)
    /// // position 2: value 5 (hundreds place)
    /// let value = interpreter.interpret(lanes: lanes)
    /// // Returns 503
    /// ```
    public func interpret(lanes: [SorobanLane]) -> Int {
        guard !lanes.isEmpty else {
            return 0
        }

        var value = 0

        for lane in lanes {
            // Calculate multiplier directly from position
            // This is robust against non-contiguous positions
            let multiplier = Self.powerOf10(lane.position)
            
            // Check for overflow during multiplication
            let (addValue, overflow1) = lane.value.multipliedReportingOverflow(by: multiplier)
            if overflow1 {
                return 0
            }
            
            // Check for overflow during addition
            let (newValue, overflow2) = value.addingReportingOverflow(addValue)
            if overflow2 {
                return 0
            }
            
            value = newValue
        }

        return value
    }
    
    /// Returns 10^exponent as Int, with overflow protection.
    ///
    /// - Parameter exponent: The power to raise 10 to (must be >= 0).
    /// - Returns: 10^exponent, or Int.max if overflow would occur.
    private static func powerOf10(_ exponent: Int) -> Int {
        guard exponent >= 0 else { return 1 }
        
        // Int.max on 64-bit is 9,223,372,036,854,775,807 (about 9.2e18)
        // 10^18 = 1,000,000,000,000,000,000 is the largest safe power
        guard exponent <= 18 else { return Int.max }
        
        var result = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
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
