import Foundation
import CoreVideo
import Resolver

/// Main SDK interface for AbacusKit
///
/// This is the primary entry point for all AbacusKit operations.
/// It coordinates model updates, loading, and inference operations.
///
/// ## Usage
///
/// ```swift
/// let abacus = Abacus()
/// try await abacus.configure(config: config)
/// let result = try await abacus.predict(pixelBuffer: pixelBuffer)
/// ```
///
/// ## Thread Safety
///
/// All methods are thread-safe and use Swift's actor model for concurrency.
public final class Abacus: Sendable {
    
    private let coordinator: AbacusCoordinator
    
    /// Initialize a new Abacus instance
    ///
    /// This creates a new instance with default dependency injection.
    /// For testing, you can provide a custom container.
    public init(container: AbacusContainer = .shared) {
        self.coordinator = AbacusCoordinator(container: container)
    }
    
    /// Configure the SDK with remote version URL and local storage
    ///
    /// This method performs the following operations:
    /// 1. Validates the configuration
    /// 2. Checks for model updates from remote server
    /// 3. Downloads and extracts new model if needed
    /// 4. Loads the CoreML model into memory
    ///
    /// - Parameter config: Configuration containing version URL and model directory
    /// - Throws: AbacusError if configuration fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = AbacusConfig(
    ///     versionURL: URL(string: "https://s3.amazonaws.com/bucket/version.json")!,
    ///     modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    /// )
    /// try await abacus.configure(config: config)
    /// ```
    public func configure(config: AbacusConfig) async throws {
        try await coordinator.configure(config: config)
    }
    
    /// Perform inference on a camera frame
    ///
    /// This method performs the following operations:
    /// 1. Validates the input pixel buffer
    /// 2. Preprocesses the input if needed
    /// 3. Runs CoreML inference
    /// 4. Parses and returns the result
    ///
    /// - Parameter pixelBuffer: Input frame from camera (CVPixelBuffer)
    /// - Returns: Prediction result with value, confidence, and timing information
    /// - Throws: AbacusError if inference fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await abacus.predict(pixelBuffer: pixelBuffer)
    /// print("Value: \(result.value), Confidence: \(result.confidence)")
    /// ```
    ///
    /// ## Supported Pixel Formats
    ///
    /// - 32BGRA
    /// - 32RGBA
    /// - 24RGB
    public func predict(pixelBuffer: CVPixelBuffer) async throws -> PredictionResult {
        return try await coordinator.predict(pixelBuffer: pixelBuffer)
    }
    
    /// Get current SDK metadata
    ///
    /// Returns information about the SDK version and currently loaded model.
    ///
    /// - Returns: Metadata containing SDK and model information
    public func getMetadata() async -> AbacusMetadata {
        return await coordinator.getMetadata()
    }
    
    /// Force a model update check and download if available
    ///
    /// This method forces a check for model updates even if the cached
    /// version matches the remote version.
    ///
    /// - Parameter config: Configuration containing version URL and model directory
    /// - Throws: AbacusError if update fails
    public func forceUpdate(config: AbacusConfig) async throws {
        var updatedConfig = config
        updatedConfig = AbacusConfig(
            versionURL: config.versionURL,
            modelDirectoryURL: config.modelDirectoryURL,
            forceUpdate: true
        )
        try await coordinator.configure(config: updatedConfig)
    }
}

// MARK: - Coordinator

/// Internal coordinator for managing AbacusKit operations
///
/// This actor coordinates all SDK operations and manages state.
/// It follows the Coordinator pattern to separate concerns.
actor AbacusCoordinator {
    private let modelUpdater: ModelUpdater
    private let modelManager: ModelManager
    private let preprocessor: Preprocessor
    private let cache: ModelCache
    private let logger: Logger
    
    private var isConfigured = false
    
    init(container: AbacusContainer) {
        self.modelUpdater = container.resolve()
        self.modelManager = container.resolve()
        self.preprocessor = container.resolve()
        self.cache = container.resolve()
        self.logger = Logger.make(category: "Core")
    }
    
    func configure(config: AbacusConfig) async throws {
        logger.info("Starting configuration")
        
        do {
            try config.validate()
        } catch {
            logger.error("Configuration validation failed", error: error)
            throw error
        }
        
        let modelURL: URL
        do {
            modelURL = try await modelUpdater.updateModelIfNeeded(
                config: config,
                forceUpdate: config.forceUpdate
            )
        } catch {
            logger.error("Model update failed", error: error)
            throw error
        }
        
        do {
            try await modelManager.loadModel(from: modelURL)
        } catch {
            logger.error("Model loading failed", error: error)
            throw error
        }
        
        isConfigured = true
        logger.info("Configuration completed successfully")
    }
    
    func predict(pixelBuffer: CVPixelBuffer) async throws -> PredictionResult {
        guard isConfigured else {
            logger.error("Attempted prediction before configuration")
            throw AbacusError.notConfigured
        }
        
        guard await modelManager.isModelLoaded() else {
            logger.error("Model not loaded")
            throw AbacusError.modelNotLoaded
        }
        
        do {
            try preprocessor.validate(pixelBuffer)
        } catch {
            logger.error("Input validation failed", error: error)
            throw error
        }
        
        let startTime = Date()
        
        let outputArray: [Float]
        do {
            outputArray = try await modelManager.predict(pixelBuffer: pixelBuffer)
        } catch {
            logger.error("Inference failed", error: error)
            throw error
        }
        
        let inferenceTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        guard outputArray.count >= 2 else {
            logger.error(
                "Invalid output array size",
                metadata: ["size": "\(outputArray.count)"]
            )
            throw AbacusError.inferenceFailed(
                underlying: NSError(
                    domain: "Abacus",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid output array size: \(outputArray.count)"]
                )
            )
        }
        
        let value = Int(outputArray[0])
        let confidence = Double(outputArray[1])
        
        let result = PredictionResult(
            value: value,
            confidence: confidence,
            inferenceTimeMs: inferenceTimeMs
        )
        
        logger.debug(
            "Prediction completed",
            metadata: [
                "value": "\(value)",
                "confidence": "\(confidence)",
                "inferenceTimeMs": "\(inferenceTimeMs)"
            ]
        )
        
        return result
    }
    
    func getMetadata() async -> AbacusMetadata {
        let modelVersion = await cache.getCurrentVersion()
        
        return AbacusMetadata(
            sdkVersion: "1.0.0",
            modelVersion: modelVersion,
            lastUpdateCheck: Date()
        )
    }
}
