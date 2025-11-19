# Contributing to AbacusKit

AbacusKitへの貢献を歓迎します！このガイドでは、プロジェクトへの貢献方法について説明します。

## 開発環境のセットアップ

### 必要な環境

- macOS 14.0以上
- Xcode 16.0以上
- Swift 6.0以上

### セットアップ手順

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/AbacusKit.git
cd AbacusKit

# 依存関係を解決
make setup

# モックを生成
make mocks

# ビルド
make build

# テストを実行
make test
```

## 開発ワークフロー

### 1. ブランチの作成

```bash
# 新機能の場合
git checkout -b feature/your-feature-name

# バグ修正の場合
git checkout -b fix/bug-description
```

### 2. コーディング規約

#### Swift Style Guide

- Swift API Design Guidelinesに従う
- SwiftLintの設定に準拠
- 命名規則:
  - クラス/構造体: PascalCase
  - メソッド/変数: camelCase
  - プロトコル: 名詞または形容詞
  - 定数: camelCase

#### アーキテクチャ原則

- **SOLID原則**を遵守
- **Clean Architecture**のレイヤー分離を維持
- すべての依存関係は**プロトコル経由**
- **Dependency Injection**を使用

#### ドキュメント

すべてのpublic APIには**SwiftDocC**形式のドキュメントを記述：

```swift
/// メソッドの概要
///
/// 詳細な説明をここに記述します。
///
/// - Parameters:
///   - param1: パラメータの説明
///   - param2: パラメータの説明
/// - Returns: 戻り値の説明
/// - Throws: スローされるエラーの説明
public func myMethod(param1: String, param2: Int) throws -> Result {
    // 実装
}
```

実装の詳細には日本語コメントを使用可能：

```swift
// ここでモデルをキャッシュから読み込む
let cachedModel = await cache.getCurrentModelURL()
```

### 3. テストの作成

#### テストの必須要件

- すべての新機能にはテストが必要
- テストカバレッジは80%以上を維持
- Quick/Nimbleを使用したBDDスタイル
- Cuckooでモックを生成

#### テストの書き方

```swift
import Quick
import Nimble
import Cuckoo
@testable import AbacusKit

final class MyFeatureSpec: QuickSpec {
    override class func spec() {
        describe("MyFeature") {
            var sut: MyFeature!
            var mockDependency: MockDependency!
            
            beforeEach {
                mockDependency = MockDependency()
                sut = MyFeature(dependency: mockDependency)
            }
            
            context("when condition X") {
                it("should do Y") {
                    // Given
                    stub(mockDependency) { stub in
                        when(stub.someMethod()).thenReturn(expectedValue)
                    }
                    
                    // When
                    let result = sut.performAction()
                    
                    // Then
                    expect(result).to(equal(expectedValue))
                    verify(mockDependency).someMethod()
                }
            }
        }
    }
}
```

#### モックの生成

新しいプロトコルを追加した場合：

```bash
# モックを再生成
make mocks

# テストを実行して確認
make test
```

### 4. コミット

#### コミットメッセージ規約

Conventional Commitsに従う：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type:**
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（フォーマットなど）
- `refactor`: バグ修正や機能追加を伴わないコード変更
- `test`: テストの追加や修正
- `chore`: ビルドプロセスやツールの変更

**例:**

```bash
git commit -m "feat(ml): add model preloading support"
git commit -m "fix(networking): handle timeout errors correctly"
git commit -m "docs(readme): update installation instructions"
```

### 5. プルリクエスト

#### PR作成前のチェックリスト

- [ ] すべてのテストがパス (`make test`)
- [ ] ビルドが成功 (`make build`)
- [ ] SwiftDocCドキュメントを追加
- [ ] 変更内容をCHANGELOG.mdに記載
- [ ] コードレビューの準備完了

#### PRテンプレート

```markdown
## 変更内容

<!-- 変更内容の概要を記述 -->

## 動機と背景

<!-- なぜこの変更が必要か -->

## 変更の種類

- [ ] バグ修正
- [ ] 新機能
- [ ] 破壊的変更
- [ ] ドキュメント更新

## テスト方法

<!-- この変更をどのようにテストしたか -->

## チェックリスト

- [ ] テストを追加/更新した
- [ ] ドキュメントを更新した
- [ ] CHANGELOG.mdを更新した
- [ ] すべてのテストがパスする
```

## コードレビュープロセス

1. PRを作成すると自動的にCIが実行されます
2. 最低1人のメンテナーによるレビューが必要
3. すべてのコメントに対応してください
4. 承認後、メンテナーがマージします

## リリースプロセス

1. バージョン番号を更新（Semantic Versioning）
2. CHANGELOG.mdを更新
3. タグを作成: `git tag v1.0.0`
4. タグをプッシュ: `git push origin v1.0.0`

## 質問やサポート

- Issue: バグ報告や機能リクエスト
- Discussions: 一般的な質問や議論
- Email: メンテナーへの直接連絡

## 行動規範

すべての貢献者は[Code of Conduct](CODE_OF_CONDUCT.md)に従ってください。

## ライセンス

貢献したコードはMITライセンスの下で公開されます。

---

貢献いただきありがとうございます！ 🎉
