# AbacusKit Architecture

## Overview

AbacusKitは、iOS/iPadアプリケーション向けのリアルタイム推論SDKです。本ドキュメントでは、SDKの内部アーキテクチャ、データフロー、および設計判断について詳しく説明します。

## Design Principles

AbacusKitの設計は以下の原則に基づいています：

1. **Layered Architecture**: 関心の分離による保守性の向上
2. **Swift Concurrency**: async/awaitとActorによる安全な非同期処理
3. **Performance First**: C++層でのTensor変換による高速化
4. **Offline-First**: 初回ダウンロード後はオフラインでも動作
5. **Type Safety**: Swift 6の厳格な型システムとSendable準拠

## 6-Layer Architecture

AbacusKitは以下の6つの層で構成されています：

```
┌─────────────────────────────────────────────────────────┐
│              Application Layer                          │
│           (iOS/iPad App Code)                           │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│         Core Layer (Public API)                         │
│   Abacus, AbacusConfig, AbacusError                     │
└─────────────────────────────────────────────────────────┘
         ↓                  ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  ML Layer    │  │  Networking  │  │   Storage    │
│ TorchModule  │  │VersionChecker│  │ ModelCache   │
│ Preprocessor │  │ModelDownloader│  │ FileStorage  │
└──────────────┘  └──────────────┘  └──────────────┘
         ↓                  ↓                  ↓
┌─────────────────────────────────────────────────────────┐
│         Domain Layer (Models)                           │
│   PredictionResult, ModelVersion, AbacusMetadata        │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│         Utils Layer                                     │
│      ImageUtils, Logger                                 │
└─────────────────────────────────────────────────────────┘
```

### Layer Descriptions

#### 1. Core Layer

公開APIを提供する最上位層です。アプリケーション開発者が直接使用するインターフェースを定義します。

**Components:**
- `Abacus`: シングルトンパターンのメインクラス
- `AbacusConfig`: SDK設定（S3 URL、ローカルストレージパス）
- `AbacusError`: エラー型定義

**Responsibilities:**
- SDK初期化とモデル読み込み
- 推論実行の調整
- エラーハンドリングと伝播


#### 2. ML Layer

機械学習モデルの実行を担当する層です。C++とObjective-C++を使用してLibTorchと統合します。

**Components:**
- `TorchModule.h/mm`: Objective-C++ブリッジ
- `TorchModule.hpp/cpp`: C++実装（LibTorch統合）
- `Preprocessor.swift`: 入力検証

**Responsibilities:**
- TorchScriptモデルの読み込み
- CVPixelBufferからTensorへの変換（C++層）
- モデル推論の実行
- 出力Tensorの解析

#### 3. Networking Layer

S3からのモデル更新を管理する層です。

**Components:**
- `VersionChecker`: バージョン情報の取得
- `ModelDownloader`: モデルファイルのダウンロード

**Responsibilities:**
- version.jsonの取得とパース
- モデルファイルのダウンロード
- ネットワークエラーハンドリング

#### 4. Storage Layer

ローカルファイルシステムとの相互作用を管理する層です。

**Components:**
- `FileStorage`: ファイル操作のラッパー
- `ModelCache`: モデルメタデータのキャッシュ（Actor）

**Responsibilities:**
- ファイルの存在確認と削除
- モデルURLとバージョンのキャッシュ
- UserDefaultsへの永続化

#### 5. Domain Layer

ビジネスロジックで使用されるデータモデルを定義する層です。

**Components:**
- `PredictionResult`: 推論結果
- `ModelVersion`: モデルバージョン情報
- `AbacusMetadata`: SDKメタデータ

**Responsibilities:**
- データ構造の定義
- Codable準拠（JSON変換）
- Sendable準拠（並行性安全性）

#### 6. Utils Layer

共通ユーティリティ機能を提供する層です。

**Components:**
- `ImageUtils`: CVPixelBuffer操作
- `Logger`: デバッグログ出力

**Responsibilities:**
- 画像フォーマット変換
- ピクセルバッファ検証
- 条件付きログ出力（DEBUG時のみ）


## Data Flow Diagrams

### Inference Flow

推論実行時のデータフローを示します：

```
┌─────────────────────────────────────────────────────────┐
│  1. Camera / Image Source                               │
│     CVPixelBuffer (BGRA/RGBA format)                    │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  2. Abacus.predict(pixelBuffer:)                        │
│     - Check if model is loaded                          │
│     - Measure start time                                │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  3. Preprocessor.validate()                             │
│     - Verify pixel format (BGRA/RGBA)                   │
│     - Check buffer dimensions                           │
│     - Throw error if invalid                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  4. TorchModuleBridge.predictWithPixelBuffer()          │
│     (Objective-C++ Bridge)                              │
│     - Pass CVPixelBuffer to C++ layer                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  5. TorchModuleCpp::predict()                           │
│     (C++ Implementation)                                │
│     a. Lock CVPixelBuffer                               │
│     b. Extract raw pixel data                           │
│     c. Convert to torch::Tensor                         │
│        - Reshape to [1, C, H, W] (NCHW format)          │
│        - Normalize [0, 255] → [0.0, 1.0]                │
│     d. Execute model.forward(tensor)                    │
│     e. Extract output tensor values                     │
│     f. Unlock CVPixelBuffer                             │
│     g. Return vector<float>                             │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  6. TorchModuleBridge → Swift                           │
│     - Convert vector<float> to NSArray<NSNumber>        │
│     - Handle C++ exceptions → NSError                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  7. Abacus.predict() completion                         │
│     - Calculate inference time                          │
│     - Parse output array                                │
│     - Create PredictionResult                           │
│     - Return to caller                                  │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  8. Application                                         │
│     PredictionResult {                                  │
│       value: Int,                                       │
│       confidence: Double,                               │
│       inferenceTimeMs: Int                              │
│     }                                                   │
└─────────────────────────────────────────────────────────┘
```

**Key Points:**
- 入力検証はSwift層（Preprocessor）で実行
- Tensor変換と推論はC++層で実行（パフォーマンス最適化）
- エラーはC++ → Objective-C++ → Swiftと伝播


### Model Update Flow

モデル更新時のデータフローを示します：

```
┌─────────────────────────────────────────────────────────┐
│  1. App Launch / Manual Trigger                         │
│     Abacus.configure(config:)                           │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  2. VersionChecker.fetchRemoteVersion()                 │
│     - HTTP GET to S3 version.json                       │
│     - URLSession with async/await                       │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  3. S3 Response                                         │
│     {                                                   │
│       "version": 5,                                     │
│       "model_url": "https://s3.../model_v5.pt",         │
│       "updated_at": "2025-11-15T10:30:00Z"              │
│     }                                                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  4. Decode to ModelVersion                              │
│     - JSON → Swift struct (Codable)                     │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  5. Compare with ModelCache.currentVersion              │
│     - Actor-isolated read                               │
│     - Check if remote version > local version           │
└─────────────────────────────────────────────────────────┘
                         ↓
         ┌───────────────┴───────────────┐
         ↓                               ↓
┌──────────────────┐          ┌──────────────────┐
│  Same Version    │          │  Newer Version   │
│  Skip Download   │          │  Download Model  │
└──────────────────┘          └──────────────────┘
         ↓                               ↓
         │              ┌─────────────────────────────────┐
         │              │  6. ModelDownloader.download()  │
         │              │     - HTTP GET model.pt         │
         │              │     - Save to temp location     │
         │              │     - Validate file size        │
         │              └─────────────────────────────────┘
         │                               ↓
         │              ┌─────────────────────────────────┐
         │              │  7. FileStorage operations      │
         │              │     - Move to final location    │
         │              │     - Atomic file replacement   │
         │              │     - Delete old model          │
         │              └─────────────────────────────────┘
         │                               ↓
         │              ┌─────────────────────────────────┐
         │              │  8. ModelCache.update()         │
         │              │     - Store new URL & version   │
         │              │     - Persist to UserDefaults   │
         │              └─────────────────────────────────┘
         │                               ↓
         └──────────────────┬────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│  9. TorchModuleBridge.loadModelAtPath()                 │
│     - Load TorchScript model into memory                │
│     - Set model to eval mode                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  10. Configuration Complete                             │
│      SDK ready for inference                            │
└─────────────────────────────────────────────────────────┘
```

**Key Points:**
- バージョンチェックは毎回実行（軽量なJSON取得）
- ダウンロードは新しいバージョンがある場合のみ
- ファイル操作はアトミック（破損防止）
- キャッシュ情報はUserDefaultsに永続化（アプリ再起動後も有効）


## C++ Tensor Conversion Rationale

### Why C++ for Tensor Operations?

AbacusKitでは、CVPixelBufferからTensorへの変換をC++層で実行しています。この設計判断には以下の理由があります：

#### 1. Performance

**Swift層での変換の問題点:**
- Swift-C++境界を複数回横断するオーバーヘッド
- Swiftのメモリ管理によるコピーコスト
- 型変換のオーバーヘッド

**C++層での変換の利点:**
- LibTorchのネイティブAPIを直接使用
- ゼロコピー操作が可能
- コンパイラ最適化の恩恵

**パフォーマンス比較（推定）:**
```
Swift層変換:  CVPixelBuffer → Swift Array → C++ vector → Tensor
              ~5-10ms overhead

C++層変換:    CVPixelBuffer → Tensor (direct)
              ~1-2ms overhead
```

#### 2. Memory Efficiency

C++層での変換により、以下のメモリ効率が実現されます：

- **Direct Memory Access**: CVPixelBufferの生データに直接アクセス
- **In-Place Operations**: 可能な限りコピーを避ける
- **Automatic Memory Management**: torch::Tensorの自動メモリ管理

```cpp
// C++での効率的な変換例
void* TorchModuleCpp::pixelBufferToTensor(CVPixelBufferRef pixelBuffer) {
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    // 直接ピクセルデータにアクセス
    void* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    // ゼロコピーでTensorを作成（可能な場合）
    auto tensor = torch::from_blob(
        baseAddress,
        {1, 3, height, width},
        torch::kFloat32
    );
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return new torch::Tensor(tensor);
}
```

#### 3. Type Safety

LibTorchのC++ APIは型安全性が高く、コンパイル時にエラーを検出できます：

```cpp
// C++: コンパイル時型チェック
torch::Tensor tensor = torch::zeros({1, 3, 224, 224});
auto output = module.forward({tensor}).toTensor();  // 型安全

// Swift: 実行時エラーの可能性
let output = module.forward([tensor])  // Any型、実行時エラーのリスク
```

#### 4. LibTorch Integration

LibTorchはC++ライブラリであり、C++から使用するのが最も自然です：

- **Native API**: すべてのLibTorch機能にアクセス可能
- **Documentation**: C++ APIのドキュメントが充実
- **Community Support**: C++での使用例が豊富

### Trade-offs

この設計にはトレードオフも存在します：

**利点:**
- ✅ 高速な推論パフォーマンス
- ✅ メモリ効率の向上
- ✅ LibTorchの全機能へのアクセス

**欠点:**
- ❌ Objective-C++ブリッジの複雑性
- ❌ デバッグの難しさ（Swift ↔ C++境界）
- ❌ ビルド設定の複雑化

### Alternative Approaches Considered

#### Approach 1: Pure Swift with C API
```swift
// LibTorchのC APIを使用
let tensor = torch_tensor_from_blob(...)
```
**却下理由**: C APIは機能が限定的で、型安全性が低い

#### Approach 2: Swift Wrapper Layer
```swift
// Swift層でTensor変換を実装
struct TensorConverter {
    func convert(_ pixelBuffer: CVPixelBuffer) -> Tensor
}
```
**却下理由**: パフォーマンスオーバーヘッドが大きい

#### Approach 3: Current Approach (C++ Layer)
```cpp
// C++層で直接変換
std::vector<float> TorchModuleCpp::predict(CVPixelBufferRef pixelBuffer)
```
**採用理由**: パフォーマンスとメモリ効率のバランスが最適


## Concurrency Model

### Swift 6 Concurrency

AbacusKitはSwift 6の厳格な並行性チェックに完全準拠しています。

#### Actor Isolation

スレッドセーフな状態管理のためにActorを使用：

```swift
actor ModelCache {
    private(set) var currentModelURL: URL?
    private(set) var currentVersion: Int?
    
    func update(modelURL: URL, version: Int) async {
        self.currentModelURL = modelURL
        self.currentVersion = version
        // UserDefaultsへの永続化
    }
}

actor VersionChecker {
    func fetchRemoteVersion(from url: URL) async throws -> ModelVersion {
        // ネットワークリクエスト
    }
}
```

#### Sendable Conformance

データ型はSendableプロトコルに準拠し、並行コンテキスト間で安全に共有：

```swift
public struct PredictionResult: Sendable {
    public let value: Int
    public let confidence: Double
    public let inferenceTimeMs: Int
}

public struct AbacusConfig: Sendable {
    public let versionURL: URL
    public let modelDirectoryURL: URL
}
```

#### Async/Await

すべての非同期操作はasync/awaitを使用：

```swift
// 構造化された並行性
public func configure(config: AbacusConfig) async throws {
    let remoteVersion = try await versionChecker.fetchRemoteVersion(from: config.versionURL)
    
    if remoteVersion.version > (await modelCache.currentVersion ?? 0) {
        let localURL = try await modelDownloader.downloadModel(
            from: remoteVersion.modelURL,
            to: config.modelDirectoryURL
        )
        await modelCache.update(modelURL: localURL, version: remoteVersion.version)
    }
}
```

### Thread Safety Guarantees

- **Actor Isolation**: 共有状態への排他的アクセス
- **Sendable Types**: データ競合の防止
- **Structured Concurrency**: タスクのライフサイクル管理


## Error Handling Strategy

### Error Propagation

エラーは各層を通じて伝播し、最終的にアプリケーション層に到達します：

```
C++ Layer (torch::Error)
    ↓ (catch and convert)
Objective-C++ Bridge (NSError)
    ↓ (convert)
Swift Layer (AbacusError)
    ↓ (throw)
Application Layer (catch)
```

### Error Types

```swift
public enum AbacusError: Error, LocalizedError {
    case modelNotLoaded
    case downloadFailed(underlying: Error)
    case invalidModel(reason: String)
    case inferenceFailed(underlying: Error)
    case preprocessingFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded. Call configure() first."
        case .downloadFailed(let error):
            return "Failed to download model: \(error.localizedDescription)"
        case .invalidModel(let reason):
            return "Invalid model: \(reason)"
        case .inferenceFailed(let error):
            return "Inference failed: \(error.localizedDescription)"
        case .preprocessingFailed(let reason):
            return "Preprocessing failed: \(reason)"
        }
    }
}
```

### Recovery Strategies

| Error | Recovery Strategy |
|-------|-------------------|
| `modelNotLoaded` | Call `configure()` before `predict()` |
| `downloadFailed` | Retry with exponential backoff (future) |
| `invalidModel` | Use bundled fallback model (future) |
| `inferenceFailed` | Log and skip frame, continue processing |
| `preprocessingFailed` | Validate input format before calling |


## Testing Strategy

### Unit Tests

各層を独立してテストします：

```swift
// Core Layer Tests
final class AbacusTests: XCTestCase {
    func testConfigureLoadsModel() async throws
    func testPredictThrowsWhenNotConfigured() async throws
}

// Networking Layer Tests
final class VersionCheckerTests: XCTestCase {
    func testFetchRemoteVersionDecodesJSON() async throws
    func testHandlesNetworkError() async throws
}

// Storage Layer Tests
final class ModelCacheTests: XCTestCase {
    func testUpdateStoresModelInfo() async
    func testClearRemovesModelInfo() async
}
```

### Test Doubles

モックを使用して外部依存を排除：

```swift
// Mock URLSession for network tests
class MockURLSession: URLSession {
    var mockData: Data?
    var mockError: Error?
    
    override func data(from url: URL) async throws -> (Data, URLResponse) {
        if let error = mockError { throw error }
        return (mockData ?? Data(), URLResponse())
    }
}

// Mock TorchModule for inference tests
class MockTorchModule: TorchModuleBridge {
    var shouldSucceed = true
    
    override func predict(with pixelBuffer: CVPixelBuffer) throws -> [NSNumber] {
        if shouldSucceed {
            return [42, 0.95]  // value, confidence
        } else {
            throw NSError(domain: "test", code: -1)
        }
    }
}
```

### Integration Tests (Future)

実際のモデルとネットワークを使用したエンドツーエンドテスト：

- S3からの実際のダウンロード（テストバケット使用）
- 実際のTorchScriptモデルでの推論
- パフォーマンスベンチマーク


## Performance Optimization

### Inference Optimization

#### 1. Minimize Boundary Crossings

Swift-C++境界の横断を最小化：

```swift
// ❌ Bad: Multiple crossings
let preprocessed = preprocessor.normalize(pixelBuffer)  // Swift
let tensor = torchModule.createTensor(preprocessed)     // C++
let output = torchModule.infer(tensor)                  // C++

// ✅ Good: Single crossing
let output = torchModule.predict(pixelBuffer)           // C++ handles all
```

#### 2. Memory Management

不要なコピーを避ける：

```cpp
// ✅ Direct memory access
CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
void* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);

// Create tensor from existing memory (no copy)
auto tensor = torch::from_blob(baseAddress, {1, 3, H, W});
```

#### 3. Model Optimization

モデル自体の最適化：

- **Quantization**: FP32 → INT8（4倍のサイズ削減）
- **Pruning**: 不要な重みの削除
- **Mobile Optimization**: `torch.jit.optimize_for_mobile()`

```python
# PyTorchでのモバイル最適化
import torch
from torch.utils.mobile_optimizer import optimize_for_mobile

model = YourModel()
model.eval()

traced = torch.jit.trace(model, example_input)
optimized = optimize_for_mobile(traced)
optimized._save_for_lite_interpreter("model.ptl")
```

### Network Optimization

#### 1. Conditional Downloads

バージョンチェックによる不要なダウンロードの回避：

```swift
let remoteVersion = try await versionChecker.fetchRemoteVersion(from: url)
let localVersion = await modelCache.currentVersion ?? 0

if remoteVersion.version > localVersion {
    // Download only if newer
    try await modelDownloader.downloadModel(...)
}
```

#### 2. Background Downloads (Future)

```swift
// URLSession background configuration
let config = URLSessionConfiguration.background(withIdentifier: "com.app.model-download")
let session = URLSession(configuration: config)
```

### Memory Optimization

#### 1. Lazy Loading

モデルは必要になるまで読み込まない：

```swift
private var _torchModule: TorchModuleBridge?

var torchModule: TorchModuleBridge {
    if _torchModule == nil {
        _torchModule = TorchModuleBridge()
    }
    return _torchModule!
}
```

#### 2. Cache Management

古いモデルファイルの削除：

```swift
func cleanupOldModels() throws {
    let oldModelURL = // ... previous model URL
    try fileStorage.deleteFile(at: oldModelURL)
}
```


## Security Considerations

### Network Security

#### HTTPS Enforcement

すべてのS3通信はHTTPSを使用：

```swift
public func configure(config: AbacusConfig) async throws {
    guard config.versionURL.scheme == "https" else {
        throw AbacusError.invalidModel(reason: "Only HTTPS URLs are allowed")
    }
    // ...
}
```

#### Certificate Pinning (Future)

```swift
class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Verify certificate
    }
}
```

### Model Validation

ダウンロードしたモデルの検証：

```swift
func validateModel(at url: URL) throws {
    // 1. File size check
    let fileSize = try fileStorage.fileSize(at: url)
    guard fileSize > 0 && fileSize < 500_000_000 else {  // Max 500MB
        throw AbacusError.invalidModel(reason: "Invalid file size")
    }
    
    // 2. Format check (future: checksum verification)
    guard url.pathExtension == "pt" || url.pathExtension == "ptl" else {
        throw AbacusError.invalidModel(reason: "Invalid file format")
    }
}
```

### Data Privacy

- **No Data Collection**: SDKはユーザーデータを収集・送信しない
- **Local Processing**: すべての推論はデバイス上で実行
- **Sandboxing**: モデルはアプリのサンドボックス内に保存

### Secure Storage

```swift
// Store in app's document directory (sandboxed)
let documentsURL = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
)[0]

let modelURL = documentsURL.appendingPathComponent("models/model.pt")
```


## Future Enhancements

### Phase 2: Enhanced Functionality

#### 1. Multiple Model Support

複数のモデルを同時に管理：

```swift
public struct Abacus {
    func configure(modelID: String, config: AbacusConfig) async throws
    func predict(modelID: String, pixelBuffer: CVPixelBuffer) async throws -> PredictionResult
}

// Usage
try await abacus.configure(modelID: "classifier", config: classifierConfig)
try await abacus.configure(modelID: "detector", config: detectorConfig)

let result1 = try await abacus.predict(modelID: "classifier", pixelBuffer: buffer)
let result2 = try await abacus.predict(modelID: "detector", pixelBuffer: buffer)
```

#### 2. Model Compression

量子化モデルのサポート：

```swift
public enum ModelPrecision {
    case float32
    case float16
    case int8
}

public struct AbacusConfig {
    let precision: ModelPrecision
    // ...
}
```

#### 3. Batch Inference

複数フレームの一括処理：

```swift
func predict(pixelBuffers: [CVPixelBuffer]) async throws -> [PredictionResult] {
    // Batch processing for efficiency
}
```

#### 4. Progress Tracking

ダウンロード進捗の監視：

```swift
func configure(config: AbacusConfig, 
              progressHandler: @escaping (Double) -> Void) async throws {
    // Report download progress
}
```

### Phase 3: Advanced Features

#### 1. Push Notifications for Updates

モデル更新時の通知：

```swift
// Server sends push notification
// App downloads model in background
func application(_ application: UIApplication,
                didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
    if userInfo["type"] == "model_update" {
        Task {
            try await abacus.checkForUpdates()
        }
    }
}
```

#### 2. User-Specific Models

ユーザーIDに基づくモデル配信：

```swift
public struct AbacusConfig {
    let userID: String
    let versionURL: URL  // https://s3.../version.json?user_id={userID}
}
```

#### 3. A/B Testing

複数モデルバージョンの同時実行：

```swift
public struct ABTestConfig {
    let modelA: AbacusConfig
    let modelB: AbacusConfig
    let splitRatio: Double  // 0.0 - 1.0
}

func predict(pixelBuffer: CVPixelBuffer, 
            abTest: ABTestConfig) async throws -> PredictionResult {
    // Randomly select model based on split ratio
}
```

#### 4. Telemetry (Opt-in)

使用状況の分析：

```swift
public struct TelemetryConfig {
    let enabled: Bool
    let endpoint: URL
}

// Collect metrics
struct InferenceMetrics {
    let inferenceTime: TimeInterval
    let modelVersion: Int
    let deviceModel: String
    let timestamp: Date
}
```

#### 5. On-Device Training (Future)

デバイス上でのモデルファインチューニング：

```swift
func train(samples: [(CVPixelBuffer, Int)], 
          epochs: Int) async throws {
    // Fine-tune model on device
}
```

### Phase 4: Platform Expansion

#### 1. macOS Support

```swift
#if os(macOS)
// macOS-specific implementations
#endif
```

#### 2. visionOS Support

Apple Vision Proでの3D推論：

```swift
#if os(visionOS)
func predict(spatialBuffer: SpatialPixelBuffer) async throws -> PredictionResult
#endif
```

#### 3. watchOS Support (Lightweight)

Apple Watch向けの軽量版：

```swift
#if os(watchOS)
// Simplified API for watchOS
#endif
```


## Build Configuration

### Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AbacusKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AbacusKit",
            targets: ["AbacusKit"]
        ),
    ],
    targets: [
        .target(
            name: "AbacusKit",
            dependencies: [],
            cxxSettings: [
                .headerSearchPath("ML"),
                .define("TORCH_MOBILE", to: "1"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Accelerate"),
            ]
        ),
        .testTarget(
            name: "AbacusKitTests",
            dependencies: ["AbacusKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
```

### Xcode Build Settings

プロジェクトに以下の設定が必要です：

```
CLANG_CXX_LANGUAGE_STANDARD = c++17
CLANG_ENABLE_OBJC_ARC = YES
SWIFT_VERSION = 6.0
IPHONEOS_DEPLOYMENT_TARGET = 17.0

# LibTorch linking
OTHER_LDFLAGS = -all_load
FRAMEWORK_SEARCH_PATHS = $(PROJECT_DIR)/Frameworks
```

### LibTorch Integration

1. LibTorchフレームワークをダウンロード
2. プロジェクトの`Frameworks/`ディレクトリに配置
3. Build Phasesで`LibTorch.framework`をリンク

```bash
# Download LibTorch for iOS
wget https://download.pytorch.org/libtorch/ios/libtorch_ios_2.0.0.zip
unzip libtorch_ios_2.0.0.zip -d Frameworks/
```


## Debugging and Logging

### Logger Implementation

```swift
struct Logger {
    enum Level {
        case debug, info, warning, error
    }
    
    static func log(_ message: String, level: Level = .info) {
        #if DEBUG
        let prefix = levelPrefix(level)
        print("[\(prefix)] AbacusKit: \(message)")
        #endif
    }
    
    private static func levelPrefix(_ level: Level) -> String {
        switch level {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}
```

### Usage

```swift
// In Abacus.swift
Logger.log("Configuring SDK with version URL: \(config.versionURL)", level: .info)
Logger.log("Model loaded successfully", level: .info)
Logger.log("Inference completed in \(inferenceTime)ms", level: .debug)
Logger.log("Failed to download model: \(error)", level: .error)
```

### Debugging C++ Layer

```cpp
// In TorchModule.cpp
#ifdef DEBUG
#include <iostream>
#define LOG_DEBUG(msg) std::cout << "[C++] " << msg << std::endl
#else
#define LOG_DEBUG(msg)
#endif

std::vector<float> TorchModuleCpp::predict(CVPixelBufferRef pixelBuffer) {
    LOG_DEBUG("Starting inference");
    
    auto tensor = pixelBufferToTensor(pixelBuffer);
    LOG_DEBUG("Tensor shape: " << tensor.sizes());
    
    auto output = module->forward({tensor}).toTensor();
    LOG_DEBUG("Inference complete");
    
    return tensorToVector(output);
}
```

### Performance Profiling

Instrumentsを使用したプロファイリング：

1. **Time Profiler**: 推論時間の測定
2. **Allocations**: メモリ使用量の追跡
3. **Leaks**: メモリリークの検出

```swift
// Measure inference time
let start = CFAbsoluteTimeGetCurrent()
let result = try await abacus.predict(pixelBuffer: buffer)
let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
Logger.log("Inference took \(elapsed)ms", level: .debug)
```


## Deployment Considerations

### App Store Submission

#### 1. Binary Size

LibTorchは大きなバイナリサイズを持ちます：

- **LibTorch Framework**: ~100-150MB
- **TorchScript Model**: 10-100MB（モデルによる）

**対策:**
- App Thinningを有効化
- On-Demand Resourcesでモデルを配信
- 量子化モデルを使用してサイズ削減

#### 2. Privacy Manifest

iOS 17以降、プライバシーマニフェストが必要：

```json
{
  "NSPrivacyTracking": false,
  "NSPrivacyCollectedDataTypes": [],
  "NSPrivacyAccessedAPITypes": [
    {
      "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp",
      "NSPrivacyAccessedAPITypeReasons": ["C617.1"]
    }
  ]
}
```

#### 3. Export Compliance

機械学習モデルの輸出規制を確認：

- 暗号化機能を使用していない場合は通常問題なし
- 特定の国への配信制限を確認

### Production Checklist

- [ ] LibTorchバイナリが正しくリンクされている
- [ ] Release buildでの動作確認
- [ ] メモリリークのチェック（Instruments）
- [ ] クラッシュレポートの設定
- [ ] S3バケットのCORS設定
- [ ] S3バケットのアクセス権限
- [ ] モデルファイルのバージョン管理
- [ ] エラーハンドリングの網羅性確認
- [ ] ログ出力の本番環境での無効化確認

### Monitoring

本番環境での監視項目：

```swift
// Crash reporting
func reportCrash(_ error: Error) {
    // Send to crash reporting service
}

// Performance monitoring
struct PerformanceMetrics {
    let averageInferenceTime: TimeInterval
    let modelLoadTime: TimeInterval
    let downloadTime: TimeInterval
    let errorRate: Double
}
```


## Conclusion

AbacusKitは、パフォーマンス、保守性、安全性のバランスを取った設計になっています。

### Key Architectural Decisions

1. **6-Layer Architecture**: 明確な責任分離による保守性
2. **C++ Tensor Conversion**: パフォーマンス最適化
3. **Swift 6 Concurrency**: 型安全な並行処理
4. **Offline-First**: ネットワーク依存の最小化
5. **Actor Isolation**: スレッドセーフな状態管理

### Design Trade-offs

| Aspect | Choice | Trade-off |
|--------|--------|-----------|
| Tensor Conversion | C++ Layer | Performance ↑, Complexity ↑ |
| Model Storage | Local Cache | Offline Support ↑, Storage ↑ |
| Concurrency | Actor Model | Safety ↑, Learning Curve ↑ |
| API Design | Async/Await | Modern ↑, iOS 15+ Only |
| Error Handling | Typed Errors | Type Safety ↑, Verbosity ↑ |

### Success Metrics

- **Inference Time**: < 50ms (224x224 input)
- **Model Load Time**: < 500ms
- **Memory Usage**: < 100MB
- **Crash Rate**: < 0.1%
- **Download Success Rate**: > 99%

### Next Steps

1. 実装の完了とテスト
2. パフォーマンスベンチマーク
3. ドキュメントの充実
4. サンプルアプリの作成
5. Phase 2機能の計画

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-15  
**Authors**: AbacusKit Team
