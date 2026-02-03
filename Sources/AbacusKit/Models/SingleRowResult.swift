// AbacusKit - SingleRowResult
// Swift 6.2

import CoreGraphics
import Foundation

/// The result of single-row soroban recognition.
///
/// Contains the recognized lanes, calculated value, and metadata
/// from processing a single row of soroban beads.
///
/// ## Overview
///
/// Unlike ``SorobanResult`` which represents the full soroban frame,
/// `SingleRowResult` represents just one row of beads. The digit
/// positions are offset by ``startPosition`` to calculate the
/// correct total value.
///
/// ## Example
///
/// ```swift
/// let result = try await recognizer.recognize(pixelBuffer: frame, roi: guideRect)
/// print("Recognized \(result.laneCount) lanes")
/// print("Value: \(result.value)")  // e.g., 321 if lanes are [3,2,1] at position 0
/// ```
public struct SingleRowResult: Sendable, Equatable {
    // MARK: - Properties

    /// The recognized lanes in left-to-right order.
    ///
    /// Each lane represents one digit column. The lanes are ordered
    /// from the highest position (leftmost) to the lowest position
    /// (rightmost) in the row.
    public let lanes: [SorobanLane]

    /// The starting digit position for value calculation.
    ///
    /// This is the position of the rightmost lane:
    /// - `0` = ones place
    /// - `1` = tens place
    /// - `2` = hundreds place, etc.
    ///
    /// For example, if `startPosition` is 2 and the lanes represent
    /// `[3, 2, 1]`, the calculated value is 321 (not 321000).
    public let startPosition: Int

    /// The overall confidence score (0.0 to 1.0).
    ///
    /// This is the minimum confidence across all lanes. Higher values
    /// indicate more reliable recognition.
    public let confidence: Float

    /// The region of interest used for recognition.
    ///
    /// In normalized coordinates (0.0 to 1.0) relative to the
    /// original image dimensions.
    public let roi: CGRect

    /// The processing time in milliseconds.
    public let processingTimeMs: Double

    /// The timestamp when recognition was performed.
    public let timestamp: Date

    // MARK: - Computed Properties

    /// The number of lanes detected in this row.
    public var laneCount: Int {
        lanes.count
    }

    /// The numeric value represented by this row.
    ///
    /// Calculated by summing each lane's value multiplied by its
    /// position (10^position), starting from ``startPosition``.
    ///
    /// Returns 0 if there are no lanes or if overflow would occur.
    public var value: Int {
        guard !lanes.isEmpty else { return 0 }

        var total = 0
        for (index, lane) in lanes.reversed().enumerated() {
            let position = startPosition + index
            let multiplier = Self.powerOf10(position)

            let (product, overflow1) = lane.value.multipliedReportingOverflow(by: multiplier)
            if overflow1 { return 0 }

            let (newTotal, overflow2) = total.addingReportingOverflow(product)
            if overflow2 { return 0 }

            total = newTotal
        }
        return total
    }

    /// Individual digit values in left-to-right order.
    ///
    /// Use this for display purposes when you want to show each
    /// digit separately.
    public var digitValues: [Int] {
        lanes.map { $0.value }
    }

    /// Whether all lanes have valid (non-empty) bead states.
    public var isValid: Bool {
        lanes.allSatisfy { $0.digit.isValid }
    }

    // MARK: - Initialization

    /// Creates a new single-row result.
    ///
    /// - Parameters:
    ///   - lanes: The recognized lanes.
    ///   - startPosition: The digit position of the rightmost lane.
    ///   - confidence: The overall confidence score.
    ///   - roi: The region of interest used.
    ///   - processingTimeMs: The processing time.
    ///   - timestamp: When recognition was performed.
    public init(
        lanes: [SorobanLane],
        startPosition: Int,
        confidence: Float,
        roi: CGRect,
        processingTimeMs: Double = 0,
        timestamp: Date = Date()
    ) {
        self.lanes = lanes
        self.startPosition = startPosition
        self.confidence = confidence
        self.roi = roi
        self.processingTimeMs = processingTimeMs
        self.timestamp = timestamp
    }

    // MARK: - Private

    private static func powerOf10(_ exponent: Int) -> Int {
        guard exponent >= 0, exponent <= 18 else {
            return exponent < 0 ? 1 : Int.max
        }
        var result = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension SingleRowResult: CustomStringConvertible {
    public var description: String {
        let digits = digitValues.map(String.init).joined()
        return "SingleRowResult(value: \(value), digits: \(digits), confidence: \(String(format: "%.2f", confidence)))"
    }
}
