// AbacusKit - SorobanLane
// Swift 6.2

import Foundation
import CoreGraphics

/// そろばんの1レーン（1桁）の完全な情報
public struct SorobanLane: Sendable, Equatable {
    /// 桁情報
    public let digit: SorobanDigit
    
    /// 画像上の位置
    public let roi: CGRect
    
    /// 処理時間（ミリ秒）
    public let processingTimeMs: Double
    
    /// 生の推論出力
    public let rawPredictions: [CellPrediction]
    
    /// イニシャライザ
    public init(
        digit: SorobanDigit,
        roi: CGRect,
        processingTimeMs: Double = 0,
        rawPredictions: [CellPrediction] = []
    ) {
        self.digit = digit
        self.roi = roi
        self.processingTimeMs = processingTimeMs
        self.rawPredictions = rawPredictions
    }
    
    /// 桁位置（ショートカット）
    public var position: Int { digit.position }
    
    /// 値（ショートカット）
    public var value: Int { digit.value }
    
    /// 信頼度（ショートカット）
    public var confidence: Float { digit.confidence }
}

/// 単一セルの推論結果
public struct CellPrediction: Sendable, Equatable {
    /// 予測されたクラス
    public let predictedClass: CellState
    
    /// 各クラスの確率 [upper, lower, empty]
    public let probabilities: [Float]
    
    /// 確信度（最大確率）
    public var confidence: Float {
        probabilities.max() ?? 0
    }
    
    public init(predictedClass: CellState, probabilities: [Float]) {
        self.predictedClass = predictedClass
        self.probabilities = probabilities
    }
}
