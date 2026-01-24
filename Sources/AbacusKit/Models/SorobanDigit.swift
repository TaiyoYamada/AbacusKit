// AbacusKit - SorobanDigit
// Swift 6.2

import CoreGraphics
import Foundation

/// Represents a single digit (column) on a soroban.
///
/// A soroban digit consists of one upper bead (worth 5 points when lowered)
/// and four lower beads (worth 1 point each when raised). The combination
/// of bead positions determines the digit value from 0 to 9.
///
/// ## Digit Calculation
///
/// The value of a digit is calculated as:
/// ```
/// value = (upperBead == .lower ? 5 : 0) + count(lowerBeads where state == .lower)
/// ```
///
/// ## Example Values
///
/// | Upper | Lower Beads | Value |
/// |-------|-------------|-------|
/// | ○ (up)| ○○○○       |   0   |
/// | ○ (up)| ●●●○       |   3   |
/// | ● (dn)| ○○○○       |   5   |
/// | ● (dn)| ●●●●       |   9   |
///
/// ## Usage
///
/// ```swift
/// let digit = SorobanDigit(
///     position: 0,
///     upperBead: .lower,      // 5 points
///     lowerBeads: [.lower, .lower, .upper, .upper],  // 2 points
///     confidence: 0.95,
///     boundingBox: CGRect(x: 100, y: 50, width: 30, height: 100)
/// )
/// print(digit.value)  // 7
/// ```
public struct SorobanDigit: Sendable, Equatable, Hashable {
    /// The position of this digit, counted from the right starting at 0.
    ///
    /// Position 0 represents the ones place, position 1 represents the tens place, etc.
    public let position: Int

    /// The state of the upper bead (worth 5 points when in `.lower` position).
    public let upperBead: CellState

    /// The states of the four lower beads, ordered from top to bottom.
    ///
    /// Each bead in `.lower` position contributes 1 point to the digit value.
    /// This array must always contain exactly 4 elements.
    public let lowerBeads: [CellState]

    /// The calculated numeric value of this digit (0-9).
    ///
    /// Computed from the upper and lower bead states according to
    /// standard soroban counting rules.
    public let value: Int

    /// The confidence score for this digit recognition (0.0-1.0).
    ///
    /// This represents the minimum confidence among all bead predictions
    /// for this digit. Higher values indicate more reliable recognition.
    public let confidence: Float

    /// The bounding box of this digit in the original image coordinates.
    public let boundingBox: CGRect

    /// The raw probability distributions for each bead prediction.
    ///
    /// Each inner array contains probabilities for [upper, lower, empty] classes.
    /// The first element corresponds to the upper bead, followed by the four
    /// lower beads in order from top to bottom.
    public let probabilities: [[Float]]

    /// Creates a new soroban digit with the specified bead states.
    ///
    /// - Parameters:
    ///   - position: The position of this digit (0 = rightmost).
    ///   - upperBead: The state of the upper bead.
    ///   - lowerBeads: The states of the four lower beads (must be exactly 4).
    ///   - confidence: The recognition confidence score.
    ///   - boundingBox: The bounding box in image coordinates.
    ///   - probabilities: Optional raw prediction probabilities.
    ///
    /// - Precondition: `lowerBeads` must contain exactly 4 elements.
    public init(
        position: Int,
        upperBead: CellState,
        lowerBeads: [CellState],
        confidence: Float,
        boundingBox: CGRect,
        probabilities: [[Float]] = []
    ) {
        precondition(lowerBeads.count == 4, "Lower beads must be exactly 4")

        self.position = position
        self.upperBead = upperBead
        self.lowerBeads = lowerBeads
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.probabilities = probabilities

        // Calculate the digit value
        value = Self.calculateValue(upperBead: upperBead, lowerBeads: lowerBeads)
    }

    /// Calculates the numeric value from bead states.
    ///
    /// - Parameters:
    ///   - upperBead: The state of the upper bead.
    ///   - lowerBeads: The states of the four lower beads.
    /// - Returns: The calculated digit value (0-9).
    private static func calculateValue(upperBead: CellState, lowerBeads: [CellState]) -> Int {
        var value = 0

        // Upper bead: lower position = 5 points
        if upperBead == .lower {
            value += 5
        }

        // Lower beads: lower position = 1 point each
        for bead in lowerBeads {
            if bead == .lower {
                value += 1
            }
        }

        return min(9, value) // Maximum value is 9
    }

    /// Returns whether all beads in this digit have valid states.
    ///
    /// A digit is valid if neither the upper bead nor any lower bead
    /// has an `.empty` state.
    public var isValid: Bool {
        upperBead.isValid && lowerBeads.allSatisfy { $0.isValid }
    }
}

extension SorobanDigit: CustomStringConvertible {
    /// A textual representation of this digit showing bead positions.
    ///
    /// Uses `●` for beads in `.lower` position and `○` for beads in `.upper` position.
    public var description: String {
        let upper = upperBead == .lower ? "●" : "○"
        let lower = lowerBeads.map { $0 == .lower ? "●" : "○" }.joined()
        return "[\(position)]: \(upper)|\(lower) = \(value)"
    }
}
