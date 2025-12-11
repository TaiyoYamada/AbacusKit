// AbacusKit - SorobanDigit
// Swift 6.2

import Foundation
import CoreGraphics

/// そろばんの1桁分の情報
///
/// 上珠1個と下珠4個の状態を保持し、その桁の値（0-9）を計算する。
public struct SorobanDigit: Sendable, Equatable, Hashable {
    /// 桁位置（右から0始まり）
    public let position: Int

    /// 上珠の状態
    public let upperBead: CellState

    /// 下珠の状態（上から順に4個）
    public let lowerBeads: [CellState]

    /// この桁の値（0-9）
    public let value: Int

    /// この桁の信頼度（0.0-1.0）
    public let confidence: Float

    /// 元画像上のバウンディングボックス
    public let boundingBox: CGRect

    /// 各セルの確率分布
    public let probabilities: [[Float]]

    /// イニシャライザ
    public init(
        position: Int,
        upperBead: CellState,
        lowerBeads: [CellState],
        confidence: Float,
        boundingBox: CGRect,
        probabilities: [[Float]] = []
    ) {
        precondition(lowerBeads.count == 4, "下珠は4個必要")

        self.position = position
        self.upperBead = upperBead
        self.lowerBeads = lowerBeads
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.probabilities = probabilities

        // 値を計算
        self.value = Self.calculateValue(upperBead: upperBead, lowerBeads: lowerBeads)
    }

    /// そろばんの値を計算
    private static func calculateValue(upperBead: CellState, lowerBeads: [CellState]) -> Int {
        var value = 0

        // 上珠: lower位置 = 5点
        if upperBead == .lower {
            value += 5
        }

        // 下珠: lower位置 = 1点ずつ（上から順に）
        for bead in lowerBeads {
            if bead == .lower {
                value += 1
            }
        }

        return min(9, value) // 最大9
    }

    /// すべてのセルが有効か
    public var isValid: Bool {
        upperBead.isValid && lowerBeads.allSatisfy { $0.isValid }
    }
}

extension SorobanDigit: CustomStringConvertible {
    public var description: String {
        let upper = upperBead == .lower ? "●" : "○"
        let lower = lowerBeads.map { $0 == .lower ? "●" : "○" }.joined()
        return "[\(position)]: \(upper)|\(lower) = \(value)"
    }
}
