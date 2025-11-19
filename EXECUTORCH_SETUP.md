# ExecuTorch セットアップガイド

このドキュメントでは、AbacusKit で ExecuTorch を使用するためのセットアップ手順を説明します。

## 📋 **前提条件**

- macOS 14.0 以降
- Xcode 16.0 以降
- Python 3.8 以降
- PyTorch 2.0 以降

---

## 🚀 **1. ExecuTorch のインストール（Python 側）**

モデルを `.pte` 形式に変換するために、Python 環境に ExecuTorch をインストールします。

```bash
# PyTorch と ExecuTorch をインストール
pip install torch torchvision
pip install executorch
```

---

## 🔄 **2. モデルの変換（.pt → .pte）**

TorchScript モデル（`.pt`）を ExecuTorch 形式（`.pte`）に変換します。

```bash
# 変換スクリプトを実行
python Scripts/export_to_executorch.py \
    --input Model/abacus.pt \
    --output Model/abacus.pte
```

### **変換の詳細**

変換プロセスは以下のステップで行われます：

1. **TorchScript モデルのロード**: `.pt` ファイルを読み込む
2. **torch.export**: PyTorch 2.0 の export API でエクスポート
3. **Edge IR 変換**: ExecuTorch の中間表現に変換
4. **ExecuTorch プログラム生成**: `.pte` バイナリを生成

---

## 📦 **3. SwiftPM の依存関係解決**

AbacusKit は ExecuTorch を SwiftPM 経由で取得します。

```bash
# 依存関係を解決
swift package resolve

# ビルド
swift build
```

### **Package.swift の構成**

```swift
dependencies: [
    .package(
        url: "https://github.com/pytorch/executorch.git",
        branch: "swiftpm-1.0.0"
    ),
]

targets: [
    .target(
        name: "AbacusKitBridge",
        dependencies: [
            .product(name: "executorch", package: "executorch"),
            .product(name: "backend_coreml", package: "executorch"),
            .product(name: "backend_mps", package: "executorch"),
            .product(name: "backend_xnnpack", package: "executorch"),
            .product(name: "kernels_optimized", package: "executorch"),
            .product(name: "kernels_quantized", package: "executorch"),
        ]
    )
]
```

---

## 🧪 **4. 動作確認**

### **A. モデルのロードテスト**

```swift
import AbacusKit

let engine = ExecuTorchInferenceEngine()

// モデルをロード
let modelURL = Bundle.main.url(forResource: "abacus", withExtension: "pte")!
try await engine.loadModel(at: modelURL)

print("✅ Model loaded successfully!")
```

### **B. 推論テスト**

```swift
// PixelBuffer を作成（224x224）
var pixelBuffer: CVPixelBuffer?
CVPixelBufferCreate(
    kCFAllocatorDefault,
    224, 224,
    kCVPixelFormatType_32BGRA,
    nil,
    &pixelBuffer
)

// 推論実行
let result = try await engine.predict(pixelBuffer: pixelBuffer!)

print("Predicted class: \(result.predictedState)")
print("Probabilities: \(result.probabilities)")
print("Inference time: \(result.inferenceTimeMs)ms")
```

---

## 🏗️ **5. アーキテクチャ**

```
┌─────────────────────────────────────────────────────────┐
│                    Swift Layer                          │
│  ExecuTorchInferenceEngine (actor)                      │
│  - loadModel(at: URL)                                   │
│  - predict(pixelBuffer: CVPixelBuffer)                  │
└─────────────────────────────────────────────────────────┘
                          ↓ calls
┌─────────────────────────────────────────────────────────┐
│              Objective-C++ Bridge Layer                 │
│  ExecuTorchModuleBridge (@interface)                    │
│  - loadModelAtPath:error:                               │
│  - predictWithPixelBuffer:result:error:                 │
└─────────────────────────────────────────────────────────┘
                          ↓ calls
┌─────────────────────────────────────────────────────────┐
│                  ExecuTorch C++ API                     │
│  torch::executor::Module                                │
│  - load_method("forward")                               │
│  - execute("forward", inputs)                           │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 **6. トラブルシューティング**

### **問題: ビルドエラー "executorch not found"**

**解決策:**
```bash
# キャッシュをクリア
rm -rf .build
swift package clean

# 依存関係を再解決
swift package resolve
swift build
```

### **問題: モデルのロードに失敗する**

**解決策:**
1. `.pte` ファイルが正しく生成されているか確認
2. ファイルパスが正しいか確認
3. モデルのサイズが適切か確認（大きすぎる場合は量子化を検討）

### **問題: 推論が遅い**

**解決策:**
1. **XNNPACK バックエンド**を有効化（CPU 最適化）
2. **CoreML バックエンド**を有効化（Neural Engine 使用）
3. **MPS バックエンド**を有効化（GPU 使用）

```python
# モデル変換時にバックエンドを指定
from executorch.exir.backend.backend_api import to_backend

# XNNPACK バックエンドを使用
edge_program = to_edge(exported_program)
lowered_module = edge_program.to_backend("XnnpackBackend")
```

---

## 📊 **7. パフォーマンス比較**

| バックエンド | 推論時間 (ms) | メモリ使用量 (MB) | 備考 |
|------------|--------------|------------------|------|
| CPU (デフォルト) | 50-100 | 100 | 基本実装 |
| XNNPACK | 20-40 | 80 | CPU 最適化 |
| CoreML | 10-20 | 60 | Neural Engine |
| MPS | 15-30 | 70 | GPU 使用 |

---

## 📚 **8. 参考リンク**

- [ExecuTorch 公式ドキュメント](https://pytorch.org/executorch/)
- [iOS での使用方法](https://docs.pytorch.org/executorch/stable/using-executorch-ios.html)
- [モデルのエクスポート](https://pytorch.org/executorch/stable/export-to-executorch.html)
- [バックエンドの選択](https://pytorch.org/executorch/stable/backends.html)

---

## ✅ **次のステップ**

1. ✅ ExecuTorch をインストール
2. ✅ モデルを `.pte` 形式に変換
3. ✅ SwiftPM でビルド
4. ✅ 推論テストを実行
5. 🚀 アプリに統合

---

**質問や問題があれば、Issue を作成してください！**
