// AbacusKit - AbacusRecognizer
// Swift 6.2

import CoreGraphics
import CoreVideo
import Foundation

/// The main entry point for soroban recognition.
///
/// `AbacusRecognizer` provides a high-level API for recognizing soroban
/// (Japanese abacus) values from camera frames. It orchestrates the entire
/// recognition pipeline including image preprocessing, neural network
/// inference, and value interpretation.
///
/// ## Overview
///
/// Create an `AbacusRecognizer` instance and call ``recognize(pixelBuffer:)``
/// with camera frames to get recognition results:
///
/// ```swift
/// let recognizer = AbacusRecognizer()
///
/// // In your camera delegate
/// func captureOutput(_ output: AVCaptureOutput,
///                    didOutput sampleBuffer: CMSampleBuffer,
///                    from connection: AVCaptureConnection) {
///     guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
///         return
///     }
///
///     Task {
///         do {
///             let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
///             await MainActor.run {
///                 displayValue(result.value)
///             }
///         } catch AbacusError.frameNotDetected {
///             // Soroban not visible - wait for next frame
///         } catch {
///             print("Recognition error: \(error)")
///         }
///     }
/// }
/// ```
///
/// ## Configuration
///
/// Customize recognition behavior using ``AbacusConfiguration``:
///
/// ```swift
/// // Use a preset
/// let recognizer = AbacusRecognizer(configuration: .highAccuracy)
///
/// // Or customize settings
/// var config = AbacusConfiguration.default
/// config.confidenceThreshold = 0.9
/// let customRecognizer = AbacusRecognizer(configuration: config)
/// ```
///
/// ## Thread Safety
///
/// `AbacusRecognizer` is implemented as an actor, making it safe to call
/// from any thread or task. All methods are `async` and can be called
/// concurrently without explicit synchronization.
///
/// ## Topics
///
/// ### Creating a Recognizer
/// - ``init()``
/// - ``init(configuration:)``
///
/// ### Recognition
/// - ``recognize(pixelBuffer:)``
/// - ``recognizeStabilized(pixelBuffer:consecutiveCount:)``
///
/// ### Configuration
/// - ``configure(_:)``
/// - ``currentConfiguration``
public actor AbacusRecognizer {
    // MARK: - Dependencies

    private var configuration: AbacusConfiguration
    private let interpreter: SorobanInterpreter
    private var inferenceEngine: AbacusInferenceEngine?
    private var visionProcessor: VisionProcessor?

    // MARK: - State

    private var isConfigured = false
    private var frameCount = 0

    // MARK: - Initialization

    /// Creates a recognizer with default configuration.
    ///
    /// Uses ``AbacusConfiguration/default`` which provides balanced
    /// performance and accuracy suitable for most applications.
    public init() {
        configuration = .default
        interpreter = SorobanInterpreter()
        visionProcessor = VisionProcessor(configuration: .default)
        inferenceEngine = AbacusInferenceEngine()
        isConfigured = true
    }

    /// Creates a recognizer with custom configuration.
    ///
    /// - Parameter configuration: The configuration to use for recognition.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let recognizer = AbacusRecognizer(configuration: .highAccuracy)
    /// ```
    public init(configuration: AbacusConfiguration) {
        self.configuration = configuration
        interpreter = SorobanInterpreter()
        visionProcessor = VisionProcessor(configuration: configuration)
        inferenceEngine = AbacusInferenceEngine()
        isConfigured = true
    }

    // MARK: - Configuration

    /// Updates the recognizer configuration.
    ///
    /// Use this method to change recognition parameters at runtime.
    /// If the configuration includes a custom model path, the model
    /// will be loaded.
    ///
    /// - Parameter config: The new configuration to apply.
    /// - Throws: ``AbacusError`` if model loading fails.
    public func configure(_ config: AbacusConfiguration) async throws {
        configuration = config
        visionProcessor?.updateConfiguration(config)

        if let modelPath = config.modelPath {
            try await inferenceEngine?.loadModel(at: modelPath)
        }
    }

    /// The current configuration in use.
    public var currentConfiguration: AbacusConfiguration {
        configuration
    }

    // MARK: - Recognition

    /// Recognizes the soroban value from a camera frame.
    ///
    /// This method performs the complete recognition pipeline:
    /// 1. **Preprocessing**: Converts and enhances the input image.
    /// 2. **Detection**: Finds the soroban frame and extracts lanes.
    /// 3. **Inference**: Classifies each bead state using neural networks.
    /// 4. **Interpretation**: Calculates digit values and combines them.
    ///
    /// - Parameter pixelBuffer: A camera frame in BGRA or RGBA format.
    /// - Returns: A ``SorobanResult`` containing the recognized value and details.
    /// - Throws: ``AbacusError`` if any stage of recognition fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let result = try await recognizer.recognize(pixelBuffer: frame)
    ///     print("Value: \(result.value)")
    ///     print("Confidence: \(result.confidence)")
    ///     print("Processing time: \(result.timing.totalMs)ms")
    /// } catch AbacusError.frameNotDetected {
    ///     print("No soroban detected")
    /// } catch AbacusError.lowConfidence(let conf, _) {
    ///     print("Low confidence: \(conf)")
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// On iPhone 15 Pro with default configuration:
    /// - Processing time: 16-25ms per frame
    /// - Achievable FPS: 40-60
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> SorobanResult {
        guard isConfigured else {
            throw AbacusError.modelNotLoaded
        }

        frameCount += 1
        if configuration.frameSkipInterval > 1, frameCount % configuration.frameSkipInterval != 0 {
            throw AbacusError.frameNotDetected
        }

        let startTime = Date()

        // 1. Preprocessing
        let preprocessingStart = Date()
        guard let visionResult = try visionProcessor?.process(pixelBuffer: pixelBuffer) else {
            throw AbacusError.preprocessingFailed(reason: "Vision processor not initialized", code: -1)
        }
        let preprocessingTime = Date().timeIntervalSince(preprocessingStart) * 1000

        guard visionResult.frameDetected else {
            throw AbacusError.frameNotDetected
        }

        // 2. Inference
        let inferenceStart = Date()
        guard let engine = inferenceEngine else {
            throw AbacusError.modelNotLoaded
        }

        let predictions = try await engine.predictBatch(
            tensorData: visionResult.tensorData,
            cellCount: visionResult.cellCount
        )
        let inferenceTime = Date().timeIntervalSince(inferenceStart) * 1000

        // 3. Interpretation
        let postprocessingStart = Date()
        let lanes = interpreter.buildLanes(
            from: predictions,
            laneCount: visionResult.laneCount,
            boundingBoxes: visionResult.laneBoundingBoxes
        )

        let value = interpreter.interpret(lanes: lanes)
        let overallConfidence = lanes.map { $0.confidence }.min() ?? 0
        let postprocessingTime = Date().timeIntervalSince(postprocessingStart) * 1000

        if overallConfidence < configuration.confidenceThreshold {
            throw AbacusError.lowConfidence(
                confidence: overallConfidence,
                threshold: configuration.confidenceThreshold
            )
        }

        // 4. Build result
        let timing = TimingBreakdown(
            preprocessingMs: preprocessingTime,
            detectionMs: visionResult.detectionTimeMs,
            inferenceMs: inferenceTime,
            postprocessingMs: postprocessingTime
        )

        let result = SorobanResult(
            value: value,
            lanes: lanes,
            confidence: overallConfidence,
            frameRect: visionResult.frameRect,
            frameCorners: visionResult.frameCorners,
            timing: timing,
            timestamp: startTime
        )

        if configuration.enablePerformanceLogging {
            logPerformance(timing: timing)
        }

        return result
    }

    /// Recognizes with temporal stabilization.
    ///
    /// This method requires consistent recognition results across multiple
    /// consecutive frames before returning a result. This reduces false
    /// positives caused by motion blur or temporary occlusions.
    ///
    /// - Parameters:
    ///   - pixelBuffer: A camera frame to process.
    ///   - consecutiveCount: Number of consistent results required (default: 3).
    /// - Returns: A stabilized result, or `nil` if not yet stable.
    /// - Throws: ``AbacusError`` if recognition fails.
    ///
    /// - Note: This is a simplified implementation that currently does not
    ///   implement full temporal stabilization.
    public func recognizeStabilized(
        pixelBuffer: CVPixelBuffer,
        consecutiveCount _: Int = 3
    ) async throws -> SorobanResult? {
        // TODO: Implement temporal stabilization logic
        try await recognize(pixelBuffer: pixelBuffer)
    }

    // MARK: - Private

    private func logPerformance(timing: TimingBreakdown) {
        print("""
        [AbacusKit] Performance:
          Preprocessing: \(String(format: "%.1f", timing.preprocessingMs))ms
          Detection: \(String(format: "%.1f", timing.detectionMs))ms
          Inference: \(String(format: "%.1f", timing.inferenceMs))ms
          Postprocessing: \(String(format: "%.1f", timing.postprocessingMs))ms
          Total: \(String(format: "%.1f", timing.totalMs))ms
          FPS: \(String(format: "%.1f", timing.estimatedFPS))
        """)
    }
}

// MARK: - VisionProcessor

/// Internal wrapper for the AbacusVision C++ module.
///
/// Handles conversion between Swift types and the C bridge layer.
final class VisionProcessor: @unchecked Sendable {
    private var configuration: AbacusConfiguration
    private let bridge: VisionBridge

    /// Internal result structure matching VisionExtractionResult.
    struct VisionResult: Sendable {
        let frameDetected: Bool
        let frameRect: CGRect
        let frameCorners: [CGPoint]
        let laneCount: Int
        let laneBoundingBoxes: [CGRect]
        let tensorData: [Float]
        let cellCount: Int
        let detectionTimeMs: Double
    }

    init(configuration: AbacusConfiguration) {
        self.configuration = configuration
        bridge = VisionBridge()
    }

    func updateConfiguration(_ config: AbacusConfiguration) {
        configuration = config
    }

    func process(pixelBuffer: CVPixelBuffer) throws -> VisionResult {
        guard bridge.isValid else {
            throw AbacusError.preprocessingFailed(reason: "VisionBridge not initialized", code: -1)
        }

        let result = try bridge.process(pixelBuffer: pixelBuffer)

        return VisionResult(
            frameDetected: result.frameDetected,
            frameRect: result.frameRect,
            frameCorners: result.frameCorners,
            laneCount: result.laneCount,
            laneBoundingBoxes: result.laneBoundingBoxes,
            tensorData: result.tensorData,
            cellCount: result.cellCount,
            detectionTimeMs: result.detectionTimeMs
        )
    }
}
