// AbacusKit - AbacusConfiguration
// Swift 6.2

import Foundation

/// Configuration options for the AbacusKit recognition engine.
///
/// Use `AbacusConfiguration` to customize recognition behavior, performance
/// characteristics, and preprocessing options. The SDK provides several
/// preset configurations suitable for common use cases.
///
/// ## Presets
///
/// AbacusKit includes three built-in presets:
///
/// - ``default``: Balanced performance and accuracy for most applications.
/// - ``highAccuracy``: Maximum accuracy with higher processing time.
/// - ``fast``: Optimized for speed with reduced accuracy.
///
/// ## Example
///
/// ```swift
/// // Use a preset
/// let recognizer = AbacusRecognizer(configuration: .highAccuracy)
///
/// // Or customize specific settings
/// var config = AbacusConfiguration.default
/// config.confidenceThreshold = 0.9
/// config.enablePerformanceLogging = true
/// let customRecognizer = AbacusRecognizer(configuration: config)
/// ```
///
/// ## Performance Tuning
///
/// For real-time applications, consider adjusting:
///
/// - ``frameSkipInterval``: Process every Nth frame to reduce CPU usage.
/// - ``maxInputResolution``: Lower values reduce processing time.
/// - ``batchSize``: Affects GPU utilization during inference.
public struct AbacusConfiguration: Sendable, Equatable {
    // MARK: - Model Settings

    /// The path to a custom model file.
    ///
    /// Set this to use a custom-trained `.pte` model file instead of
    /// the bundled model. Set to `nil` to use the default bundled model.
    public var modelPath: URL?

    /// The inference backend to use for neural network execution.
    ///
    /// Different backends offer various tradeoffs between speed and
    /// power consumption. See ``InferenceBackend`` for options.
    public var inferenceBackend: InferenceBackend

    // MARK: - Recognition Settings

    /// The minimum number of digit lanes to detect.
    ///
    /// Sorobans with fewer lanes than this value will not be recognized.
    /// Set to 1 to accept any soroban.
    public var minLaneCount: Int

    /// The maximum number of digit lanes to detect.
    ///
    /// Sorobans with more lanes than this value will not be recognized.
    /// Standard sorobans have up to 27 lanes.
    public var maxLaneCount: Int

    /// The minimum confidence threshold for valid recognition results.
    ///
    /// Results with confidence below this threshold will throw
    /// ``AbacusError/lowConfidence(confidence:threshold:)``.
    /// Range: 0.0 to 1.0.
    public var confidenceThreshold: Float

    /// The minimum size ratio of the soroban frame relative to the image.
    ///
    /// Frames smaller than this ratio (frame_area / image_area) will be
    /// ignored. Increase this value to prevent false positives from
    /// small objects in the scene.
    public var minFrameSizeRatio: Float

    // MARK: - Performance Settings

    /// The interval at which to process frames.
    ///
    /// Set to 1 to process every frame. Set to 2 to process every
    /// other frame, etc. Higher values reduce CPU usage but may
    /// increase latency in detecting changes.
    public var frameSkipInterval: Int

    /// The maximum input resolution (longest edge in pixels).
    ///
    /// Input images larger than this resolution will be downscaled
    /// before processing. Lower values improve performance but may
    /// reduce accuracy for small beads.
    public var maxInputResolution: Int

    /// The batch size for neural network inference.
    ///
    /// Larger batch sizes can improve GPU utilization but use more
    /// memory. The optimal value depends on the device's GPU capabilities.
    public var batchSize: Int

    // MARK: - Preprocessing Settings

    /// Enables Contrast Limited Adaptive Histogram Equalization (CLAHE).
    ///
    /// CLAHE improves recognition in low-contrast lighting conditions
    /// but adds processing overhead. Recommended for variable lighting.
    public var enableCLAHE: Bool

    /// Enables automatic white balance correction.
    ///
    /// White balance correction normalizes color temperature, improving
    /// recognition under artificial lighting. Recommended for indoor use.
    public var enableWhiteBalance: Bool

    /// Enables noise reduction filtering.
    ///
    /// Noise reduction improves recognition of low-quality camera feeds
    /// but adds processing time. Disable for high-quality cameras.
    public var enableNoiseReduction: Bool

    // MARK: - Debug Settings

    /// Enables the debug overlay showing detection regions.
    ///
    /// When enabled, recognition results include visualization data
    /// for drawing debug overlays on the camera preview.
    public var enableDebugOverlay: Bool

    /// Enables performance logging to the console.
    ///
    /// When enabled, timing information is printed after each
    /// recognition operation. Useful during development.
    public var enablePerformanceLogging: Bool

    // MARK: - Presets

    /// The default configuration with balanced performance and accuracy.
    ///
    /// Suitable for most applications. Processes every frame at up to
    /// 1280px resolution with all preprocessing enabled.
    public static let `default` = AbacusConfiguration(
        modelPath: nil,
        inferenceBackend: .auto,
        minLaneCount: 1,
        maxLaneCount: 27,
        confidenceThreshold: 0.7,
        minFrameSizeRatio: 0.1,
        frameSkipInterval: 1,
        maxInputResolution: 1280,
        batchSize: 8,
        enableCLAHE: true,
        enableWhiteBalance: true,
        enableNoiseReduction: true,
        enableDebugOverlay: false,
        enablePerformanceLogging: false
    )

    /// High-accuracy configuration optimized for precision.
    ///
    /// Uses higher resolution, stricter confidence thresholds, and
    /// smaller batch sizes for maximum accuracy. Recommended when
    /// recognition accuracy is more important than speed.
    public static let highAccuracy = AbacusConfiguration(
        modelPath: nil,
        inferenceBackend: .coreml,
        minLaneCount: 1,
        maxLaneCount: 27,
        confidenceThreshold: 0.9,
        minFrameSizeRatio: 0.15,
        frameSkipInterval: 1,
        maxInputResolution: 1920,
        batchSize: 4,
        enableCLAHE: true,
        enableWhiteBalance: true,
        enableNoiseReduction: true,
        enableDebugOverlay: false,
        enablePerformanceLogging: false
    )

    /// Fast configuration optimized for speed.
    ///
    /// Uses lower resolution, relaxed confidence thresholds, and
    /// skips preprocessing for maximum performance. Use when
    /// processing speed is critical and lighting conditions are good.
    public static let fast = AbacusConfiguration(
        modelPath: nil,
        inferenceBackend: .coreml,
        minLaneCount: 1,
        maxLaneCount: 27,
        confidenceThreshold: 0.5,
        minFrameSizeRatio: 0.1,
        frameSkipInterval: 2,
        maxInputResolution: 720,
        batchSize: 16,
        enableCLAHE: false,
        enableWhiteBalance: false,
        enableNoiseReduction: false,
        enableDebugOverlay: false,
        enablePerformanceLogging: false
    )

    // MARK: - Initialization

    /// Creates a new configuration with the specified options.
    ///
    /// - Parameters:
    ///   - modelPath: Path to a custom model file, or `nil` for the default model.
    ///   - inferenceBackend: The backend to use for neural network inference.
    ///   - minLaneCount: Minimum number of lanes to detect.
    ///   - maxLaneCount: Maximum number of lanes to detect.
    ///   - confidenceThreshold: Minimum confidence for valid results.
    ///   - minFrameSizeRatio: Minimum frame size relative to image.
    ///   - frameSkipInterval: Process every Nth frame.
    ///   - maxInputResolution: Maximum input image resolution.
    ///   - batchSize: Batch size for inference.
    ///   - enableCLAHE: Enable contrast enhancement.
    ///   - enableWhiteBalance: Enable white balance correction.
    ///   - enableNoiseReduction: Enable noise filtering.
    ///   - enableDebugOverlay: Enable debug visualization.
    ///   - enablePerformanceLogging: Enable timing logs.
    public init(
        modelPath: URL? = nil,
        inferenceBackend: InferenceBackend = .auto,
        minLaneCount: Int = 1,
        maxLaneCount: Int = 27,
        confidenceThreshold: Float = 0.7,
        minFrameSizeRatio: Float = 0.1,
        frameSkipInterval: Int = 1,
        maxInputResolution: Int = 1280,
        batchSize: Int = 8,
        enableCLAHE: Bool = true,
        enableWhiteBalance: Bool = true,
        enableNoiseReduction: Bool = true,
        enableDebugOverlay: Bool = false,
        enablePerformanceLogging: Bool = false
    ) {
        self.modelPath = modelPath
        self.inferenceBackend = inferenceBackend
        self.minLaneCount = minLaneCount
        self.maxLaneCount = maxLaneCount
        self.confidenceThreshold = confidenceThreshold
        self.minFrameSizeRatio = minFrameSizeRatio
        self.frameSkipInterval = frameSkipInterval
        self.maxInputResolution = maxInputResolution
        self.batchSize = batchSize
        self.enableCLAHE = enableCLAHE
        self.enableWhiteBalance = enableWhiteBalance
        self.enableNoiseReduction = enableNoiseReduction
        self.enableDebugOverlay = enableDebugOverlay
        self.enablePerformanceLogging = enablePerformanceLogging
    }
}

// MARK: - InferenceBackend

/// The hardware backend used for neural network inference.
///
/// Different backends offer various tradeoffs between performance,
/// power consumption, and availability. Use ``auto`` to let the
/// system choose the optimal backend for the current device.
///
/// ## Backend Comparison
///
/// | Backend | Processor | Best For |
/// |---------|-----------|----------|
/// | `.coreml` | Neural Engine | Battery life, consistent performance |
/// | `.mps` | GPU | Maximum throughput |
/// | `.xnnpack` | CPU | Compatibility |
/// | `.auto` | Varies | General use |
public enum InferenceBackend: String, Sendable, Codable, CaseIterable {
    /// Uses Core ML with the Apple Neural Engine.
    ///
    /// Provides excellent performance with low power consumption.
    /// Recommended for most iOS applications.
    case coreml

    /// Uses Metal Performance Shaders on the GPU.
    ///
    /// Provides high throughput for batch processing. May use more
    /// power than Core ML but offers lower latency for some models.
    case mps

    /// Uses XNNPACK for CPU-based inference.
    ///
    /// A fallback option that works on all devices but may be slower
    /// than hardware-accelerated backends.
    case xnnpack

    /// Automatically selects the best available backend.
    ///
    /// Chooses based on device capabilities and current system state.
    /// This is the recommended option for most applications.
    case auto

    /// A human-readable description of this backend.
    public var localizedDescription: String {
        switch self {
        case .coreml: "Core ML (Neural Engine)"
        case .mps: "Metal Performance Shaders (GPU)"
        case .xnnpack: "XNNPACK (CPU)"
        case .auto: "Automatic Selection"
        }
    }
}
