# AbacusKit xcframework セットアップガイド

## 前提条件

- Xcode 15.0+
- macOS 14+
- Python 3.10+ (ExecuTorch ビルド用)

---

## 1. ExecuTorch xcframework の入手

### 方法A: SwiftPM ブランチから取得 (推奨)

```bash
git clone -b swiftpm-1.0.1 https://github.com/pytorch/executorch.git executorch-swiftpm
cd executorch-swiftpm

# Frameworks ディレクトリに xcframework が含まれる
ls Frameworks/
# → executorch.xcframework, backend_coreml.xcframework, etc.
```

### 方法B: ソースからビルド

```bash
git clone https://github.com/pytorch/executorch.git
cd executorch
git checkout v1.0.1

# 依存関係をインストール
pip install cmake
./install_requirements.sh

# iOS 用 xcframework をビルド
./build/build_apple_frameworks.sh --Release

# 出力確認
ls cmake-out/
# → executorch.xcframework
```

---

## 2. OpenCV xcframework の入手

```bash
# 公式リリースからダウンロード
curl -LO https://github.com/opencv/opencv/releases/download/4.12.0/opencv-4.12.0-ios-framework.zip
unzip opencv-4.12.0-ios-framework.zip

# opencv2.framework が展開される
# -> xcframework 形式に変換が必要な場合:
xcodebuild -create-xcframework \
    -framework opencv2.framework \
    -output opencv2.xcframework
```

---

## 3. xcframework を zip 圧縮

```bash
# ExecuTorch
zip -r ExecuTorch.xcframework.zip executorch.xcframework

# OpenCV
zip -r opencv2.xcframework.zip opencv2.xcframework
```

---

## 4. GitHub Releases へアップロード

1. https://github.com/TaiyoYamada/AbacusKit/releases にアクセス
2. 「Draft a new release」をクリック
3. Tag: `v1.0.0` を作成
4. Title: `AbacusKit v1.0.0`
5. 以下のファイルを添付:
   - `ExecuTorch.xcframework.zip`
   - `opencv2.xcframework.zip`
6. 「Publish release」をクリック

---

## 5. checksum を計算して Package.swift を更新

```bash
# checksum を計算
swift package compute-checksum ExecuTorch.xcframework.zip
# 出力例: abc123def456...

swift package compute-checksum opencv2.xcframework.zip
# 出力例: 789xyz...
```

Package.swift の以下の行を更新:

```swift
let execuTorchChecksum = "abc123def456..."  // ← 実際の値に置換
let opencvChecksum = "789xyz..."            // ← 実際の値に置換
```

---

## 6. 動作確認

```bash
cd /path/to/AbacusKit
swift build
swift test
```

---

## トラブルシューティング

### checksum が一致しない

```
error: checksum of downloaded artifact does not match
```

→ zip ファイルを再ダウンロードし、checksum を再計算してください。

### ExecuTorch ビルドエラー

→ Python 3.10+ と CMake が正しくインストールされているか確認してください。

### OpenCV シンボルが見つからない

→ opencv2.xcframework が正しい形式か確認してください。
