// AbacusKit - AbacusInferenceEngine
// Swift 6.2

import Foundation

/// Neural network inference engine for bead state classification.
///
/// `AbacusInferenceEngine` executes machine learning models to classify
/// the state of individual soroban beads. It uses ExecuTorch for
/// high-performance on-device inference.
///
/// ## Overview
///
/// The inference engine performs the following tasks:
///
/// 1. **Model Loading**: Loads `.pte` (PyTorch Executable) model files
/// 2. **Tensor Preparation**: Accepts preprocessed image tensors
/// 3. **Batch Inference**: Classifies multiple beads efficiently
/// 4. **Result Parsing**: Converts logits to class predictions
///
/// ## Model Format
///
/// The engine expects models exported using ExecuTorch in `.pte` format.
/// Models should accept input tensors of shape `[N, 3, 224, 224]` and
/// output logits of shape `[N, 3]` for the three classes:
/// - Class 0: Upper position
/// - Class 1: Lower position
/// - Class 2: Empty/unclear
///
/// ## Usage
///
/// The engine is typically used internally by ``AbacusRecognizer``, but
/// can be used directly for custom pipelines:
///
/// ```swift
/// let engine = AbacusInferenceEngine(batchSize: 8)
/// try await engine.loadBundledModel()
///
/// let predictions = try await engine.predictBatch(
///     tensorData: preprocessedData,
///     cellCount: 25  // 5 lanes × 5 beads
/// )
/// ```
///
/// ## Thread Safety
///
/// This is an actor, ensuring thread-safe access to the model and
/// inference state. All methods can be called from any task.
public actor AbacusInferenceEngine {
    // MARK: - Properties

    private var modelLoaded = false
    private var modelPath: URL?
    private let batchSize: Int

    /// Cell image dimensions (CHW format).
    private let cellChannels = 3
    private let cellHeight = 224
    private let cellWidth = 224

    /// Handle to the loaded model (type-erased for ExecuTorch).
    private var moduleHandle: Any?

    // MARK: - Initialization

    /// Creates an inference engine with the specified batch size.
    ///
    /// - Parameter batchSize: The number of cells to process in each batch.
    ///   Larger values may improve GPU utilization but use more memory.
    ///   Default is 8.
    public init(batchSize: Int = 8) {
        self.batchSize = batchSize
    }

    // MARK: - Model Management

    /// Loads a model from the specified file path.
    ///
    /// - Parameter path: URL to a `.pte` model file.
    /// - Throws: ``AbacusError/modelNotFound(path:)`` if the file doesn't exist.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let modelURL = Bundle.main.url(forResource: "custom", withExtension: "pte")!
    /// try await engine.loadModel(at: modelURL)
    /// ```
    public func loadModel(at path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AbacusError.modelNotFound(path: path.path)
        }

        // ExecuTorch model loading placeholder
        // In production, this would initialize the ExecuTorch module
        modelPath = path
        modelLoaded = true
    }

    /// Loads the default model bundled with the framework.
    ///
    /// Searches for `abacus.pte` in the following locations:
    /// 1. The main application bundle
    /// 2. The AbacusKit framework bundle
    /// 3. The package's Model directory
    ///
    /// - Throws: ``AbacusError/modelNotFound(path:)`` if no model is found.
    public func loadBundledModel() throws {
        // Search in multiple bundle locations
        let candidates = [
            Bundle.main.url(forResource: "abacus", withExtension: "pte"),
            Bundle(for: BundleToken.self).url(forResource: "abacus", withExtension: "pte"),
        ]

        for candidate in candidates {
            if let modelURL = candidate, FileManager.default.fileExists(atPath: modelURL.path) {
                try loadModel(at: modelURL)
                return
            }
        }

        // Search in package Model directory
        let packagePath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Model")
            .appendingPathComponent("abacus.pte")

        if FileManager.default.fileExists(atPath: packagePath.path) {
            try loadModel(at: packagePath)
            return
        }

        throw AbacusError.modelNotFound(path: "abacus.pte")
    }

    /// Returns whether a model is currently loaded.
    public var isModelLoaded: Bool {
        modelLoaded
    }

    // MARK: - Inference

    /// Predicts the state of a single bead.
    ///
    /// - Parameter tensorData: Preprocessed tensor data for one cell
    ///   in CHW format (3 × 224 × 224 = 150,528 floats).
    /// - Returns: The prediction for the cell.
    /// - Throws: ``AbacusError/modelNotLoaded`` if no model is loaded.
    public func predict(tensorData: [Float]) async throws -> CellPrediction {
        guard modelLoaded else {
            throw AbacusError.modelNotLoaded
        }

        let results = try await predictBatch(tensorData: tensorData, cellCount: 1)

        guard !results.isEmpty else {
            throw AbacusError.internalError(message: "Empty inference result")
        }

        return results[0]
    }

    /// Predicts the states of multiple beads in batches.
    ///
    /// Efficiently processes multiple cells by batching them for GPU
    /// inference. Cells are processed in batches according to the engine's batch size.
    ///
    /// - Parameters:
    ///   - tensorData: Flattened tensor data for all cells (NCHW format).
    ///   - cellCount: The number of cells in the tensor data.
    /// - Returns: An array of predictions, one per cell.
    /// - Throws: ``AbacusError/modelNotLoaded`` if no model is loaded,
    ///   or ``AbacusError/invalidInput(reason:)`` if tensor size is wrong.
    ///
    /// ## Expected Tensor Format
    ///
    /// The tensor data should be organized as:
    /// - Shape: [cellCount, 3, 224, 224]
    /// - Flattened in row-major order
    /// - Normalized according to model requirements
    ///
    /// Total size: `cellCount × 3 × 224 × 224` floats.
    public func predictBatch(
        tensorData: [Float],
        cellCount: Int
    ) async throws -> [CellPrediction] {
        guard modelLoaded else {
            throw AbacusError.modelNotLoaded
        }

        // Validate input size
        let expectedSize = cellCount * cellChannels * cellHeight * cellWidth
        guard tensorData.count >= expectedSize else {
            throw AbacusError.invalidInput(
                reason: "Tensor data size mismatch: expected \(expectedSize), got \(tensorData.count)"
            )
        }

        // Placeholder: Return dummy predictions
        // In production, this would call ExecuTorch inference
        return createDummyPredictions(count: cellCount)
    }

    // MARK: - Private

    /// Creates placeholder predictions when ExecuTorch is not available.
    private func createDummyPredictions(count: Int) -> [CellPrediction] {
        (0..<count).map { _ in
            CellPrediction(
                predictedClass: .empty,
                probabilities: [0.33, 0.33, 0.34]
            )
        }
    }

    /// Applies softmax to convert logits to probabilities.
    private func softmax(_ logits: [Float]) -> [Float] {
        let maxLogit = logits.max() ?? 0
        let exps = logits.map { exp($0 - maxLogit) }
        let sumExp = exps.reduce(0, +)
        return exps.map { $0 / sumExp }
    }

    /// Parses inference output tensor into cell predictions.
    private func parseOutputs(_ data: [Float], batchSize: Int) -> [CellPrediction] {
        let numClasses = 3
        var predictions: [CellPrediction] = []

        for i in 0..<batchSize {
            let offset = i * numClasses
            guard offset + numClasses <= data.count else {
                break
            }

            let logits = Array(data[offset..<offset + numClasses])
            let probabilities = softmax(logits)

            let maxIndex = probabilities.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let predictedClass: CellState = switch maxIndex {
            case 0: .upper
            case 1: .lower
            default: .empty
            }

            predictions.append(CellPrediction(
                predictedClass: predictedClass,
                probabilities: probabilities
            ))
        }

        return predictions
    }
}

// MARK: - Bundle Token

/// Token class for locating framework bundle resources.
private final class BundleToken {}
