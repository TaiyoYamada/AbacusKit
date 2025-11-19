import Foundation
import CoreVideo
import AbacusKitBridge

/// そろばんセルの状態
public enum AbacusCellState: Int, Sendable {
    case upper = 0  // 上玉
    case lower = 1  // 下玉
    case empty = 2  // 玉なし
}

/// ExecuTorch 推論結果
public struct ExecuTorchInferenceResult: Sendable {
    public let predictedState: AbacusCellState
    public let probabilities: [Float]
    public let inferenceTimeMs: Double
    
    public init(predictedState: AbacusCellState, probabilities: [Float], inferenceTimeMs: Double) {
        self.predictedState = predictedState
        self.probabilities = probabilities
        self.inferenceTimeMs = inferenceTimeMs
    }
}

/// ExecuTorch 推論エンジンのエラー
public enum ExecuTorchInferenceError: Error, Sendable {
    case modelNotLoaded
    case modelLoadFailed(String)
    case inferenceFailed(String)
    case invalidInput(String)
}

/// ExecuTorch を使った推論エンジン（Swift API）
public actor ExecuTorchInferenceEngine {
    private let bridge: ExecuTorchModuleBridge
    private var isLoaded: Bool = false
    
    public init() {
        self.bridge = ExecuTorchModuleBridge()
    }
    
    /// モデルをロードする
    /// - Parameter modelPath: .pte ファイルのパス
    public func loadModel(at modelPath: URL) throws {
        do {
            try bridge.loadModel(atPath: modelPath.path)
            isLoaded = true
        } catch {
            throw ExecuTorchInferenceError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    /// 推論を実行する
    /// - Parameter pixelBuffer: 入力画像（224x224 RGB）
    /// - Returns: 推論結果
    public func predict(pixelBuffer: CVPixelBuffer) throws -> ExecuTorchInferenceResult {
        guard isLoaded else {
            throw ExecuTorchInferenceError.modelNotLoaded
        }
        
        var result = ExecuTorchPredictionResult()
        
        do {
            try bridge.predict(with: pixelBuffer, result: &result)
        } catch {
            throw ExecuTorchInferenceError.inferenceFailed(error.localizedDescription)
        }
        
        // 結果を Swift 型に変換
        guard let state = AbacusCellState(rawValue: Int(result.predictedClass)) else {
            throw ExecuTorchInferenceError.inferenceFailed("Invalid predicted class")
        }
        
        let probabilities = [
            result.probabilities.0,
            result.probabilities.1,
            result.probabilities.2
        ]
        
        return ExecuTorchInferenceResult(
            predictedState: state,
            probabilities: probabilities,
            inferenceTimeMs: result.inferenceTimeMs
        )
    }
}
