import Foundation
import CoreVideo
import AbacusKitBridge

/// そろばんセルの状態
public enum AbacusCellState: Int, Sendable {
    case upper = 0  // 上玉
    case lower = 1  // 下玉
    case empty = 2  // 玉なし
}

/// TorchScript 推論結果
public struct TorchInferenceResult: Sendable {
    public let predictedState: AbacusCellState
    public let probabilities: [Float]
    public let inferenceTimeMs: Double
    
    public init(predictedState: AbacusCellState, probabilities: [Float], inferenceTimeMs: Double) {
        self.predictedState = predictedState
        self.probabilities = probabilities
        self.inferenceTimeMs = inferenceTimeMs
    }
}

/// TorchScript 推論エンジンのエラー
public enum TorchInferenceError: Error, Sendable {
    case modelNotLoaded
    case modelLoadFailed(String)
    case inferenceFailed(String)
    case invalidInput(String)
}

/// TorchScript を使った推論エンジン（Swift API）
public actor TorchInferenceEngine {
    private let bridge: TorchModuleBridge
    private var isLoaded: Bool = false
    
    public init() {
        self.bridge = TorchModuleBridge()
    }
    
    /// モデルをロードする
    /// - Parameter modelPath: .pt ファイルのパス
    public func loadModel(at modelPath: URL) throws {
        var error: NSError?
        let success = bridge.loadModel(atPath: modelPath.path, error: &error)
        
        if let error = error {
            throw TorchInferenceError.modelLoadFailed(error.localizedDescription)
        }
        
        guard success else {
            throw TorchInferenceError.modelLoadFailed("Unknown error")
        }
        
        isLoaded = true
    }
    
    /// 推論を実行する
    /// - Parameter pixelBuffer: 入力画像（224x224 RGB）
    /// - Returns: 推論結果
    public func predict(pixelBuffer: CVPixelBuffer) throws -> TorchInferenceResult {
        guard isLoaded else {
            throw TorchInferenceError.modelNotLoaded
        }
        
        var result = TorchPredictionResult()
        var error: NSError?
        
        let success = bridge.predict(
            with: pixelBuffer,
            result: &result,
            error: &error
        )
        
        if let error = error {
            throw TorchInferenceError.inferenceFailed(error.localizedDescription)
        }
        
        guard success else {
            throw TorchInferenceError.inferenceFailed("Unknown error")
        }
        
        // 結果を Swift 型に変換
        guard let state = AbacusCellState(rawValue: Int(result.predictedClass)) else {
            throw TorchInferenceError.inferenceFailed("Invalid predicted class")
        }
        
        let probabilities = [
            result.probabilities.0,
            result.probabilities.1,
            result.probabilities.2
        ]
        
        return TorchInferenceResult(
            predictedState: state,
            probabilities: probabilities,
            inferenceTimeMs: result.inferenceTimeMs
        )
    }
}
