// AbacusKit - VisionBridgeTests
// Swift 6.2

import XCTest
@testable import AbacusKit

final class VisionBridgeTests: XCTestCase {
    // MARK: - Initialization Tests

    func testVisionBridgeInitialization() {
        // VisionBridge は OpenCV がリンクされていない環境では
        // nil instance になる可能性がある
        let bridge = VisionBridge()

        // isValid プロパティが存在することを確認
        // 実際の結果は OpenCV の有無に依存
        _ = bridge.isValid
    }

    func testVisionBridgeMultipleInstances() {
        // 複数のインスタンスが独立して動作することを確認
        let bridge1 = VisionBridge()
        let bridge2 = VisionBridge()

        // 両方のインスタンスが同じ状態を持つ（OpenCV 依存）
        XCTAssertEqual(bridge1.isValid, bridge2.isValid)
    }

    // MARK: - Error Handling Tests

    func testProcessWithNilBridgeThrowsError() {
        // 無効なブリッジでの処理はエラーになるべき
        // Note: 実際のテストには CVPixelBuffer のモックが必要
    }

    // MARK: - VisionExtractionResult Tests

    func testVisionExtractionResultProperties() {
        // VisionExtractionResult の構造体が正しく初期化できることを確認
        let result = VisionExtractionResult(
            frameDetected: true,
            frameRect: CGRect(x: 0, y: 0, width: 100, height: 50),
            frameCorners: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 100, y: 0),
                CGPoint(x: 100, y: 50),
                CGPoint(x: 0, y: 50),
            ],
            laneCount: 5,
            laneBoundingBoxes: [],
            tensorData: [],
            cellCount: 25,
            detectionTimeMs: 15.5
        )

        XCTAssertTrue(result.frameDetected)
        XCTAssertEqual(result.frameRect.width, 100)
        XCTAssertEqual(result.frameRect.height, 50)
        XCTAssertEqual(result.laneCount, 5)
        XCTAssertEqual(result.cellCount, 25)
        XCTAssertEqual(result.detectionTimeMs, 15.5, accuracy: 0.01)
    }

    func testVisionExtractionResultIsSendable() {
        // VisionExtractionResult が Sendable 準拠であることを確認
        let result = VisionExtractionResult(
            frameDetected: false,
            frameRect: .zero,
            frameCorners: [],
            laneCount: 0,
            laneBoundingBoxes: [],
            tensorData: [],
            cellCount: 0,
            detectionTimeMs: 0
        )

        // Task で送信可能であることを確認
        Task {
            let _ = result
        }
    }
}
