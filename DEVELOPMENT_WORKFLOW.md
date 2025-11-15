# AbacusKit Development Workflow

## Overview

このドキュメントでは、AbacusKit の開発からリリースまでの推奨ワークフローを説明します。

## 開発環境のセットアップ

### 必要なツール

- Xcode 16.0+
- Swift 6.0+
- LibTorch iOS binary (オプション、推論テスト用)

### プロジェクトのクローン

```bash
git clone https://github.com/your-org/AbacusKit.git
cd AbacusKit
```

### 依存関係の確認

```bash
# Package.swift の検証
swift package describe

# ビルドテスト（LibTorch なしでも構造確認可能）
swift build
```

## ターゲット別開発ガイド

### AbacusKit (Swift) の開発

Swift のみのコードを扱う場合は、`Sources/AbacusKit/` で作業します。

#### 開発対象

- Core Layer: 公開API
- ML Layer: Preprocessor（入力検証）
- Networking Layer: S3通信
- Storage Layer: ローカルストレージ
- Domain Layer: データモデル
- Utils Layer: ユーティリティ

#### 開発フロー

1. **ファイル編集**
   ```bash
   # 例: Preprocessor の機能追加
   vim Sources/AbacusKit/ML/Preprocessor.swift
   ```

2. **ビルド確認**
   ```bash
   swift build --target AbacusKit
   ```

3. **テスト実行**
   ```bash
   swift test --filter PreprocessorTests
   ```

4. **診断確認**
   ```bash
   # Xcode で開く
   open Package.swift
   
   # または swift-format でフォーマット
   swift-format -i Sources/AbacusKit/**/*.swift
   ```

### AbacusKitBridge (C++/ObjC++) の開発

C++/Objective-C++ コードを扱う場合は、`Sources/AbacusKitBridge/` で作業します。

#### 開発対象

- TorchModule.h: Public header
- TorchModule.mm: ObjC++ bridge
- TorchModule.hpp: C++ header
- TorchModule.cpp: C++ implementation

#### 開発フロー

1. **ファイル編集**
   ```bash
   # 例: Tensor 変換の最適化
   vim Sources/AbacusKitBridge/TorchModule.cpp
   ```

2. **ビルド確認**
   ```bash
   # LibTorch がリンクされている場合
   swift build --target AbacusKitBridge
   
   # LibTorch なしの場合（構文チェックのみ）
   clang++ -std=c++17 -fsyntax-only Sources/AbacusKitBridge/TorchModule.cpp
   ```

3. **ヘッダー変更時の注意**
   ```bash
   # TorchModule.h を変更した場合、Swift 側も影響を受ける
   swift build  # 全体ビルドで確認
   ```

## テスト戦略

### Unit Tests

各層を独立してテストします。

#### Swift Layer Tests

```bash
# 全テスト実行
swift test

# 特定のテストクラスのみ
swift test --filter AbacusTests

# 特定のテストメソッドのみ
swift test --filter AbacusTests.testConfigureLoadsModel
```

#### Test 作成例

```swift
// Tests/AbacusKitTests/PreprocessorTests.swift
import XCTest
@testable import AbacusKit

final class PreprocessorTests: XCTestCase {
    func testValidateAcceptsBGRAFormat() throws {
        let preprocessor = Preprocessor()
        let pixelBuffer = createMockPixelBuffer(format: kCVPixelFormatType_32BGRA)
        
        XCTAssertNoThrow(try preprocessor.validate(pixelBuffer))
    }
    
    func testValidateRejectsInvalidFormat() throws {
        let preprocessor = Preprocessor()
        let pixelBuffer = createMockPixelBuffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        
        XCTAssertThrowsError(try preprocessor.validate(pixelBuffer)) { error in
            guard case AbacusError.preprocessingFailed = error else {
                XCTFail("Expected preprocessingFailed error")
                return
            }
        }
    }
}
```

### Integration Tests

実際の LibTorch を使用したエンドツーエンドテスト。

```swift
// Tests/AbacusKitTests/IntegrationTests.swift
final class IntegrationTests: XCTestCase {
    func testFullInferencePipeline() async throws {
        // LibTorch がリンクされている環境でのみ実行
        #if LIBTORCH_AVAILABLE
        let abacus = Abacus.shared
        let config = AbacusConfig(
            versionURL: URL(string: "https://test-bucket.s3.amazonaws.com/version.json")!,
            modelDirectoryURL: FileManager.default.temporaryDirectory
        )
        
        try await abacus.configure(config: config)
        
        let pixelBuffer = createTestPixelBuffer()
        let result = try await abacus.predict(pixelBuffer: pixelBuffer)
        
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThan(result.inferenceTimeMs, 1000)
        #endif
    }
}
```

### Performance Tests

パフォーマンスベンチマーク。

```swift
final class PerformanceTests: XCTestCase {
    func testInferencePerformance() throws {
        let abacus = Abacus.shared
        let pixelBuffer = createTestPixelBuffer()
        
        measure {
            Task {
                _ = try? await abacus.predict(pixelBuffer: pixelBuffer)
            }
        }
    }
}
```

## コードスタイル

### Swift

Swift の標準スタイルガイドに従います。

```swift
// ✅ Good
public func configure(config: AbacusConfig) async throws {
    let remoteVersion = try await versionChecker.fetchRemoteVersion(from: config.versionURL)
    // ...
}

// ❌ Bad
public func configure(config:AbacusConfig)async throws{
    let remoteVersion=try await versionChecker.fetchRemoteVersion(from:config.versionURL)
    // ...
}
```

### C++

Google C++ Style Guide に従います。

```cpp
// ✅ Good
std::vector<float> TorchModuleCpp::predict(CVPixelBufferRef pixelBuffer) {
    if (!module) {
        throw std::runtime_error("Model not loaded");
    }
    // ...
}

// ❌ Bad
std::vector<float> TorchModuleCpp::predict(CVPixelBufferRef pixelBuffer)
{
    if(!module)
    {
        throw std::runtime_error("Model not loaded");
    }
    // ...
}
```

## Git Workflow

### ブランチ戦略

```
main
├── develop
│   ├── feature/add-batch-inference
│   ├── feature/improve-preprocessor
│   └── bugfix/fix-memory-leak
└── release/v1.0.0
```

### コミットメッセージ

```bash
# Feature
git commit -m "feat: Add batch inference support"

# Bug fix
git commit -m "fix: Resolve memory leak in TorchModule"

# Documentation
git commit -m "docs: Update ARCHITECTURE.md with new flow"

# Refactor
git commit -m "refactor: Simplify Preprocessor validation logic"

# Test
git commit -m "test: Add unit tests for ModelCache"
```

### Pull Request

1. **ブランチ作成**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **変更をコミット**
   ```bash
   git add .
   git commit -m "feat: Your feature description"
   ```

3. **テスト実行**
   ```bash
   swift test
   ```

4. **プッシュ**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **PR 作成**
   - GitHub で Pull Request を作成
   - テンプレートに従って説明を記入
   - レビュアーを指定

### PR チェックリスト

- [ ] すべてのテストが通過
- [ ] コードスタイルに準拠
- [ ] ドキュメントを更新（必要な場合）
- [ ] CHANGELOG.md を更新
- [ ] Breaking changes がある場合は明記

## リリースプロセス

### バージョニング

Semantic Versioning (SemVer) に従います。

```
MAJOR.MINOR.PATCH

例:
1.0.0 - Initial release
1.1.0 - New feature (backward compatible)
1.1.1 - Bug fix
2.0.0 - Breaking change
```

### リリース手順

#### 1. リリースブランチ作成

```bash
git checkout develop
git pull origin develop
git checkout -b release/v1.1.0
```

#### 2. バージョン更新

```bash
# Package.swift のバージョンを更新（必要な場合）
# CHANGELOG.md を更新
vim CHANGELOG.md
```

```markdown
# Changelog

## [1.1.0] - 2025-11-15

### Added
- Batch inference support
- Model compression options

### Fixed
- Memory leak in TorchModule
- Preprocessor validation edge case

### Changed
- Improved error messages
```

#### 3. 最終テスト

```bash
# クリーンビルド
swift package clean
swift build

# 全テスト実行
swift test

# パフォーマンステスト
swift test --filter PerformanceTests
```

#### 4. マージと タグ付け

```bash
# develop にマージ
git checkout develop
git merge release/v1.1.0

# main にマージ
git checkout main
git merge develop

# タグ作成
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin main --tags
```

#### 5. GitHub Release 作成

1. GitHub の Releases ページに移動
2. "Create a new release" をクリック
3. タグを選択: `v1.1.0`
4. リリースノートを記入（CHANGELOG.md から）
5. "Publish release" をクリック

### リリース後

```bash
# develop ブランチに戻る
git checkout develop

# 次のバージョンの準備
# ...
```

## CI/CD

### GitHub Actions

`.github/workflows/ci.yml` の例：

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Swift
      uses: swift-actions/setup-swift@v1
      with:
        swift-version: '6.0'
    
    - name: Build
      run: swift build
    
    - name: Run tests
      run: swift test
    
    - name: Check code style
      run: swift-format lint -r Sources/
```

### 自動テスト

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Run unit tests
      run: swift test --filter ".*Tests"
    
    - name: Generate coverage
      run: swift test --enable-code-coverage
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

## トラブルシューティング

### ビルドエラー

#### "Cannot find 'TorchModuleBridge' in scope"

```swift
// Abacus.swift に追加
import AbacusKitBridge
```

#### "torch/script.h file not found"

これは正常です。LibTorch は手動でリンクする必要があります。

```bash
# 開発中は無視して OK
# 実際のアプリでは README.md の LibTorch Setup を参照
```

### テストエラー

#### "Model not loaded"

```swift
// テストで configure() を呼び出す
try await abacus.configure(config: testConfig)
```

#### "Pixel buffer is null"

```swift
// モック CVPixelBuffer を作成
func createMockPixelBuffer() -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        224, 224,
        kCVPixelFormatType_32BGRA,
        nil,
        &pixelBuffer
    )
    return pixelBuffer!
}
```

## ベストプラクティス

### 1. 小さなコミット

```bash
# ✅ Good
git commit -m "feat: Add pixel format validation"
git commit -m "test: Add tests for pixel format validation"
git commit -m "docs: Update Preprocessor documentation"

# ❌ Bad
git commit -m "Add feature, fix bugs, update docs"
```

### 2. テスト駆動開発 (TDD)

```swift
// 1. テストを書く
func testNewFeature() {
    XCTAssertEqual(newFeature(), expectedResult)
}

// 2. 実装する
func newFeature() -> Result {
    // implementation
}

// 3. リファクタリング
func newFeature() -> Result {
    // improved implementation
}
```

### 3. ドキュメント更新

コードを変更したら、必ずドキュメントも更新します。

```bash
# コード変更
vim Sources/AbacusKit/Core/Abacus.swift

# ドキュメント更新
vim README.md
vim Docs/ARCHITECTURE.md
```

### 4. パフォーマンス測定

新機能を追加したら、パフォーマンスへの影響を測定します。

```swift
func testNewFeaturePerformance() {
    measure {
        // new feature execution
    }
}
```

## まとめ

### 日常的な開発フロー

1. ブランチ作成: `git checkout -b feature/your-feature`
2. コード編集: `vim Sources/AbacusKit/...`
3. ビルド: `swift build`
4. テスト: `swift test`
5. コミット: `git commit -m "feat: ..."`
6. プッシュ: `git push origin feature/your-feature`
7. PR 作成

### リリースフロー

1. リリースブランチ: `git checkout -b release/vX.Y.Z`
2. バージョン更新: CHANGELOG.md
3. 最終テスト: `swift test`
4. マージ: `develop` → `main`
5. タグ: `git tag vX.Y.Z`
6. GitHub Release

### 推奨ツール

- **Xcode**: メイン IDE
- **swift-format**: コードフォーマット
- **SwiftLint**: コードスタイルチェック
- **Instruments**: パフォーマンスプロファイリング
- **GitHub Actions**: CI/CD

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-15  
**Author**: AbacusKit Team
