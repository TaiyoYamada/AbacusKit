# Part 4: API設計とエラー設計

## 4.1 Public Swift API

### AbacusRecognizer (メインファサード)

```swift
/// そろばん認識エンジン
/// 
/// スレッドセーフ。複数スレッドから同時に呼び出し可能。
/// 
/// ```swift
/// let recognizer = try AbacusRecognizer(configuration: .default)
/// let result = try await recognizer.recognize(pixelBuffer: buffer)
/// print("認識結果: \(result.value)")
/// ```
public actor AbacusRecognizer {
    
    // MARK: - Initialization
    
    /// 設定を指定して初期化
    /// - Parameter configuration: 認識設定
    /// - Throws: AbacusError.invalidConfiguration
    public init(configuration: AbacusConfiguration) throws
    
    /// バンドルモデルで初期化 (デフォルト設定)
    /// - Throws: AbacusError.modelNotFound
    public convenience init() throws
    
    // MARK: - Recognition
    
    /// 単一フレームを認識
    /// - Parameter pixelBuffer: カメラフレーム (BGRA 推奨)
    /// - Returns: 認識結果
    /// - Throws: AbacusError
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> AbacusResult
    
    /// 連続認識（安定化付き）
    /// - Parameters:
    ///   - pixelBuffer: カメラフレーム
    ///   - strategy: 安定化戦略
    /// - Returns: 安定化された認識結果
    public func recognizeContinuous(
        pixelBuffer: CVPixelBuffer,
        strategy: StabilizationStrategy = .default
    ) async throws -> AbacusResult
    
    // MARK: - Configuration
    
    /// 設定を更新
    public func updateConfiguration(_ config: AbacusConfiguration) async
    
    /// 現在の設定を取得
    public var configuration: AbacusConfiguration { get async }
    
    // MARK: - Model Management
    
    /// モデルを再読み込み
    public func reloadModel() async throws
    
    /// モデルバージョン情報
    public var modelInfo: ModelInfo { get async }
}
```

### AbacusConfiguration

```swift
/// 認識エンジンの設定
public struct AbacusConfiguration: Sendable, Codable {
    
    // MARK: - Model
    
    /// モデルファイルのパス (nil = バンドル内モデル)
    public var modelPath: URL?
    
    /// 推論バックエンド
    public var inferenceBackend: InferenceBackend
    
    // MARK: - Recognition
    
    /// 認識する桁数 (1-13)
    public var digitCount: Int
    
    /// 最小そろばん検出サイズ (画面比)
    public var minFrameSizeRatio: Float
    
    /// 信頼度閾値 (0.0-1.0)
    public var confidenceThreshold: Float
    
    // MARK: - Performance
    
    /// フレームスキップ間隔 (1 = 毎フレーム)
    public var frameSkipInterval: Int
    
    /// 入力解像度制限 (長辺)
    public var maxInputResolution: Int
    
    // MARK: - Debug
    
    /// デバッグ描画を有効化
    public var enableDebugOverlay: Bool
    
    /// 処理時間ログを有効化
    public var enablePerformanceLogging: Bool
    
    // MARK: - Presets
    
    /// デフォルト設定
    public static let `default`: AbacusConfiguration
    
    /// 高精度モード (遅い)
    public static let highAccuracy: AbacusConfiguration
    
    /// 高速モード (精度低下)
    public static let fast: AbacusConfiguration
}

public enum InferenceBackend: String, Sendable, Codable {
    case coreml   // Neural Engine (推奨)
    case mps      // GPU
    case xnnpack  // CPU
    case auto     // 自動選択
}
```

### AbacusResult

```swift
/// 認識結果
public struct AbacusResult: Sendable, Equatable {
    
    /// 認識された値
    public let value: Int
    
    /// 各セルの状態
    public let cells: [CellState]
    
    /// 各桁の詳細情報
    public let digits: [DigitInfo]
    
    /// 全体信頼度 (0.0-1.0)
    public let confidence: Float
    
    /// そろばんフレームの位置 (元画像座標)
    public let frameRect: CGRect
    
    /// 処理時間 (ms)
    public let processingTimeMs: Double
    
    /// 処理時間の内訳
    public let timingBreakdown: TimingBreakdown
    
    /// タイムスタンプ
    public let timestamp: Date
}

public struct DigitInfo: Sendable, Equatable {
    /// 桁の位置 (右から0始まり)
    public let position: Int
    
    /// この桁の値 (0-9)
    public let value: Int
    
    /// 上珠の状態
    public let upperBead: CellState
    
    /// 下珠の状態 (4個)
    public let lowerBeads: [CellState]
    
    /// この桁の信頼度
    public let confidence: Float
    
    /// 元画像上のバウンディングボックス
    public let boundingBox: CGRect
}

public enum CellState: Int, Sendable, Codable {
    case upper = 0  // 上位置 (カウントしない)
    case lower = 1  // 下位置 (カウントする)
    case empty = 2  // 検出できず
}

public struct TimingBreakdown: Sendable {
    public let preprocessingMs: Double
    public let detectionMs: Double
    public let inferenceMs: Double
    public let postprocessingMs: Double
    public let totalMs: Double
}
```

---

## 4.2 エラー設計

```swift
/// AbacusKit のエラー
public enum AbacusError: Error, Sendable {
    
    // MARK: - Configuration Errors
    
    /// 無効な設定
    case invalidConfiguration(reason: String)
    
    /// モデルファイルが見つからない
    case modelNotFound(path: String)
    
    /// モデルのロードに失敗
    case modelLoadFailed(underlying: Error)
    
    // MARK: - Vision Errors
    
    /// 画像前処理に失敗
    case preprocessingFailed(reason: String, code: Int)
    
    /// そろばんフレームが検出できない
    case abacusNotDetected
    
    /// 無効な入力画像
    case invalidInput(reason: String)
    
    // MARK: - Inference Errors
    
    /// 推論に失敗
    case inferenceFailed(underlying: Error)
    
    /// モデルがロードされていない
    case modelNotLoaded
    
    // MARK: - Recognition Errors
    
    /// 信頼度が閾値未満
    case lowConfidence(confidence: Float, threshold: Float)
    
    /// セグメンテーションに失敗
    case segmentationFailed(reason: String)
}

extension AbacusError: LocalizedError {
    public var errorDescription: String? { ... }
    public var failureReason: String? { ... }
    public var recoverySuggestion: String? { ... }
}

extension AbacusError {
    /// リトライ可能か
    public var isRetryable: Bool {
        switch self {
        case .abacusNotDetected, .lowConfidence:
            return true  // 次のフレームで改善する可能性
        case .modelLoadFailed, .modelNotFound, .invalidConfiguration:
            return false // 設定変更が必要
        default:
            return false
        }
    }
}
```

---

## 4.3 StabilizationStrategy

```swift
/// 連続認識時の安定化戦略
public struct StabilizationStrategy: Sendable {
    
    /// 同じ値が連続する回数の閾値
    public var consecutiveMatchCount: Int
    
    /// 履歴ウィンドウサイズ
    public var historyWindowSize: Int
    
    /// 信頼度の重み付け
    public var confidenceWeight: Float
    
    /// デフォルト戦略
    public static let `default` = StabilizationStrategy(
        consecutiveMatchCount: 3,
        historyWindowSize: 5,
        confidenceWeight: 0.7
    )
    
    /// 高感度 (変化に素早く追従)
    public static let responsive = StabilizationStrategy(
        consecutiveMatchCount: 2,
        historyWindowSize: 3,
        confidenceWeight: 0.5
    )
    
    /// 高安定 (誤認識を防ぐ)
    public static let stable = StabilizationStrategy(
        consecutiveMatchCount: 5,
        historyWindowSize: 10,
        confidenceWeight: 0.9
    )
}
```

---

## 4.4 Model Update API (GitHub Releases)

```swift
/// モデル更新マネージャー
public actor AbacusModelUpdater {
    
    /// GitHub Releases から最新モデルをチェック
    public func checkForUpdates(
        repository: String = "owner/AbacusKit"
    ) async throws -> ModelUpdateInfo?
    
    /// モデルをダウンロード・インストール
    public func downloadAndInstall(
        updateInfo: ModelUpdateInfo,
        progress: @escaping (Double) -> Void
    ) async throws -> URL
    
    /// ローカルキャッシュをクリア
    public func clearCache() async throws
    
    /// 現在インストールされているバージョン
    public var installedVersion: String? { get async }
}

public struct ModelUpdateInfo: Sendable {
    public let version: String      // e.g., "v1.2.0"
    public let releaseDate: Date
    public let downloadURL: URL
    public let releaseNotes: String
    public let fileSize: Int64
    public let checksum: String     // SHA256
}
```

---

## 4.5 使用例

### 基本使用

```swift
import AbacusKit
import AVFoundation

class AbacusViewController: UIViewController {
    private var recognizer: AbacusRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            recognizer = try AbacusRecognizer()
        } catch {
            showError("初期化失敗: \(error)")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        Task {
            do {
                let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
                await MainActor.run {
                    updateUI(with: result)
                }
            } catch AbacusError.abacusNotDetected {
                // そろばんが見つからない → 無視
            } catch {
                print("認識エラー: \(error)")
            }
        }
    }
}
```

### カスタム設定

```swift
var config = AbacusConfiguration.default
config.digitCount = 5           // 5桁のそろばん
config.inferenceBackend = .mps  // GPU使用
config.confidenceThreshold = 0.8

let recognizer = try AbacusRecognizer(configuration: config)
```

### 連続認識 (安定化)

```swift
// 値が3回連続して同じときに確定
let result = try await recognizer.recognizeContinuous(
    pixelBuffer: buffer,
    strategy: .stable
)

if result.confidence > 0.9 {
    // 高信頼度の結果
    confirmValue(result.value)
}
```
