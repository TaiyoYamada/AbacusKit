# Model Directory

このディレクトリには、AbacusKit で使用する機械学習モデルを配置します。

## 📦 **ファイル構成**

```
Model/
├── abacus.pt      # TorchScript モデル（元のモデル）
└── abacus.pte     # ExecuTorch モデル（iOS で使用）
```

## 🔄 **モデルの変換**

TorchScript モデル（`.pt`）を ExecuTorch 形式（`.pte`）に変換するには：

```bash
# Makefile を使用
make export-model

# または直接スクリプトを実行
python3 Scripts/export_to_executorch.py \
    --input Model/abacus.pt \
    --output Model/abacus.pte
```

## 📋 **モデルの仕様**

### **入力**
- 形状: `(1, 3, 224, 224)`
- 型: `float32`
- 正規化: ImageNet 標準（mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]）

### **出力**
- 形状: `(1, 3)`
- 型: `float32`
- クラス:
  - 0: `upper` (上玉)
  - 1: `lower` (下玉)
  - 2: `empty` (玉なし)

## 🚀 **モデルの配置**

### **開発時**
モデルファイルをこのディレクトリに配置してください。

### **アプリ配布時**
- **オプション A**: アプリバンドルに同梱
  - `Bundle.main.url(forResource: "abacus", withExtension: "pte")`
  
- **オプション B**: S3 からダウンロード
  - 初回起動時にダウンロード
  - ローカルキャッシュに保存

## 📊 **モデルサイズ**

| フォーマット | サイズ | 備考 |
|------------|--------|------|
| `.pt` (TorchScript) | ~10MB | 元のモデル |
| `.pte` (ExecuTorch) | ~8MB | 最適化済み |
| `.pte` (量子化) | ~2MB | INT8 量子化 |

## 🔧 **トラブルシューティング**

### **問題: モデルファイルが見つからない**

```bash
# ファイルの存在確認
ls -lh Model/

# 必要に応じてダウンロード
# curl -o Model/abacus.pt https://your-s3-url/abacus.pt
```

### **問題: 変換に失敗する**

```bash
# Python 環境を確認
python3 --version
pip list | grep torch
pip list | grep executorch

# 必要に応じて再インストール
pip install --upgrade torch executorch
```

---

**詳細は [EXECUTORCH_SETUP.md](../EXECUTORCH_SETUP.md) を参照してください。**
