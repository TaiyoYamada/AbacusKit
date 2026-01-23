// AbacusKit - SorobanInterpreter
// Swift 6.2

import CoreGraphics
import Foundation

/// そろばん値の解釈器
///
/// セル状態から数値を計算する。可変レーン対応。
public struct SorobanInterpreter: Sendable {
    public init() {}

    /// レーンリストから数値を計算
    /// - Parameter lanes: レーンのリスト（順不同）
    /// - Returns: 計算された整数値
    public func interpret(lanes: [SorobanLane]) -> Int {
        guard !lanes.isEmpty else {
            return 0
        }

        // 右から順にソート
        let sortedLanes = lanes.sorted { $0.position < $1.position }

        var value = 0
        var multiplier = 1

        for lane in sortedLanes {
            value += lane.value * multiplier
            multiplier *= 10
        }

        return value
    }

    /// セル状態配列から桁の値を計算
    /// - Parameters:
    ///   - upperBead: 上珠の状態
    ///   - lowerBeads: 下珠の状態（4個）
    /// - Returns: この桁の値（0-9）
    public func calculateDigitValue(upperBead: CellState, lowerBeads: [CellState]) -> Int {
        var value = 0

        // 上珠が下がっている = 5点
        if upperBead == .lower {
            value += 5
        }

        // 下珠が上がっている = 各1点
        for bead in lowerBeads {
            if bead == .lower {
                value += 1
            }
        }

        return min(9, value)
    }

    /// 推論結果からレーンを構築
    public func buildLanes(
        from predictions: [CellPrediction],
        laneCount: Int,
        boundingBoxes: [CGRect]
    ) -> [SorobanLane] {
        guard predictions.count == laneCount * 5,
              boundingBoxes.count == laneCount else
        {
            return []
        }

        var lanes: [SorobanLane] = []

        for i in 0..<laneCount {
            let startIndex = i * 5
            let cellPredictions = Array(predictions[startIndex..<startIndex + 5])

            let upperBead = cellPredictions[0].predictedClass
            let lowerBeads = cellPredictions[1...4].map { $0.predictedClass }

            let confidence = cellPredictions.map { $0.confidence }.min() ?? 0

            let digit = SorobanDigit(
                position: laneCount - 1 - i,
                upperBead: upperBead,
                lowerBeads: Array(lowerBeads),
                confidence: confidence,
                boundingBox: boundingBoxes[i],
                probabilities: cellPredictions.map { $0.probabilities }
            )

            let lane = SorobanLane(
                digit: digit,
                roi: boundingBoxes[i],
                rawPredictions: cellPredictions
            )

            lanes.append(lane)
        }

        return lanes
    }

    /// 結果を検証
    public func validate(lanes: [SorobanLane], threshold: Float) -> Bool {
        lanes.allSatisfy { $0.confidence >= threshold && $0.digit.isValid }
    }
}
