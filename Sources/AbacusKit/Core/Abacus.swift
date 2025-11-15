import Foundation
import CoreVideo
import AbacusKitBridge

/// Main SDK interface for AbacusKit
public struct Abacus {
    /// Shared singleton instance
    public static let shared = Abacus()
    
    private let torchModule: TorchModuleBridge
    private let versionChecker: VersionChecker
    private let modelDownloader: ModelDownloader
    private let modelCache: ModelCache
    private let preprocessor: Preprocessor
    private let fileStorage: FileStorage
    
    private init() {
        self.torchModule = TorchModuleBridge()
        self.versionChecker = VersionChecker()
        self.modelDownloader = ModelDownloader()
        self.modelCache = ModelCache()
        self.preprocessor = Preprocessor()
        self.fileStorage = FileStorage()
    }
    
    /// Configure the SDK with S3 URLs and local storage
    /// - Parameter config: Configuration containing version URL and model directory
    /// - Throws: AbacusError if configuration fails
    public func configure(config: AbacusConfig) async throws {
        do {
            // Fetch remote version using VersionChecker
            let remoteVersion = try await versionChecker.fetchRemoteVersion(from: config.versionURL)
            
            // Compare with ModelCache.currentVersion
            let cachedVersion = await modelCache.currentVersion
            let cachedModelURL = await modelCache.currentModelURL
            
            var modelURL: URL
            
            // Check if we need to download a new model
            if let cachedVersion = cachedVersion,
               let cachedModelURL = cachedModelURL,
               remoteVersion.version <= cachedVersion,
               fileStorage.fileExists(at: cachedModelURL) {
                // Use cached model
                modelURL = cachedModelURL
            } else {
                // Download new model
                let modelFileName = "model_v\(remoteVersion.version).pt"
                let destinationURL = config.modelDirectoryURL.appendingPathComponent(modelFileName)
                
                do {
                    modelURL = try await modelDownloader.downloadModel(
                        from: remoteVersion.modelURL,
                        to: destinationURL
                    )
                } catch {
                    throw AbacusError.downloadFailed(underlying: error)
                }
                
                // Update ModelCache with new model info
                await modelCache.update(modelURL: modelURL, version: remoteVersion.version)
                
                // Clean up old model files if they exist
                if let oldModelURL = cachedModelURL,
                   oldModelURL != modelURL,
                   fileStorage.fileExists(at: oldModelURL) {
                    try? fileStorage.deleteFile(at: oldModelURL)
                }
            }
            
            // Load model into TorchModuleBridge
            var error: NSError?
            let success = torchModule.loadModel(atPath: modelURL.path, error: &error)
            
            if !success {
                if let error = error {
                    throw AbacusError.invalidModel(reason: error.localizedDescription)
                } else {
                    throw AbacusError.invalidModel(reason: "Failed to load model")
                }
            }
            
        } catch let error as AbacusError {
            throw error
        } catch {
            throw AbacusError.downloadFailed(underlying: error)
        }
    }
    
    /// Perform inference on a camera frame
    /// - Parameter pixelBuffer: Input frame from camera
    /// - Returns: Prediction result with value and confidence
    /// - Throws: AbacusError if inference fails
    public func predict(pixelBuffer: CVPixelBuffer) async throws -> PredictionResult {
        // Check if model is loaded
        let cachedModelURL = await modelCache.currentModelURL
        guard cachedModelURL != nil else {
            throw AbacusError.modelNotLoaded
        }
        
        // Validate input using Preprocessor
        try preprocessor.validate(pixelBuffer)
        
        // Measure inference start time
        let startTime = Date()
        
        // Call TorchModuleBridge.predictWithPixelBuffer
        var error: NSError?
        guard let outputArray = torchModule.predict(with: pixelBuffer, error: &error) else {
            if let error = error {
                throw AbacusError.inferenceFailed(underlying: error)
            } else {
                throw AbacusError.inferenceFailed(underlying: NSError(
                    domain: "AbacusKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Prediction returned nil"]
                ))
            }
        }
        
        // Calculate inference time
        let inferenceTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        // Parse output array to extract value and confidence
        // Assuming the model outputs [value, confidence, ...]
        guard outputArray.count >= 2 else {
            throw AbacusError.inferenceFailed(underlying: NSError(
                domain: "AbacusKit",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid output array size: \(outputArray.count)"]
            ))
        }
        
        let value = outputArray[0].intValue
        let confidence = outputArray[1].doubleValue
        
        // Return PredictionResult
        return PredictionResult(
            value: value,
            confidence: confidence,
            inferenceTimeMs: inferenceTimeMs
        )
    }
}
