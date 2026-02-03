// AbacusKit - SorobanResult
// Swift 6.2

import CoreGraphics
import Foundation

/// The complete result of a soroban recognition operation.
///
/// `SorobanResult` contains the recognized numeric value, detailed information
/// about each digit (lane), frame detection data, and performance metrics.
///
/// ## Overview
///
/// After successfully recognizing a soroban from a camera frame, you receive
/// a `SorobanResult` containing:
///
/// - The total numeric ``value`` displayed on the soroban
/// - An array of ``SorobanLane`` objects with per-digit details
/// - The detected frame location and corner coordinates
/// - A ``TimingBreakdown`` with performance metrics
///
/// ## Example
///
/// ```swift
/// let result = try await recognizer.recognize(pixelBuffer: frame)
///
/// print("Value: \(result.value)")
/// print("Digits: \(result.digitCount)")
/// print("Confidence: \(result.confidence)")
/// print("Processing time: \(result.timing.totalMs)ms")
///
/// // Access individual digits
/// for lane in result.lanes {
///     print("Position \(lane.position): \(lane.value)")
/// }
/// ```
///
/// ## Validation
///
/// Use ``isValid`` to check whether the recognition result meets quality
/// thresholds before displaying it to users:
///
/// ```swift
/// if result.isValid {
///     displayValue(result.value)
/// } else {
///     showRetryPrompt()
/// }
/// ```
public struct SorobanResult: Sendable, Equatable {
    // MARK: - Primary Results

    /// The recognized numeric value displayed on the soroban.
    ///
    /// This is the combined value of all detected digits, computed by
    /// interpreting each lane value according to its position (ones,
    /// tens, hundreds, etc.).
    public let value: Int

    /// Detailed information for each digit lane.
    ///
    /// The lanes are ordered from right to left (least significant to
    /// most significant digit). Use ``digitValues`` for a left-to-right
    /// array of individual digit values.
    public let lanes: [SorobanLane]

    /// The overall confidence score (0.0-1.0).
    ///
    /// This is the minimum confidence across all detected lanes.
    /// A higher value indicates more reliable recognition results.
    public let confidence: Float

    // MARK: - Frame Information

    /// The bounding rectangle of the detected soroban frame.
    ///
    /// This rectangle is in the coordinate space of the input image
    /// and can be used to draw an overlay around the detected soroban.
    public let frameRect: CGRect

    /// The four corner points of the detected soroban frame.
    ///
    /// Ordered as: top-left, top-right, bottom-right, bottom-left.
    /// These points are used for perspective transformation and
    /// can be displayed as a quadrilateral overlay.
    public let frameCorners: [CGPoint]

    /// The number of digit lanes detected.
    ///
    /// This equals `lanes.count` and represents the number of
    /// columns (digits) on the soroban.
    public let laneCount: Int

    // MARK: - Performance Information

    /// A breakdown of processing time by phase.
    ///
    /// Use this to identify performance bottlenecks or display
    /// processing statistics to developers.
    public let timing: TimingBreakdown

    /// The timestamp when recognition was performed.
    ///
    /// Useful for correlating recognition results with video frames
    /// or implementing temporal smoothing algorithms.
    public let timestamp: Date

    // MARK: - Initialization

    /// Creates a new soroban recognition result.
    ///
    /// - Parameters:
    ///   - value: The total recognized numeric value.
    ///   - lanes: Array of lane details (right to left order).
    ///   - confidence: Overall confidence score.
    ///   - frameRect: Bounding rectangle of the detected frame.
    ///   - frameCorners: Four corners of the detected frame.
    ///   - timing: Performance timing breakdown.
    ///   - timestamp: The time of recognition.
    public init(
        value: Int,
        lanes: [SorobanLane],
        confidence: Float,
        frameRect: CGRect,
        frameCorners: [CGPoint],
        timing: TimingBreakdown,
        timestamp: Date = Date()
    ) {
        self.value = value
        self.lanes = lanes
        self.confidence = confidence
        self.frameRect = frameRect
        self.frameCorners = frameCorners
        laneCount = lanes.count
        self.timing = timing
        self.timestamp = timestamp
    }

    // MARK: - Convenience Accessors

    /// The number of digits in the recognized value.
    ///
    /// Equivalent to ``laneCount`` and `lanes.count`.
    public var digitCount: Int {
        lanes.count
    }

    /// Returns whether this result meets minimum quality thresholds.
    ///
    /// A result is considered valid if:
    /// - The ``confidence`` is above 0.5
    /// - All lanes have valid bead states (no `.empty` states)
    ///
    /// Use this to filter out unreliable recognition results before
    /// displaying them to users.
    public var isValid: Bool {
        confidence > 0.5 && lanes.allSatisfy { $0.digit.isValid }
    }

    /// The total processing time in milliseconds.
    ///
    /// Convenience accessor that returns ``TimingBreakdown/totalMs``.
    public var totalProcessingTimeMs: Double {
        timing.totalMs
    }

    /// An array of individual digit values in reading order (left to right).
    ///
    /// For a soroban showing "1234", this returns `[1, 2, 3, 4]`.
    ///
    /// ```swift
    /// let result = // ... recognition result for "1234"
    /// print(result.digitValues)  // [1, 2, 3, 4]
    /// print(result.value)        // 1234
    /// ```
    public var digitValues: [Int] {
        lanes.sorted { $0.position > $1.position }.map { $0.value }
    }
}

// MARK: - TimingBreakdown

/// A breakdown of processing time across recognition phases.
///
/// Use this structure to analyze performance characteristics and
/// identify bottlenecks in the recognition pipeline.
///
/// ## Processing Phases
///
/// 1. **Preprocessing**: Image conversion and enhancement (OpenCV)
/// 2. **Detection**: Soroban frame detection and lane extraction
/// 3. **Inference**: Neural network classification (ExecuTorch)
/// 4. **Postprocessing**: Value calculation and result construction
///
/// ## Example
///
/// ```swift
/// let timing = result.timing
/// print("Total: \(timing.totalMs)ms")
/// print("FPS: \(timing.estimatedFPS)")
/// print("Inference: \(timing.inferenceMs)ms (\(timing.inferenceMs/timing.totalMs*100)%)")
/// ```
public struct TimingBreakdown: Sendable, Equatable {
    /// Time spent in image preprocessing (milliseconds).
    ///
    /// Includes color space conversion, resizing, and image
    /// enhancement operations performed by OpenCV.
    public let preprocessingMs: Double

    /// Time spent in frame and lane detection (milliseconds).
    ///
    /// Includes contour detection, perspective transformation,
    /// and lane segmentation.
    public let detectionMs: Double

    /// Time spent in neural network inference (milliseconds).
    ///
    /// The time taken by ExecuTorch to classify all bead states.
    /// This is typically the most compute-intensive phase.
    public let inferenceMs: Double

    /// Time spent in postprocessing (milliseconds).
    ///
    /// Includes value calculation, result validation, and
    /// data structure construction.
    public let postprocessingMs: Double

    /// The total processing time across all phases.
    ///
    /// Computed as the sum of all individual phase times.
    public var totalMs: Double {
        preprocessingMs + detectionMs + inferenceMs + postprocessingMs
    }

    /// The estimated frames per second based on total processing time.
    ///
    /// Calculated as `1000 / totalMs`. Returns 0 if `totalMs` is 0.
    public var estimatedFPS: Double {
        guard totalMs > 0 else {
            return 0
        }
        return 1000.0 / totalMs
    }

    /// Creates a new timing breakdown.
    ///
    /// - Parameters:
    ///   - preprocessingMs: Preprocessing time in milliseconds.
    ///   - detectionMs: Detection time in milliseconds.
    ///   - inferenceMs: Inference time in milliseconds.
    ///   - postprocessingMs: Postprocessing time in milliseconds.
    public init(
        preprocessingMs: Double = 0,
        detectionMs: Double = 0,
        inferenceMs: Double = 0,
        postprocessingMs: Double = 0
    ) {
        self.preprocessingMs = preprocessingMs
        self.detectionMs = detectionMs
        self.inferenceMs = inferenceMs
        self.postprocessingMs = postprocessingMs
    }
}

extension SorobanResult: CustomStringConvertible {
    /// A textual representation of this recognition result.
    public var description: String {
        """
        SorobanResult {
            value: \(value)
            lanes: \(laneCount) digits
            confidence: \(String(format: "%.1f%%", confidence * 100))
            processingTime: \(String(format: "%.1fms", timing.totalMs))
            fps: \(String(format: "%.1f", timing.estimatedFPS))
        }
        """
    }
}
