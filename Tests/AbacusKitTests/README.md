# AbacusKit Tests

このディレクトリにはAbacusKitのテストスイートが含まれています。

## テストフレームワーク

- **Quick**: BDD形式のテストフレームワーク
- **Nimble**: 表現力豊かなマッチャーライブラリ
- **Cuckoo**: プロトコルベースのモック自動生成

## モック生成

Cuckooを使用してプロトコルのモックを自動生成します。

### モック生成の実行

```bash
# Swift Package Managerでビルド時に自動生成
swift build

# または手動で生成
swift run cuckoo generate \
  --testable AbacusKit \
  --output Tests/AbacusKitTests/Generated
```

### 生成されるモック

以下のプロトコルのモックが自動生成されます：

- `MockModelManager`
- `MockModelUpdater`
- `MockModelVersionAPI`
- `MockS3Downloader`
- `MockFileStorage`
- `MockModelCache`
- `MockPreprocessor`

## テストの実行

```bash
# すべてのテストを実行
swift test

# 特定のテストを実行
swift test --filter ModelVersionSpec

# 詳細な出力
swift test --verbose
```

## テストの構造

```
Tests/AbacusKitTests/
├── Core/
│   └── AbacusConfigTests.swift
├── Domain/
│   └── ModelVersionTests.swift
├── ML/
│   └── PreprocessorTests.swift
├── Networking/
│   └── ModelVersionAPITests.swift
├── Storage/
│   └── ModelCacheTests.swift
├── Generated/              # Cuckooが自動生成
│   └── GeneratedMocks.swift
├── AbacusTests.swift
├── GenerateMocks.swift     # モック生成マーカー
└── README.md
```

## モックの使用例

```swift
import Cuckoo
@testable import AbacusKit

class MyTests: QuickSpec {
    override class func spec() {
        describe("MyFeature") {
            var mockModelManager: MockModelManager!
            
            beforeEach {
                mockModelManager = MockModelManager()
            }
            
            it("should perform inference") {
                // モックの振る舞いを設定
                stub(mockModelManager) { stub in
                    when(stub.predict(pixelBuffer: any())).thenReturn([42.0, 0.95])
                }
                
                // テスト実行
                waitUntil { done in
                    Task {
                        let result = try await mockModelManager.predict(pixelBuffer: pixelBuffer)
                        expect(result).to(equal([42.0, 0.95]))
                        done()
                    }
                }
                
                // 呼び出しを検証
                verify(mockModelManager).predict(pixelBuffer: any())
            }
        }
    }
}
```

## ベストプラクティス

1. **Given-When-Then**: テストを明確な3つのフェーズに分ける
2. **1テスト1アサーション**: 各テストは1つの振る舞いのみを検証
3. **モックの分離**: 各テストで新しいモックインスタンスを使用
4. **非同期テスト**: `waitUntil`を使用して非同期処理を適切に待機
5. **意味のある名前**: テストケース名は振る舞いを明確に表現

## トラブルシューティング

### モックが生成されない

```bash
# キャッシュをクリーンアップ
swift package clean
swift build
```

### テストがタイムアウトする

```swift
// タイムアウト時間を延長
waitUntil(timeout: .seconds(10)) { done in
    // ...
}
```

### モックの振る舞いが期待通りでない

```swift
// デバッグ出力を有効化
stub(mockModelManager) { stub in
    when(stub.predict(pixelBuffer: any())).then { _ in
        print("Mock called!")
        return [42.0, 0.95]
    }
}
```
