// AbacusKit - VisionBridge
// Swift 6.2

import AbacusVisionBridge
import CoreGraphics
import CoreVideo
import Foundation

// MARK: - AbacusVision C API 呼び出し

/// AbacusVision C++ モジュールへのブリッジ
///
/// C API (`ab_vision_*`) を使用して AbacusVision C++ 実装を呼び出す。
/// Swift から CVPixelBuffer を渡して、そろばん検出結果を取得する。
final class VisionBridge: @unchecked Sendable {
    // MARK: - Properties

    /// AbacusVision インスタンスへのポインタ
    private var instance: UnsafeMutableRawPointer?

    /// ブリッジが有効か
    var isValid: Bool { instance != nil }

    // MARK: - Initialization

    init() {
        instance = ab_vision_create()
    }

    deinit {
        if let instance {
            ab_vision_destroy(instance)
        }
    }

    // MARK: - Processing

    /// CVPixelBuffer を処理してそろばん検出結果を取得
    ///
    /// - Parameter pixelBuffer: カメラフレーム（BGRA 推奨）
    /// - Returns: 抽出結果
    /// - Throws: AbacusError
    func process(pixelBuffer: CVPixelBuffer) throws -> VisionExtractionResult {
        guard let instance else {
            throw AbacusError.preprocessingFailed(reason: "VisionBridge not initialized", code: -1)
        }

        var result = ABExtractionResult()

        let errorCode = ab_vision_process(
            instance,
            Unmanaged.passUnretained(pixelBuffer).toOpaque(),
            &result
        )

        defer {
            ab_vision_free_result(&result)
        }

        guard errorCode == Int32(ABVisionErrorNone.rawValue) else {
            throw mapError(code: errorCode)
        }

        guard result.success else {
            throw AbacusError.frameNotDetected
        }

        return convertResult(result)
    }

    // MARK: - Private

    /// C エラーコードを AbacusError に変換
    private func mapError(code: Int32) -> AbacusError {
        let errorType = ABVisionError(rawValue: UInt32(code))

        switch errorType {
        case ABVisionErrorNone:
            return AbacusError.frameNotDetected
        case ABVisionErrorInvalidInput:
            return AbacusError.preprocessingFailed(reason: "Invalid input", code: Int(code))
        case ABVisionErrorFrameNotDetected:
            return AbacusError.frameNotDetected
        case ABVisionErrorLaneExtractionFailed:
            return AbacusError.preprocessingFailed(reason: "Lane extraction failed", code: Int(code))
        case ABVisionErrorTensorConversionFailed:
            return AbacusError.preprocessingFailed(reason: "Tensor conversion failed", code: Int(code))
        case ABVisionErrorMemoryAllocationFailed:
            return AbacusError.preprocessingFailed(reason: "Memory allocation failed", code: Int(code))
        case ABVisionErrorOpenCVError:
            return AbacusError.preprocessingFailed(reason: "OpenCV error", code: Int(code))
        default:
            return AbacusError.preprocessingFailed(reason: "Unknown error", code: Int(code))
        }
    }

    /// ABExtractionResult を Swift 型に変換
    private func convertResult(_ result: ABExtractionResult) -> VisionExtractionResult {
        // フレーム情報を変換
        let frame = result.frame
        let frameRect = CGRect(
            x: CGFloat(frame.boundingBox.x),
            y: CGFloat(frame.boundingBox.y),
            width: CGFloat(frame.boundingBox.width),
            height: CGFloat(frame.boundingBox.height)
        )

        let topLeft = CGPoint(
            x: CGFloat(frame.corners.topLeft.x),
            y: CGFloat(frame.corners.topLeft.y)
        )
        let topRight = CGPoint(
            x: CGFloat(frame.corners.topRight.x),
            y: CGFloat(frame.corners.topRight.y)
        )
        let bottomRight = CGPoint(
            x: CGFloat(frame.corners.bottomRight.x),
            y: CGFloat(frame.corners.bottomRight.y)
        )
        let bottomLeft = CGPoint(
            x: CGFloat(frame.corners.bottomLeft.x),
            y: CGFloat(frame.corners.bottomLeft.y)
        )
        let frameCorners = [topLeft, topRight, bottomRight, bottomLeft]

        // レーン情報を変換
        var laneBoundingBoxes: [CGRect] = []
        if let lanes = result.lanes {
            for i in 0 ..< Int(result.laneCount) {
                let lane = lanes[i]
                let rect = CGRect(
                    x: CGFloat(lane.boundingBox.x),
                    y: CGFloat(lane.boundingBox.y),
                    width: CGFloat(lane.boundingBox.width),
                    height: CGFloat(lane.boundingBox.height)
                )
                laneBoundingBoxes.append(rect)
            }
        }

        // テンソルデータを変換
        var tensorData: [Float] = []
        if let data = result.tensorData, result.tensorBatchSize > 0 {
            let count = Int(result.tensorBatchSize) *
                Int(result.tensorChannels) *
                Int(result.tensorHeight) *
                Int(result.tensorWidth)
            tensorData = Array(UnsafeBufferPointer(start: data, count: count))
        }

        return VisionExtractionResult(
            frameDetected: frame.detected,
            frameRect: frameRect,
            frameCorners: frameCorners,
            laneCount: Int(result.frame.laneCount),
            laneBoundingBoxes: laneBoundingBoxes,
            tensorData: tensorData,
            cellCount: Int(result.totalCells),
            detectionTimeMs: result.preprocessingTimeMs
        )
    }
}

// MARK: - Vision Extraction Result

/// Vision 処理の抽出結果（Swift 型）
struct VisionExtractionResult: Sendable {
    /// フレームが検出されたか
    let frameDetected: Bool

    /// フレームのバウンディングボックス
    let frameRect: CGRect

    /// フレームの4隅（射影変換用）
    let frameCorners: [CGPoint]

    /// 検出されたレーン数
    let laneCount: Int

    /// 各レーンのバウンディングボックス
    let laneBoundingBoxes: [CGRect]

    /// 推論用テンソルデータ (N × C × H × W, flatten済み)
    let tensorData: [Float]

    /// セル総数
    let cellCount: Int

    /// 検出処理時間（ミリ秒）
    let detectionTimeMs: Double
}
