# AbacusKit 完全仕様書 v2.0

> そろばん認識 SDK - OpenCV前処理 + ExecuTorch推論

## 目次

1. [Part 1: アーキテクチャ概要](./SPEC_PART1_ARCHITECTURE.md)
2. [Part 2: モジュール構成と責務](./SPEC_PART2_MODULES.md)
3. [Part 3: 前処理・推論パイプライン](./SPEC_PART3_PIPELINE.md)
4. [Part 4: API設計とエラー設計](./SPEC_PART4_API.md)
5. [Part 5: パフォーマンス設計](./SPEC_PART5_PERFORMANCE.md)
6. [Part 6: 実装ロードマップ](./SPEC_PART6_ROADMAP.md)

---

## エグゼクティブサマリー

### 現状分析

| 項目 | 現在の実装 | 目標仕様 |
|------|-----------|---------|
| **前処理** | Obj-C++ (ImageNet正規化のみ) | OpenCV C++ (検出/ROI抽出/正規化) |
| **推論** | ExecuTorch (.pte) | ExecuTorch (.pte) ✅ |
| **モデル配布** | S3 OTA更新 | GitHub Releases + ローカルキャッシュ |
| **Swift API** | 2系統 (Abacus + ExecuTorchInferenceEngine) | 統合した1系統 |
| **ターゲットFPS** | 未定義 | 30-60 FPS |

### 主要課題

1. **OpenCV 統合が未実装** - 現在は単純な正規化のみ
2. **セル検出ロジックがない** - そろばん全体→個別セル分離が必要
3. **出力が3クラス分類のみ** - そろばん全体の値を構造化する必要あり
4. **2系統のAPIが混在** - `Abacus` と `ExecuTorchInferenceEngine` の統合が必要
5. **SPM + ExecuTorch の制約** - ランタイムはアプリ側埋め込み

---

## クイックリファレンス

### 推奨ディレクトリ構成

```
AbacusKit/
├── Sources/
│   ├── AbacusKit/              # Pure Swift (Public API)
│   │   ├── Core/               # 初期化・設定・ファサード
│   │   ├── Domain/             # ドメインモデル
│   │   └── Public/             # Public エントリポイント
│   │
│   ├── AbacusVision/           # OpenCV 画像処理 (C++)
│   │   ├── include/            # Public C headers
│   │   ├── src/                # C++ 実装
│   │   └── bridge/             # Swift-C ブリッジ
│   │
│   └── AbacusInference/        # ExecuTorch 推論 (Obj-C++)
│       ├── include/            # Public ObjC headers
│       └── src/                # Obj-C++ 実装
│
├── Model/                      # .pte モデルファイル
├── Tests/
└── Package.swift
```

### 依存関係図

```
[App] ─── import ───▶ [AbacusKit] (Swift)
                           │
                           ├──▶ [AbacusVision] (C++/OpenCV) ─── OpenCV.xcframework
                           │
                           └──▶ [AbacusInference] (Obj-C++) ─── ExecuTorch runtime (App提供)
```

---

## 次のステップ

各パートの詳細は個別ファイルを参照してください。
