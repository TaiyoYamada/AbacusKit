// AbacusKit - SorobanResult
// Swift 6.2

import Foundation
import CoreGraphics

/// そろばん認識の完全な結果
public struct SorobanResult: Sendable, Equatable {

    // MARK: - 主要な結果

    /// 認識された数値
    public let value: Int

    /// 各レーン（桁）の情報（右から順）
    public let lanes: [SorobanLane]

    /// 全体信頼度（0.0-1.0）
    public let confidence: Float

    // MARK: - フレーム情報

    /// 検出されたそろばんフレームの位置
    public let frameRect: CGRect

    /// フレームの4隅（射影変換用）
    public let frameCorners: [CGPoint]

    /// 検出されたレーン数
    public let laneCount: Int

    // MARK: - パフォーマンス情報

    /// 処理時間の内訳
    public let timing: TimingBreakdown

    /// タイムスタンプ
    public let timestamp: Date

    // MARK: - 初期化

    public init(
        value: Int,
        lanes: [SorobanLane],
        confidence: Float,
        frameRect: CGRect,
        frameCorners: [CGPoint],
        timing: TimingBreakdown,
        timestamp: Date = Date()
    ) {
        self.value = value
        self.lanes = lanes
        self.confidence = confidence
        self.frameRect = frameRect
        self.frameCorners = frameCorners
        self.laneCount = lanes.count
        self.timing = timing
        self.timestamp = timestamp
    }

    // MARK: - 便利なアクセサ

    /// 桁数
    public var digitCount: Int { lanes.count }

    /// 有効な認識結果か
    public var isValid: Bool {
        confidence > 0.5 && lanes.allSatisfy { $0.digit.isValid }
    }

    /// 合計処理時間（ミリ秒）
    public var totalProcessingTimeMs: Double {
        timing.totalMs
    }

    /// 各桁の値を配列で取得（左から右）
    public var digitValues: [Int] {
        lanes.sorted { $0.position > $1.position }.map { $0.value }
    }
}

/// 処理時間の内訳
public struct TimingBreakdown: Sendable, Equatable {
    /// 前処理時間（OpenCV）
    public let preprocessingMs: Double

    /// フレーム検出時間
    public let detectionMs: Double

    /// 推論時間（ExecuTorch）
    public let inferenceMs: Double

    /// 後処理時間（値解釈）
    public let postprocessingMs: Double

    /// 合計時間
    public var totalMs: Double {
        preprocessingMs + detectionMs + inferenceMs + postprocessingMs
    }

    /// FPS換算
    public var estimatedFPS: Double {
        guard totalMs > 0 else { return 0 }
        return 1000.0 / totalMs
    }

    public init(
        preprocessingMs: Double = 0,
        detectionMs: Double = 0,
        inferenceMs: Double = 0,
        postprocessingMs: Double = 0
    ) {
        self.preprocessingMs = preprocessingMs
        self.detectionMs = detectionMs
        self.inferenceMs = inferenceMs
        self.postprocessingMs = postprocessingMs
    }
}

extension SorobanResult: CustomStringConvertible {
    public var description: String {
        """
        SorobanResult {
            value: \(value)
            lanes: \(laneCount)桁
            confidence: \(String(format: "%.1f%%", confidence * 100))
            processingTime: \(String(format: "%.1fms", timing.totalMs))
            fps: \(String(format: "%.1f", timing.estimatedFPS))
        }
        """
    }
}
