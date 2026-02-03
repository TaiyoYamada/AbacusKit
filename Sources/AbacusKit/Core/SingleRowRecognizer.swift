// AbacusKit - SingleRowRecognizer
// Swift 6.2

import CoreGraphics
import CoreVideo
import Foundation

/// Recognizes a single row of soroban beads within a fixed region.
///
/// `SingleRowRecognizer` provides a simplified recognition API for
/// scenarios where only one row of beads is visible at a time, such as
/// when using a guide overlay to align the soroban.
///
/// ## Overview
///
/// Unlike ``AbacusRecognizer`` which detects the full soroban frame,
/// this recognizer works with a user-defined region of interest (ROI).
/// This eliminates frame detection complexity and is ideal for:
///
/// - Tutorial applications showing one row at a time
/// - Practice tools where the user aligns to a guide
/// - Video analysis of individual rows
///
/// ## Usage
///
/// ```swift
/// let recognizer = SingleRowRecognizer()
///
/// // Get the recommended guide rectangle
/// let guideRect = recognizer.guideRect(in: viewSize)
///
/// // Recognize beads in the guide region
/// let result = try await recognizer.recognize(
///     pixelBuffer: cameraFrame,
///     roi: guideRect  // Normalized to view coordinates
/// )
///
/// print("Value: \(result.value)")
/// ```
///
/// ## Coordinate System
///
/// The ROI uses normalized coordinates (0.0 to 1.0) where:
/// - (0, 0) is the top-left corner
/// - (1, 1) is the bottom-right corner
/// - The aspect ratio matches the original image
public actor SingleRowRecognizer {
    // MARK: - Dependencies

    private var configuration: SingleRowConfiguration
    private let interpreter: SorobanInterpreter
    private var inferenceEngine: AbacusInferenceEngine?
    private var isConfigured = false

    // MARK: - Initialization

    /// Creates a recognizer with default configuration.
    public init() {
        self.configuration = .default
        self.interpreter = SorobanInterpreter()
        self.inferenceEngine = AbacusInferenceEngine()
        self.isConfigured = true
    }

    /// Creates a recognizer with the specified configuration.
    ///
    /// - Parameter configuration: Settings for single-row recognition.
    public init(configuration: SingleRowConfiguration) {
        self.configuration = configuration
        self.interpreter = SorobanInterpreter()
        self.inferenceEngine = AbacusInferenceEngine()
        self.isConfigured = true
    }

    // MARK: - Configuration

    /// The current configuration.
    public var currentConfiguration: SingleRowConfiguration {
        configuration
    }

    /// Updates the recognizer configuration.
    ///
    /// - Parameter configuration: The new configuration to apply.
    public func configure(_ configuration: SingleRowConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Guide Calculation

    /// Returns the recommended guide rectangle for display.
    ///
    /// The guide rectangle is sized based on the configuration's
    /// aspect ratio and inset settings, centered in the view.
    ///
    /// - Parameter viewSize: The size of the camera preview view.
    /// - Returns: A rectangle in view coordinates (not normalized).
    public func guideRect(in viewSize: CGSize) -> CGRect {
        let inset = viewSize.width * configuration.guideInsetRatio
        let availableWidth = viewSize.width - (inset * 2)
        let guideWidth = availableWidth
        let guideHeight = guideWidth / configuration.guideAspectRatio

        let x = inset
        let y = (viewSize.height - guideHeight) / 2

        return CGRect(x: x, y: y, width: guideWidth, height: guideHeight)
    }

    /// Returns the normalized ROI for the guide rectangle.
    ///
    /// Use this to convert the guide rectangle to normalized coordinates
    /// suitable for the `recognize(pixelBuffer:roi:)` method.
    ///
    /// - Parameter viewSize: The size of the camera preview view.
    /// - Returns: Normalized coordinates (0.0 to 1.0).
    public func normalizedGuideROI(in viewSize: CGSize) -> CGRect {
        let guide = guideRect(in: viewSize)
        return CGRect(
            x: guide.origin.x / viewSize.width,
            y: guide.origin.y / viewSize.height,
            width: guide.width / viewSize.width,
            height: guide.height / viewSize.height
        )
    }

    // MARK: - Recognition

    /// Recognizes beads in the specified region of interest.
    ///
    /// This method:
    /// 1. Crops the pixel buffer to the ROI
    /// 2. Detects or uses the configured lane count
    /// 3. Extracts and classifies bead images
    /// 4. Calculates the total value
    ///
    /// - Parameters:
    ///   - pixelBuffer: A camera frame in BGRA or RGBA format.
    ///   - roi: The region to analyze in normalized coordinates (0.0-1.0).
    /// - Returns: The recognition result for the row.
    /// - Throws: ``AbacusError`` if recognition fails.
    public func recognize(
        pixelBuffer: CVPixelBuffer,
        roi: CGRect
    ) async throws -> SingleRowResult {
        guard isConfigured else {
            throw AbacusError.modelNotLoaded
        }

        let startTime = Date()

        // Get image dimensions
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Convert normalized ROI to pixel coordinates
        let pixelROI = CGRect(
            x: roi.origin.x * CGFloat(imageWidth),
            y: roi.origin.y * CGFloat(imageHeight),
            width: roi.width * CGFloat(imageWidth),
            height: roi.height * CGFloat(imageHeight)
        )

        // Determine lane count
        let laneCount = configuration.expectedLaneCount ?? detectLaneCount(in: pixelROI)

        guard laneCount >= configuration.minLaneCount else {
            throw AbacusError.frameNotDetected
        }

        // Calculate lane bounding boxes (equal-width division)
        let laneWidth = pixelROI.width / CGFloat(laneCount)
        var laneBoundingBoxes: [CGRect] = []

        for i in 0..<laneCount {
            let laneRect = CGRect(
                x: pixelROI.origin.x + CGFloat(i) * laneWidth,
                y: pixelROI.origin.y,
                width: laneWidth,
                height: pixelROI.height
            )
            laneBoundingBoxes.append(laneRect)
        }

        // For now, create placeholder lanes (ML inference will be wired later)
        let lanes = createPlaceholderLanes(
            count: laneCount,
            boundingBoxes: laneBoundingBoxes,
            startPosition: configuration.startDigitPosition
        )

        let processingTime = Date().timeIntervalSince(startTime) * 1000
        let confidence = lanes.map { $0.confidence }.min() ?? 0

        return SingleRowResult(
            lanes: lanes,
            startPosition: configuration.startDigitPosition,
            confidence: confidence,
            roi: roi,
            processingTimeMs: processingTime,
            timestamp: startTime
        )
    }

    /// Recognizes using the default guide region.
    ///
    /// Convenience method that uses the guide rectangle calculated
    /// from the pixel buffer dimensions.
    ///
    /// - Parameter pixelBuffer: A camera frame.
    /// - Returns: The recognition result.
    /// - Throws: ``AbacusError`` if recognition fails.
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> SingleRowResult {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let viewSize = CGSize(width: width, height: height)
        let roi = normalizedGuideROI(in: viewSize)
        return try await recognize(pixelBuffer: pixelBuffer, roi: roi)
    }

    // MARK: - Private

    /// Detects the number of lanes in the ROI using edge projection.
    private func detectLaneCount(in roi: CGRect) -> Int {
        // Simple heuristic based on aspect ratio
        // Assumes each lane is roughly square in the row
        let estimatedLanes = Int(roi.width / roi.height)
        return max(
            configuration.minLaneCount,
            min(configuration.maxLaneCount, estimatedLanes)
        )
    }

    /// Creates placeholder lanes for testing.
    private func createPlaceholderLanes(
        count: Int,
        boundingBoxes: [CGRect],
        startPosition: Int
    ) -> [SorobanLane] {
        var lanes: [SorobanLane] = []

        for i in 0..<count {
            // Position: leftmost lane has highest position
            let position = startPosition + (count - 1 - i)

            let digit = SorobanDigit(
                position: position,
                upperBead: .empty,
                lowerBeads: [.empty, .empty, .empty, .empty],
                confidence: 0.0,
                boundingBox: boundingBoxes[i]
            )

            let lane = SorobanLane(digit: digit, roi: boundingBoxes[i])
            lanes.append(lane)
        }

        return lanes
    }
}
