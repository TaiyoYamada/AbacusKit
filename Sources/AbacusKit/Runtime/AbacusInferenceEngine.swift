// AbacusKit - AbacusInferenceEngine
// Swift 6.2

import Foundation

/// ExecuTorch 推論エンジン
///
/// ExecuTorch を使用してそろばんセルの状態を推論する。
/// .pte モデルファイルをロードし、バッチ推論を実行する。
///
/// ## 使用例
///
/// ```swift
/// let engine = AbacusInferenceEngine()
/// try await engine.loadBundledModel()
/// let predictions = try await engine.predictBatch(tensorData: data, cellCount: 5)
/// ```
public actor AbacusInferenceEngine {
    // MARK: - Properties

    private var modelLoaded = false
    private var modelPath: URL?
    private let batchSize: Int

    // セル画像のサイズ (CHW format)
    private let cellChannels: Int = 3
    private let cellHeight: Int = 224
    private let cellWidth: Int = 224

    // ExecuTorch モジュール（実際の実装では型安全に保持）
    private var moduleHandle: Any?

    // MARK: - Initialization

    public init(batchSize: Int = 8) {
        self.batchSize = batchSize
    }

    // MARK: - Model Management

    /// モデルをロード
    public func loadModel(at path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AbacusError.modelNotFound(path: path.path)
        }

        // ExecuTorch モジュールのロードを試みる
        // 実際のアプリでは ExecuTorch xcframework がリンクされている必要がある
        modelPath = path
        modelLoaded = true

        // Note: 実際の ExecuTorch モジュールロードは以下のようになる:
        // moduleHandle = try loadExecuTorchModule(at: path)
    }

    /// バンドル内のモデルをロード
    public func loadBundledModel() throws {
        // バンドル内の abacus.pte を探す
        let candidates = [
            Bundle.main.url(forResource: "abacus", withExtension: "pte"),
            Bundle(for: BundleToken.self).url(forResource: "abacus", withExtension: "pte"),
        ]

        for candidate in candidates {
            if let modelURL = candidate, FileManager.default.fileExists(atPath: modelURL.path) {
                try loadModel(at: modelURL)
                return
            }
        }

        // Model ディレクトリから探す
        let packagePath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Model")
            .appendingPathComponent("abacus.pte")

        if FileManager.default.fileExists(atPath: packagePath.path) {
            try loadModel(at: packagePath)
            return
        }

        throw AbacusError.modelNotFound(path: "abacus.pte")
    }

    /// モデルがロード済みか
    public var isModelLoaded: Bool {
        modelLoaded
    }

    // MARK: - Inference

    /// 単一セルを推論
    public func predict(tensorData: [Float]) async throws -> CellPrediction {
        guard modelLoaded else {
            throw AbacusError.modelNotLoaded
        }

        let results = try await predictBatch(tensorData: tensorData, cellCount: 1)

        guard !results.isEmpty else {
            throw AbacusError.internalError(message: "Empty inference result")
        }

        return results[0]
    }

    /// バッチ推論
    ///
    /// - Parameters:
    ///   - tensorData: 入力テンソルデータ (N × C × H × W, flatten済み)
    ///   - cellCount: セル総数
    /// - Returns: 各セルの推論結果
    public func predictBatch(
        tensorData: [Float],
        cellCount: Int
    ) async throws -> [CellPrediction] {
        guard modelLoaded else {
            throw AbacusError.modelNotLoaded
        }

        // 入力データのバリデーション
        let expectedSize = cellCount * cellChannels * cellHeight * cellWidth
        guard tensorData.count >= expectedSize else {
            throw AbacusError.invalidInput(
                reason: "Tensor data size mismatch: expected \(expectedSize), got \(tensorData.count)"
            )
        }

        // TODO: 実際の ExecuTorch 推論を実装
        // 現在はダミー結果を返す（モデルがロードされていれば）
        return createDummyPredictions(count: cellCount)
    }

    // MARK: - Private

    /// ダミー予測結果を作成
    ///
    /// 実際の ExecuTorch 推論が実装されるまでのプレースホルダー。
    /// 各セルに対してランダムな予測を生成する。
    private func createDummyPredictions(count: Int) -> [CellPrediction] {
        (0 ..< count).map { _ in
            // シンプルなダミー予測（実際には ExecuTorch からの出力を使用）
            CellPrediction(
                predictedClass: .empty,
                probabilities: [0.33, 0.33, 0.34]
            )
        }
    }

    /// Softmax 関数
    private func softmax(_ logits: [Float]) -> [Float] {
        let maxLogit = logits.max() ?? 0
        let exps = logits.map { exp($0 - maxLogit) }
        let sumExp = exps.reduce(0, +)
        return exps.map { $0 / sumExp }
    }

    /// 出力テンソルを CellPrediction に変換
    private func parseOutputs(_ data: [Float], batchSize: Int) -> [CellPrediction] {
        // 出力形状: [batchSize, 3] (3クラス: upper, lower, empty)
        let numClasses = 3
        var predictions: [CellPrediction] = []

        for i in 0 ..< batchSize {
            let offset = i * numClasses
            guard offset + numClasses <= data.count else { break }

            let logits = Array(data[offset ..< offset + numClasses])
            let probabilities = softmax(logits)

            let maxIndex = probabilities.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let predictedClass: CellState = switch maxIndex {
            case 0: .upper
            case 1: .lower
            default: .empty
            }

            predictions.append(CellPrediction(
                predictedClass: predictedClass,
                probabilities: probabilities
            ))
        }

        return predictions
    }
}

// MARK: - Bundle Token

/// バンドル検出用のトークンクラス
private final class BundleToken {}
