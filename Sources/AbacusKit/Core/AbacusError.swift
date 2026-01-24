// AbacusKit - AbacusError
// Swift 6.2

import Foundation

/// Errors that can occur during soroban recognition operations.
///
/// `AbacusError` provides detailed error information for all failure modes
/// in the recognition pipeline, from configuration issues to inference failures.
///
/// ## Error Categories
///
/// Errors are organized into categories based on the phase where they occur:
///
/// - **Configuration Errors**: Problems with SDK setup or model loading.
/// - **Input Errors**: Invalid or unsupported input data.
/// - **Detection Errors**: Failures during image processing or frame detection.
/// - **Inference Errors**: Neural network execution failures.
/// - **Result Errors**: Problems with recognition quality or validation.
/// - **System Errors**: Memory or internal failures.
///
/// ## Error Handling Example
///
/// ```swift
/// do {
///     let result = try await recognizer.recognize(pixelBuffer: frame)
/// } catch let error as AbacusError {
///     switch error {
///     case .frameNotDetected:
///         // Ask user to point camera at soroban
///         showGuidance("Point the camera at the soroban")
///
///     case .lowConfidence(let conf, let threshold):
///         // Recognition succeeded but confidence is low
///         showWarning("Recognition accuracy is low (\(conf) < \(threshold))")
///
///     case .modelNotLoaded:
///         // Attempt to reload the model
///         try await recognizer.configure(.default)
///
///     default:
///         print("Error: \(error.localizedDescription)")
///     }
/// }
/// ```
///
/// ## Retry Behavior
///
/// Use ``isRetryable`` to determine if an error may resolve with a new frame:
///
/// ```swift
/// if error.isRetryable {
///     // Wait for next frame and try again
/// } else {
///     // Show error to user
/// }
/// ```
public enum AbacusError: Error, Sendable {
    // MARK: - Configuration Errors

    /// The configuration contains invalid values.
    ///
    /// - Parameter reason: A description of what is invalid.
    case invalidConfiguration(reason: String)

    /// The specified model file could not be found.
    ///
    /// - Parameter path: The file path that was searched.
    case modelNotFound(path: String)

    /// The model file failed to load.
    ///
    /// - Parameter underlying: The underlying error from the model loader.
    case modelLoadFailed(underlying: Error)

    /// A recognition operation was attempted before loading a model.
    ///
    /// Call ``AbacusRecognizer/configure(_:)`` or initialize with
    /// a valid configuration before attempting recognition.
    case modelNotLoaded

    // MARK: - Input Errors

    /// The input data is invalid or corrupt.
    ///
    /// - Parameter reason: A description of what is wrong with the input.
    case invalidInput(reason: String)

    /// The input image uses an unsupported pixel format.
    ///
    /// Supported formats include BGRA, RGBA, and grayscale.
    ///
    /// - Parameter format: The unsupported format identifier.
    case unsupportedPixelFormat(format: String)

    // MARK: - Detection Errors

    /// No soroban frame was detected in the input image.
    ///
    /// This typically occurs when:
    /// - The soroban is not visible in the camera frame.
    /// - The soroban is too small relative to the image.
    /// - Lighting conditions prevent detection.
    ///
    /// This error is retryable; try again with a better camera angle.
    case frameNotDetected

    /// Lane extraction failed after frame detection.
    ///
    /// The soroban frame was detected, but individual lanes could not
    /// be segmented. This may indicate an unusual soroban design.
    ///
    /// - Parameter reason: Details about the extraction failure.
    case laneExtractionFailed(reason: String)

    /// Image preprocessing failed.
    ///
    /// An error occurred during OpenCV image processing operations.
    ///
    /// - Parameters:
    ///   - reason: A description of the failure.
    ///   - code: An internal error code for debugging.
    case preprocessingFailed(reason: String, code: Int)

    // MARK: - Inference Errors

    /// Neural network inference failed.
    ///
    /// - Parameter underlying: The underlying error from the inference engine.
    case inferenceFailed(underlying: Error)

    /// Tensor format conversion failed.
    ///
    /// An error occurred while converting image data to tensor format.
    ///
    /// - Parameter reason: Details about the conversion failure.
    case tensorConversionFailed(reason: String)

    // MARK: - Result Errors

    /// The recognition confidence is below the configured threshold.
    ///
    /// The recognition completed, but the confidence score indicates
    /// the result may be unreliable.
    ///
    /// - Parameters:
    ///   - confidence: The achieved confidence score (0.0-1.0).
    ///   - threshold: The configured minimum threshold.
    case lowConfidence(confidence: Float, threshold: Float)

    /// The recognition result is invalid or inconsistent.
    ///
    /// - Parameter reason: Details about why the result is invalid.
    case invalidResult(reason: String)

    // MARK: - System Errors

    /// The system ran out of memory during processing.
    ///
    /// This may occur when processing very high resolution images
    /// or when the device has limited available memory.
    case outOfMemory

    /// An internal error occurred.
    ///
    /// This indicates a bug in AbacusKit. Please report this error
    /// along with reproduction steps.
    ///
    /// - Parameter message: Internal debugging information.
    case internalError(message: String)
}

// MARK: - LocalizedError

extension AbacusError: LocalizedError {
    /// A localized description of the error.
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(reason):
            "Invalid configuration: \(reason)"

        case let .modelNotFound(path):
            "Model not found: \(path)"

        case let .modelLoadFailed(error):
            "Failed to load model: \(error.localizedDescription)"

        case .modelNotLoaded:
            "Model not loaded"

        case let .invalidInput(reason):
            "Invalid input: \(reason)"

        case let .unsupportedPixelFormat(format):
            "Unsupported pixel format: \(format)"

        case .frameNotDetected:
            "Soroban frame not detected"

        case let .laneExtractionFailed(reason):
            "Lane extraction failed: \(reason)"

        case let .preprocessingFailed(reason, code):
            "Preprocessing failed (\(code)): \(reason)"

        case let .inferenceFailed(error):
            "Inference failed: \(error.localizedDescription)"

        case let .tensorConversionFailed(reason):
            "Tensor conversion failed: \(reason)"

        case let .lowConfidence(confidence, threshold):
            "Confidence too low (\(String(format: "%.1f%%", confidence * 100)) < \(String(format: "%.1f%%", threshold * 100)))"

        case let .invalidResult(reason):
            "Invalid result: \(reason)"

        case .outOfMemory:
            "Out of memory"

        case let .internalError(message):
            "Internal error: \(message)"
        }
    }

    /// A suggestion for recovering from this error.
    public var recoverySuggestion: String? {
        switch self {
        case .frameNotDetected:
            "Ensure the soroban is visible in the camera frame"
        case .lowConfidence:
            "Improve lighting or move the camera closer"
        case .modelNotFound,
             .modelNotLoaded:
            "Reinstall the application"
        default:
            nil
        }
    }
}

// MARK: - Retry Support

extension AbacusError {
    /// Returns whether this error may resolve with a subsequent attempt.
    ///
    /// Retryable errors are typically transient conditions that may
    /// succeed with a new camera frame or improved conditions.
    ///
    /// - Returns: `true` if retrying may succeed; `false` if the error
    ///   requires user intervention or configuration changes.
    public var isRetryable: Bool {
        switch self {
        case .frameNotDetected,
             .lowConfidence,
             .laneExtractionFailed:
            true
        case .modelNotLoaded,
             .modelNotFound,
             .invalidConfiguration:
            false
        default:
            false
        }
    }
}
