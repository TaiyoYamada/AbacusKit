// AbacusKit - AbacusRecognizer
// Swift 6.2

import Foundation
import CoreVideo
import CoreGraphics

/// そろばん認識エンジン
///
/// カメラフレームからそろばんを検出し、数値を認識する統合ファサード。
/// 
/// ## 基本的な使用例
///
/// ```swift
/// let recognizer = try AbacusRecognizer()
/// 
/// // 単一フレーム認識
/// let result = try await recognizer.recognize(pixelBuffer: cameraFrame)
/// print("認識値: \(result.value)")
/// ```
public actor AbacusRecognizer {
    
    // MARK: - Dependencies
    
    private var configuration: AbacusConfiguration
    private let interpreter: SorobanInterpreter
    private var inferenceEngine: AbacusInferenceEngine?
    private var visionProcessor: VisionProcessor?
    
    // MARK: - State
    
    private var isConfigured: Bool = false
    private var frameCount: Int = 0
    
    // MARK: - Initialization
    
    /// デフォルト設定で初期化
    public init() {
        self.configuration = .default
        self.interpreter = SorobanInterpreter()
        self.visionProcessor = VisionProcessor(configuration: .default)
        self.inferenceEngine = AbacusInferenceEngine()
        self.isConfigured = true
    }
    
    /// カスタム設定で初期化
    public init(configuration: AbacusConfiguration) {
        self.configuration = configuration
        self.interpreter = SorobanInterpreter()
        self.visionProcessor = VisionProcessor(configuration: configuration)
        self.inferenceEngine = AbacusInferenceEngine()
        self.isConfigured = true
    }
    
    // MARK: - Configuration
    
    /// 設定を更新
    public func configure(_ config: AbacusConfiguration) async throws {
        self.configuration = config
        visionProcessor?.updateConfiguration(config)
        
        if let modelPath = config.modelPath {
            try await inferenceEngine?.loadModel(at: modelPath)
        }
    }
    
    /// 現在の設定を取得
    public var currentConfiguration: AbacusConfiguration {
        configuration
    }
    
    // MARK: - Recognition
    
    /// 単一フレームを認識
    ///
    /// - Parameter pixelBuffer: カメラフレーム（BGRA 推奨）
    /// - Returns: 認識結果
    /// - Throws: AbacusError
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> SorobanResult {
        guard isConfigured else {
            throw AbacusError.modelNotLoaded
        }
        
        frameCount += 1
        if configuration.frameSkipInterval > 1 && frameCount % configuration.frameSkipInterval != 0 {
            throw AbacusError.frameNotDetected
        }
        
        let startTime = Date()
        
        // 1. 前処理
        let preprocessingStart = Date()
        guard let visionResult = try visionProcessor?.process(pixelBuffer: pixelBuffer) else {
            throw AbacusError.preprocessingFailed(reason: "Vision processor not initialized", code: -1)
        }
        let preprocessingTime = Date().timeIntervalSince(preprocessingStart) * 1000
        
        guard visionResult.frameDetected else {
            throw AbacusError.frameNotDetected
        }
        
        // 2. 推論
        let inferenceStart = Date()
        guard let engine = inferenceEngine else {
            throw AbacusError.modelNotLoaded
        }
        
        let predictions = try await engine.predictBatch(
            tensorData: visionResult.tensorData,
            cellCount: visionResult.cellCount
        )
        let inferenceTime = Date().timeIntervalSince(inferenceStart) * 1000
        
        // 3. 結果の解釈
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
        
        // 4. 結果の構築
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
    
    /// 連続認識（安定化付き）
    public func recognizeStabilized(
        pixelBuffer: CVPixelBuffer,
        consecutiveCount: Int = 3
    ) async throws -> SorobanResult? {
        let result = try await recognize(pixelBuffer: pixelBuffer)
        return result
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

/// AbacusVision の Swift ラッパー
final class VisionProcessor: @unchecked Sendable {
    private var configuration: AbacusConfiguration
    
    struct VisionResult: Sendable {
        let frameDetected: Bool
        let frameRect: CGRect
        let frameCorners: [CGPoint]
        let laneCount: Int
        let laneBoundingBoxes: [CGRect]
        let tensorData: [Float]  // Sendable のために配列に変更
        let cellCount: Int
        let detectionTimeMs: Double
    }
    
    init(configuration: AbacusConfiguration) {
        self.configuration = configuration
    }
    
    func updateConfiguration(_ config: AbacusConfiguration) {
        self.configuration = config
    }
    
    func process(pixelBuffer: CVPixelBuffer) throws -> VisionResult {
        // TODO: AbacusVision C++ モジュールを呼び出す
        throw AbacusError.frameNotDetected
    }
}
