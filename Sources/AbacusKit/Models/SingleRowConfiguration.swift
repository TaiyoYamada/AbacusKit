// AbacusKit - SingleRowConfiguration
// Swift 6.2

import CoreGraphics
import Foundation

/// Configuration for single-row soroban recognition.
///
/// Use this configuration with ``SingleRowRecognizer`` to recognize
/// a single row of soroban beads instead of the full frame.
///
/// ## Overview
///
/// Single-row recognition is designed for scenarios where:
/// - Only one row of beads is visible at a time
/// - The user aligns the soroban to a guide rectangle
/// - Frame detection is not needed or not possible
///
/// ## Example
///
/// ```swift
/// var config = SingleRowConfiguration()
/// config.startDigitPosition = 0  // Ones place
/// config.expectedLaneCount = 5   // Expect 5 digits
///
/// let recognizer = SingleRowRecognizer(configuration: config)
/// ```
public struct SingleRowConfiguration: Sendable, Equatable {
    // MARK: - Digit Position Settings

    /// The digit position of the first (leftmost) lane.
    ///
    /// This determines how the recognized value is calculated:
    /// - `0` = ones place (default)
    /// - `1` = tens place
    /// - `2` = hundreds place, etc.
    ///
    /// For example, if you recognize the row `[3, 2, 1]` with
    /// `startDigitPosition = 2`, the value would be 321.
    public var startDigitPosition: Int

    // MARK: - Lane Detection Settings

    /// The expected number of lanes, or nil for auto-detection.
    ///
    /// Set this if the lane count is known in advance. When set,
    /// the recognizer will divide the ROI into exactly this many
    /// equal-width lanes without auto-detection.
    ///
    /// Set to `nil` (default) to enable automatic lane count detection
    /// using edge detection and projection analysis.
    public var expectedLaneCount: Int?

    /// The minimum number of lanes to detect.
    ///
    /// Used when `expectedLaneCount` is nil. Recognition will fail
    /// if fewer lanes are detected.
    public var minLaneCount: Int

    /// The maximum number of lanes to detect.
    ///
    /// Used when `expectedLaneCount` is nil. If more lanes are
    /// detected, only the first `maxLaneCount` will be used.
    public var maxLaneCount: Int

    // MARK: - Guide Settings

    /// The target aspect ratio for the guide rectangle (width / height).
    ///
    /// This determines the shape of the recommended guide rectangle.
    /// A typical soroban row has an aspect ratio around 8:1.
    public var guideAspectRatio: CGFloat

    /// The guide rectangle inset ratio.
    ///
    /// The guide will be inset from the view edges by this fraction
    /// of the view width. Range: 0.0 to 0.4.
    public var guideInsetRatio: CGFloat

    // MARK: - Recognition Settings

    /// The minimum confidence threshold for valid results.
    ///
    /// Results with overall confidence below this threshold will
    /// throw an error.
    public var confidenceThreshold: Float

    /// Enables preprocessing (CLAHE, white balance) for the ROI.
    ///
    /// Enable for variable lighting conditions. Disable for
    /// consistent lighting or maximum performance.
    public var enablePreprocessing: Bool

    // MARK: - Presets

    /// Default configuration for single-row recognition.
    public static let `default` = SingleRowConfiguration(
        startDigitPosition: 0,
        expectedLaneCount: nil,
        minLaneCount: 1,
        maxLaneCount: 13,
        guideAspectRatio: 8.0,
        guideInsetRatio: 0.05,
        confidenceThreshold: 0.7,
        enablePreprocessing: true
    )

    /// Configuration for fixed lane count (no auto-detection).
    ///
    /// - Parameter laneCount: The exact number of lanes to expect.
    /// - Returns: A configuration with fixed lane count.
    public static func fixed(laneCount: Int) -> SingleRowConfiguration {
        var config = SingleRowConfiguration.default
        config.expectedLaneCount = laneCount
        return config
    }

    // MARK: - Initialization

    /// Creates a new single-row configuration.
    ///
    /// - Parameters:
    ///   - startDigitPosition: Position of the first digit (0 = ones).
    ///   - expectedLaneCount: Expected lane count, or nil for auto.
    ///   - minLaneCount: Minimum lanes for auto-detection.
    ///   - maxLaneCount: Maximum lanes for auto-detection.
    ///   - guideAspectRatio: Guide rectangle aspect ratio.
    ///   - guideInsetRatio: Guide inset from view edges.
    ///   - confidenceThreshold: Minimum confidence for valid results.
    ///   - enablePreprocessing: Enable image preprocessing.
    public init(
        startDigitPosition: Int = 0,
        expectedLaneCount: Int? = nil,
        minLaneCount: Int = 1,
        maxLaneCount: Int = 13,
        guideAspectRatio: CGFloat = 8.0,
        guideInsetRatio: CGFloat = 0.05,
        confidenceThreshold: Float = 0.7,
        enablePreprocessing: Bool = true
    ) {
        self.startDigitPosition = startDigitPosition
        self.expectedLaneCount = expectedLaneCount
        self.minLaneCount = minLaneCount
        self.maxLaneCount = maxLaneCount
        self.guideAspectRatio = guideAspectRatio
        self.guideInsetRatio = guideInsetRatio
        self.confidenceThreshold = confidenceThreshold
        self.enablePreprocessing = enablePreprocessing
    }
}
