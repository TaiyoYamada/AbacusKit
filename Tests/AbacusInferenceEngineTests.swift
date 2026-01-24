// AbacusKit - AbacusInferenceEngineTests
// Swift 6.2

import XCTest
@testable import AbacusKit

final class AbacusInferenceEngineTests: XCTestCase {
    // MARK: - Initialization Tests

    func testEngineInitialization() async {
        let engine = AbacusInferenceEngine()
        let isLoaded = await engine.isModelLoaded
        XCTAssertFalse(isLoaded, "モデルは初期状態でロードされていないべき")
    }

    func testEngineInitializationWithCustomBatchSize() async {
        let engine = AbacusInferenceEngine(batchSize: 16)
        let isLoaded = await engine.isModelLoaded
        XCTAssertFalse(isLoaded)
    }

    // MARK: - Model Loading Tests

    func testLoadModelNotFound() async {
        let engine = AbacusInferenceEngine()
        let nonExistentPath = URL(fileURLWithPath: "/nonexistent/model.pte")

        do {
            try await engine.loadModel(at: nonExistentPath)
            XCTFail("存在しないモデルのロードは失敗すべき")
        } catch let error as AbacusError {
            if case .modelNotFound = error {
                // 期待通り
            } else {
                XCTFail("modelNotFound エラーが期待されるが \(error) が発生")
            }
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    func testLoadBundledModelNotFound() async {
        // バンドル内にモデルがない場合のテスト
        let engine = AbacusInferenceEngine()

        do {
            try await engine.loadBundledModel()
            // モデルが見つかった場合は成功
            let isLoaded = await engine.isModelLoaded
            XCTAssertTrue(isLoaded)
        } catch let error as AbacusError {
            // モデルが見つからない場合も許容
            if case .modelNotFound = error {
                // テスト環境ではモデルがないかもしれない
            } else {
                XCTFail("予期しないエラー: \(error)")
            }
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    // MARK: - Inference Tests

    func testPredictWithoutModelThrowsError() async {
        let engine = AbacusInferenceEngine()
        let dummyTensorData: [Float] = Array(repeating: 0.5, count: 3 * 224 * 224)

        do {
            _ = try await engine.predict(tensorData: dummyTensorData)
            XCTFail("モデル未ロード時の推論は失敗すべき")
        } catch let error as AbacusError {
            if case .modelNotLoaded = error {
                // 期待通り
            } else {
                XCTFail("modelNotLoaded エラーが期待されるが \(error) が発生")
            }
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    func testPredictBatchWithoutModelThrowsError() async {
        let engine = AbacusInferenceEngine()
        let dummyTensorData: [Float] = Array(repeating: 0.5, count: 5 * 3 * 224 * 224)

        do {
            _ = try await engine.predictBatch(tensorData: dummyTensorData, cellCount: 5)
            XCTFail("モデル未ロード時のバッチ推論は失敗すべき")
        } catch let error as AbacusError {
            if case .modelNotLoaded = error {
                // 期待通り
            } else {
                XCTFail("modelNotLoaded エラーが期待されるが \(error) が発生")
            }
        } catch {
            XCTFail("予期しないエラー: \(error)")
        }
    }

    // MARK: - CellPrediction Tests

    func testCellPredictionConfidence() {
        let prediction = CellPrediction(
            predictedClass: .lower,
            probabilities: [0.1, 0.8, 0.1]
        )

        XCTAssertEqual(prediction.predictedClass, .lower)
        XCTAssertEqual(prediction.confidence, 0.8, accuracy: 0.01)
    }

    func testCellPredictionAllClasses() {
        // 各クラスの予測をテスト
        let upperPrediction = CellPrediction(
            predictedClass: .upper,
            probabilities: [0.9, 0.05, 0.05]
        )
        XCTAssertEqual(upperPrediction.predictedClass, .upper)

        let lowerPrediction = CellPrediction(
            predictedClass: .lower,
            probabilities: [0.05, 0.9, 0.05]
        )
        XCTAssertEqual(lowerPrediction.predictedClass, .lower)

        let emptyPrediction = CellPrediction(
            predictedClass: .empty,
            probabilities: [0.05, 0.05, 0.9]
        )
        XCTAssertEqual(emptyPrediction.predictedClass, .empty)
    }
}
