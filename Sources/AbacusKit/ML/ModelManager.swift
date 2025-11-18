import Foundation
import CoreML
import CoreVideo

/// Protocol for managing CoreML model loading and inference
///
/// This protocol abstracts CoreML operations for dependency inversion.
protocol ModelManager: Sendable {
    /// Load a CoreML model from file
    /// - Parameter url: URL to the .mlmodelc file
    /// - Throws: Error if model loading fails
    func loadModel(from url: URL) async throws
    
    /// Perform inference on a pixel buffer
    /// - Parameter pixelBuffer: Input pixel buffer
    /// - Returns: Array of output values
    /// - Throws: Error if inference fails
    func predict(pixelBuffer: CVPixelBuffer) async throws -> [Float]
    
    /// Check if a model is currently loaded
    /// - Returns: True if model is loaded, false otherwise
    func isModelLoaded() async -> Bool
}

// CVPixelBuffer is not Sendable, so we need to suppress the warning
extension CVPixelBuffer: @unchecked Sendable {}

/// Implementation of ModelManager using CoreML
actor ModelManagerImpl: ModelManager {
    private nonisolated(unsafe) var model: MLModel?
    private let logger: Logger
    
    init(logger: Logger = .make(category: "ML")) {
        self.logger = logger
    }
    
    func loadModel(from url: URL) async throws {
        logger.info("Loading CoreML model", metadata: ["path": url.path])
        
        do {
            // CoreMLモデルを非同期でロード
            let compiledURL = try await compileModelIfNeeded(url)
            let model = try await MLModel.load(contentsOf: compiledURL)
            
            self.model = model
            
            logger.info("CoreML model loaded successfully")
        } catch {
            logger.error("Failed to load CoreML model", error: error)
            throw AbacusError.modelLoadFailed(underlying: error)
        }
    }
    
    func predict(pixelBuffer: CVPixelBuffer) async throws -> [Float] {
        guard let model = model else {
            logger.error("Attempted prediction without loaded model")
            throw AbacusError.modelNotLoaded
        }
        
        do {
            // CVPixelBufferをMLFeatureValueに変換
            let inputFeature = MLFeatureValue(pixelBuffer: pixelBuffer)
            
            // 入力を準備（モデルの入力名に応じて調整が必要）
            let inputProvider = try MLDictionaryFeatureProvider(
                dictionary: ["input": inputFeature]
            )
            
            // 推論を実行
            let output = try await model.prediction(from: inputProvider)
            
            // 出力を解析（モデルの出力形式に応じて調整が必要）
            // ここでは出力が "output" という名前のMultiArrayであると仮定
            guard let outputFeature = output.featureValue(for: "output"),
                  let multiArray = outputFeature.multiArrayValue else {
                logger.error("Failed to extract output from model prediction")
                throw AbacusError.inferenceFailed(
                    underlying: NSError(
                        domain: "ModelManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid model output format"]
                    )
                )
            }
            
            // MultiArrayをFloat配列に変換
            let outputArray = convertMultiArrayToFloatArray(multiArray)
            
            logger.debug(
                "Prediction completed",
                metadata: ["outputSize": "\(outputArray.count)"]
            )
            
            return outputArray
        } catch let error as AbacusError {
            throw error
        } catch {
            logger.error("Prediction failed", error: error)
            throw AbacusError.inferenceFailed(underlying: error)
        }
    }
    
    func isModelLoaded() async -> Bool {
        return model != nil
    }
    
    // MARK: - Private Helpers
    
    /// モデルが未コンパイルの場合はコンパイルする
    private func compileModelIfNeeded(_ url: URL) async throws -> URL {
        // .mlmodelcの場合はそのまま返す
        if url.pathExtension == "mlmodelc" {
            return url
        }
        
        // .mlmodelの場合はコンパイルが必要
        if url.pathExtension == "mlmodel" {
            logger.info("Compiling CoreML model")
            let compiledURL = try await withCheckedThrowingContinuation { continuation in
                Task {
                    do {
                        let url = try MLModel.compileModel(at: url)
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            logger.info("Model compiled successfully", metadata: ["path": compiledURL.path])
            return compiledURL
        }
        
        // それ以外の場合はそのまま返す（エラーはloadで発生）
        return url
    }
    
    /// MLMultiArrayをFloat配列に変換
    private func convertMultiArrayToFloatArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var result = [Float](repeating: 0, count: count)
        
        let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            result[i] = pointer[i]
        }
        
        return result
    }
}
