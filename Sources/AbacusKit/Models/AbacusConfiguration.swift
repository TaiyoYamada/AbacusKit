// AbacusKit - AbacusConfiguration
// Swift 6.2

import Foundation

/// AbacusKit の設定
public struct AbacusConfiguration: Sendable, Equatable {
    
    // MARK: - モデル設定
    
    /// モデルファイルのパス（nil = バンドル内モデル）
    public var modelPath: URL?
    
    /// 推論バックエンド
    public var inferenceBackend: InferenceBackend
    
    // MARK: - 認識設定
    
    /// 最小レーン数
    public var minLaneCount: Int
    
    /// 最大レーン数
    public var maxLaneCount: Int
    
    /// 信頼度閾値
    public var confidenceThreshold: Float
    
    /// フレーム検出の最小サイズ比率
    public var minFrameSizeRatio: Float
    
    // MARK: - パフォーマンス設定
    
    /// フレームスキップ間隔（1 = 毎フレーム処理）
    public var frameSkipInterval: Int
    
    /// 最大入力解像度（長辺）
    public var maxInputResolution: Int
    
    /// バッチサイズ（推論時）
    public var batchSize: Int
    
    // MARK: - 前処理設定
    
    /// CLAHE を有効化
    public var enableCLAHE: Bool
    
    /// ホワイトバランス補正を有効化
    public var enableWhiteBalance: Bool
    
    /// ノイズ低減を有効化
    public var enableNoiseReduction: Bool
    
    // MARK: - デバッグ設定
    
    /// デバッグオーバーレイを有効化
    public var enableDebugOverlay: Bool
    
    /// パフォーマンスログを有効化
    public var enablePerformanceLogging: Bool
    
    // MARK: - プリセット
    
    /// デフォルト設定
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
    
    /// 高精度モード
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
    
    /// 高速モード
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
    
    // MARK: - 初期化
    
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

/// 推論バックエンド
public enum InferenceBackend: String, Sendable, Codable, CaseIterable {
    /// CoreML（Neural Engine、推奨）
    case coreml
    
    /// MPS（GPU）
    case mps
    
    /// XNNPACK（CPU）
    case xnnpack
    
    /// 自動選択
    case auto
    
    /// バックエンドの説明
    public var localizedDescription: String {
        switch self {
        case .coreml: return "CoreML (Neural Engine)"
        case .mps: return "Metal Performance Shaders (GPU)"
        case .xnnpack: return "XNNPACK (CPU)"
        case .auto: return "Automatic Selection"
        }
    }
}
