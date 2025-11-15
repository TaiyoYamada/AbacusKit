# AbacusKit Architecture

## Overview

AbacusKitは、iOS/iPadアプリケーション向けのリアルタイム推論SDKです。本ドキュメントでは、SDKの内部アーキテクチャ、データフロー、および設計判断について詳しく説明します。

## Design Principles

AbacusKitの設計は以下の原則に基づいています：

1. **Layered Architecture**: 関心の分離による保守性の向上
2. **Target Separation**: Swift と C++ の明確な分離
3. **Swift Concurrency**: async/awaitとActorによる安全な非同期処理
4. **Performance First**: C++層でのTensor変換による高速化
5. **Offline-First**: 初回ダウンロード後はオフラインでも動作
6. **Type Safety**: Swift 6の厳格な型システムとSendable準拠

## Target Architecture

AbacusKitは2つの独立したターゲットで構成されています：

### Target 1: AbacusKit (Swift)

Swift のみで実装されたメインSDKターゲット。

```
AbacusKit (Swift Target)
├── Core Layer
│   ├── Abacus.swift          # Main SDK interface
│   ├── AbacusConfig.swift    # Configuration
│   └── AbacusError.swift     # Error types
├── ML Layer
│   └── Preprocessor.swift    # Input validation
├── Networking Layer
│   ├── VersionChecker.swift  # S3 version check
│   └── ModelDownloader.swift # Model download
├── Storage Layer
│   ├── ModelCache.swift      # Model metadata cache
│   └── FileStorage.swift     # File operations
├── Domain Layer
│   ├── PredictionResult.swift
│   ├── ModelVersion.swift
│   └── AbacusMetadata.swift
└── Utils Layer
    ├── Logger.swift
    └── ImageUtils.swift
```

### Target 2: AbacusKitBridge (Objective-C++/C++)

LibTorch との統合を担当するブリッジターゲット。

```
AbacusKitBridge (ObjC++/C++ Target)
├── include/
│   └── TorchModule.h         # Public ObjC header
├── TorchModule.mm            # ObjC++ bridge implementation
├── TorchModule.hpp           # C++ header
└── TorchModule.cpp           # C++ implementation (LibTorch)
```

### Why Separate Targets?

Swift Package Manager は、Swift と Objective-C++/C++ を同一ターゲット内で混在させることをサポートしていません。

**問題:**
```
❌ AbacusKit (Single Target)
   ├── Abacus.swift           # Swift
   ├── TorchModule.mm         # Objective-C++
   └── TorchModule.cpp        # C++
   
   → Build Error: "Cannot use Objective-C++ with Swift in the same target"
```

**解決策:**
```
✅ AbacusKit (Swift Target)
   └── Abacus.swift           # Swift only

✅ AbacusKitBridge (ObjC++/C++ Target)
   ├── TorchModule.mm         # Objective-C++
   └── TorchModule.cpp        # C++
   
   → AbacusKit depends on AbacusKitBridge
```

**メリット:**
- ✅ SPM のビルドエラーを回避
- ✅ 明確な責任分離（Swift = ビジネスロジック、C++ = ML実行）
- ✅ Swift と C++ の境界が明確
- ✅ 保守性の向上
- ✅ テストの容易性

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
│   [AbacusKit Target - Swift]                            │
└─────────────────────────────────────────────────────────┘
         ↓                  ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  ML Layer    │  │  Networking  │  │   Storage    │
│ Preprocessor │  │VersionChecker│  │ ModelCache   │
│   [Swift]    │  │ModelDownloader│  │ FileStorage  │
│      +       │  │   [Swift]    │  │   [Swift]    │
│ TorchModule  │  └──────────────┘  └──────────────┘
│ [ObjC++/C++] │
│  (Bridge)    │
└──────────────┘
         ↓                  ↓                  ↓
┌─────────────────────────────────────────────────────────┐
│         Domain Layer (Models)                           │
│   PredictionResult, ModelVersion, AbacusMetadata        │
│   [AbacusKit Target - Swift]                            │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│         Utils Layer                                     │
│      ImageUtils, Logger                                 │
│   [AbacusKit Target - Swift]                            │
└─────────────────────────────────────────────────────────┘
```

### Layer Descriptions

#### 1. Core Layer (Swift)

公開APIを提供する最上位層です。アプリケーション開発者が直接使用するインターフェースを定義します。

**Components:**
- `Abacus`: シングルトンパターンのメインクラス
- `AbacusConfig`: SDK設定（S3 URL、ローカルストレージパス）
- `AbacusError`: エラー型定義

**Responsibilities:**
- SDK初期化とモデル読み込み
- 推論実行の調整
- エラーハンドリングと伝播
- AbacusKitBridge との連携

**Target**: AbacusKit (Swift)

#### 2. ML Layer (Swift + Bridge)

機械学習モデルの実行を担当する層です。Swift と C++ の2つのコンポーネントで構成されます。

**Swift Component (AbacusKit Target):**
- `Preprocessor.swift`: 入力検証

**Bridge Component (AbacusKitBridge Target):**
- `TorchModule.h`: Objective-C ブリッジヘッダー（public）
- `TorchModule.mm`: Objective-C++ 実装
- `TorchModule.hpp`: C++ ヘッダー
- `TorchModule.cpp`: C++ 実装（LibTorch統合）

**Responsibilities:**
- CVPixelBuffer の形式検証（Swift）
- TorchScriptモデルの読み込み（C++）
- CVPixelBufferからTensorへの変換（C++）
- モデル推論の実行（C++）
- 出力Tensorの解析（C++）

**Data Flow:**
```
Swift (Preprocessor) → ObjC++ (Bridge) → C++ (LibTorch) → ObjC++ → Swift
```

#### 3. Networking Layer (Swift)

S3からのモデル更新を管理する層です。

**Components:**
- `VersionChecker`: バージョン情報の取得
- `ModelDownloader`: モデルファイルのダウンロード

**Responsibilities:**
- version.jsonの取得とパース
- モデルファイルのダウンロード
- ネットワークエラーハンドリング

**Target**: AbacusKit (Swift)

#### 4. Storage Layer (Swift)

ローカルファイルシステムとの相互作用を管理する層です。

**Components:**
- `FileStorage`: ファイル操作のラッパー
- `ModelCache`: モデルメタデータのキャッシュ（Actor）

**Responsibilities:**
- ファイルの存在確認と削除
- モデルURLとバージョンのキャッシュ
- UserDefaultsへの永続化

**Target**: AbacusKit (Swift)

#### 5. Domain Layer (Swift)

ビジネスロジックで使用されるデータモデルを定義する層です。

**Components:**
- `PredictionResult`: 推論結果
- `ModelVersion`: モデルバージョン情報
- `AbacusMetadata`: SDKメタデータ

**Responsibilities:**
- データ構造の定義
- Codable準拠（JSON変換）
- Sendable準拠（並行性安全性）

**Target**: AbacusKit (Swift)

#### 6. Utils Layer (Swift)

共通ユーティリティ機能を提供する層です。

**Components:**
- `ImageUtils`: CVPixelBuffer操作
- `Logger`: デバッグログ出力

**Responsibilities:**
- 画像フォーマット変換
- ピクセルバッファ検証
- 条件付きログ出力（DEBUG時のみ）

**Target**: AbacusKit (Swift)

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
│  2. Abacus.predict(pixelBuffer:) [Swift]                │
│     Target: AbacusKit                                   │
│     - Check if model is loaded                          │
│     - Measure start time                                │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  3. Preprocessor.validate() [Swift]                     │
│     Target: AbacusKit                                   │
│     - Verify pixel format (BGRA/RGBA)                   │
│     - Check buffer dimensions                           │
│     - Throw error if invalid                            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  4. TorchModuleBridge.predictWithPixelBuffer()          │
│     Target: AbacusKitBridge (Objective-C++)             │
│     - Swift → ObjC++ boundary crossing                  │
│     - Pass CVPixelBuffer to C++ layer                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  5. TorchModuleCpp::predict() [C++]                     │
│     Target: AbacusKitBridge                             │
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
│     Target: AbacusKitBridge → AbacusKit                 │
│     - Convert vector<float> to NSArray<NSNumber>        │
│     - Handle C++ exceptions → NSError                   │
│     - ObjC++ → Swift boundary crossing                  │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  7. Abacus.predict() completion [Swift]                 │
│     Target: AbacusKit                                   │
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
- Tensor変換と推論はC++層（AbacusKitBridge）で実行（パフォーマンス最適化）
- Swift ↔ ObjC++ の境界は2回のみ（最小化）
- エラーはC++ → Objective-C++ → Swiftと伝播

### Model Update Flow

モデル更新時のデータフローを示します（すべて Swift 層で完結）：

```
┌─────────────────────────────────────────────────────────┐
│  1. App Launch / Manual Trigger                         │
│     Abacus.configure(config:) [Swift]                   │
│     Target: AbacusKit                                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  2. VersionChecker.fetchRemoteVersion() [Swift]         │
│     Target: AbacusKit                                   │
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
│  4. Decode to ModelVersion [Swift]                      │
│     Target: AbacusKit                                   │
│     - JSON → Swift struct (Codable)                     │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  5. Compare with ModelCache.currentVersion [Swift]      │
│     Target: AbacusKit                                   │
│     - Actor-isolated read                               │
│     - Check if remote version > local version           │
└─────────────────────────────────────────────────────────┘
                         ↓
         ┌───────────────┴───────────────┐
         ↓                               ↓
┌──────────────────┐          ┌──────────────────┐
│  Same Version    │          │  Newer Version   │
│  Skip Download   │          │  Download Model  │
│    [Swift]       │          │    [Swift]       │
└──────────────────┘          └──────────────────┘
         ↓                               ↓
         │              ┌─────────────────────────────────┐
         │              │  6. ModelDownloader.download()  │
         │              │     Target: AbacusKit [Swift]   │
         │              │     - HTTP GET model.pt         │
         │              │     - Save to temp location     │
         │              │     - Validate file size        │
         │              └─────────────────────────────────┘
         │                               ↓
         │              ┌─────────────────────────────────┐
         │              │  7. FileStorage operations      │
         │              │     Target: AbacusKit [Swift]   │
         │              │     - Move to final location    │
         │              │     - Atomic file replacement   │
         │              │     - Delete old model          │
         │              └─────────────────────────────────┘
         │                               ↓
         │              ┌─────────────────────────────────┐
         │              │  8. ModelCache.update()         │
         │              │     Target: AbacusKit [Swift]   │
         │              │     - Store new URL & version   │
         │              │     - Persist to UserDefaults   │
         │              └─────────────────────────────────┘
         │                               ↓
         └──────────────────┬────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│  9. TorchModuleBridge.loadModelAtPath()                 │
│     Target: AbacusKitBridge [ObjC++]                    │
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
- バージョンチェックとダウンロードは Swift 層で完結
- C++ 層（AbacusKitBridge）はモデル読み込みのみ担当
- ファイル操作はアトミック（破損防止）
- キャッシュ情報はUserDefaultsに永続化


## C++ Tensor Conversion Rationale

### Why C++ for Tensor Operations?

AbacusKitでは、CVPixelBufferからTensorへの変換を C++ 層（AbacusKitBridge）で実行しています。この設計判断には以下の理由があります：

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
// AbacusKitBridge/TorchModule.cpp での効率的な変換
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
- ✅ 明確なターゲット分離（SPM準拠）

**欠点:**
- ❌ Objective-C++ブリッジの複雑性
- ❌ デバッグの難しさ（Swift ↔ C++境界）
- ❌ ビルド設定の複雑化
- ❌ 2つのターゲット管理が必要

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

#### Approach 3: Current Approach (Separate C++ Target)
```cpp
// AbacusKitBridge ターゲットで直接変換
std::vector<float> TorchModuleCpp::predict(CVPixelBufferRef pixelBuffer)
```
**採用理由**: パフォーマンス、メモリ効率、SPM準拠のバランスが最適

## Package.swift Configuration

### Target Structure

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AbacusKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AbacusKit", targets: ["AbacusKit"]),
    ],
    targets: [
        // Swift Target
        .target(
            name: "AbacusKit",
            dependencies: ["AbacusKitBridge"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        
        // Objective-C++/C++ Bridge Target
        .target(
            name: "AbacusKitBridge",
            dependencies: [],
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-std=c++17"]),
            ]
        ),
        
        // Test Target
        .testTarget(
            name: "AbacusKitTests",
            dependencies: ["AbacusKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
```

### Key Configuration Points

1. **Target Dependencies**:
   - `AbacusKit` depends on `AbacusKitBridge`
   - `AbacusKitBridge` has no dependencies (standalone)

2. **Public Headers**:
   - `publicHeadersPath: "include"` で TorchModule.h を公開
   - Swift から `import AbacusKitBridge` でアクセス可能

3. **C++ Standard**:
   - `cxxLanguageStandard: .cxx17` でパッケージ全体に適用
   - LibTorch は C++17 を要求

4. **Swift Settings**:
   - `StrictConcurrency` で Swift 6 の並行性チェックを有効化

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
- **C++ Layer**: Swift の並行性モデルから独立（同期的に実行）

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

### Bridge Layer Testing

AbacusKitBridge のテストは、実際の LibTorch バイナリが必要です：

```swift
// Integration test with real LibTorch
final class TorchModuleBridgeTests: XCTestCase {
    func testLoadModelSucceeds() throws {
        let bridge = TorchModuleBridge()
        let modelPath = Bundle.module.path(forResource: "test_model", ofType: "pt")!
        
        var error: NSError?
        let success = bridge.loadModel(atPath: modelPath, error: &error)
        
        XCTAssertTrue(success)
        XCTAssertNil(error)
    }
}
```

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
// ✅ Direct memory access in AbacusKitBridge/TorchModule.cpp
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

### Model Validation

ダウンロードしたモデルの検証：

```swift
func validateModel(at url: URL) throws {
    // 1. File size check
    let fileSize = try fileStorage.fileSize(at: url)
    guard fileSize > 0 && fileSize < 500_000_000 else {  // Max 500MB
        throw AbacusError.invalidModel(reason: "Invalid file size")
    }
    
    // 2. Format check
    guard url.pathExtension == "pt" || url.pathExtension == "ptl" else {
        throw AbacusError.invalidModel(reason: "Invalid file format")
    }
}
```

### Data Privacy

- **No Data Collection**: SDKはユーザーデータを収集・送信しない
- **Local Processing**: すべての推論はデバイス上で実行
- **Sandboxing**: モデルはアプリのサンドボックス内に保存

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

### Debugging C++ Layer

```cpp
// In AbacusKitBridge/TorchModule.cpp
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

## Future Enhancements

### Phase 2: Enhanced Functionality

#### 1. Multiple Model Support

複数のモデルを同時に管理：

```swift
public struct Abacus {
    func configure(modelID: String, config: AbacusConfig) async throws
    func predict(modelID: String, pixelBuffer: CVPixelBuffer) async throws -> PredictionResult
}
```

#### 2. Model Compression

量子化モデルのサポート：

```swift
public enum ModelPrecision {
    case float32
    case float16
    case int8
}
```

#### 3. Batch Inference

複数フレームの一括処理：

```swift
func predict(pixelBuffers: [CVPixelBuffer]) async throws -> [PredictionResult]
```

### Phase 3: Platform Expansion

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

## Conclusion

AbacusKitは、パフォーマンス、保守性、安全性のバランスを取った設計になっています。

### Key Architectural Decisions

1. **2-Target Architecture**: Swift と C++ の明確な分離（SPM準拠）
2. **C++ Tensor Conversion**: パフォーマンス最適化
3. **Swift 6 Concurrency**: 型安全な並行処理
4. **Offline-First**: ネットワーク依存の最小化
5. **Actor Isolation**: スレッドセーフな状態管理

### Design Trade-offs

| Aspect | Choice | Trade-off |
|--------|--------|-----------|
| Target Structure | 2 Targets | SPM準拠 ↑, 管理複雑性 ↑ |
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

**Document Version**: 2.0  
**Last Updated**: 2025-11-15  
**Authors**: AbacusKit Team
