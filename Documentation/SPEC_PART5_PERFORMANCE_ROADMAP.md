# Part 5: パフォーマンス設計 & Part 6: 実装ロードマップ

## 5.1 パフォーマンス要件

| メトリクス | 目標値 | 現実的目標 |
|-----------|--------|-----------|
| フレームレート | 60 FPS | 30 FPS |
| 1フレーム処理時間 | < 16.7ms | < 33.3ms |
| メモリ使用量 | < 100MB | < 150MB |
| モデルロード時間 | < 500ms | < 1000ms |
| バッテリー消費 | Low | Medium |

## 5.2 処理時間配分 (30 FPS目標)

```
Total Budget: 33.3ms
┌─────────────────────────────────────────────────────────────┐
│ Preprocessing (OpenCV)                           18ms       │
│ ├─ Format conversion                    1ms                 │
│ ├─ Resize                               2ms                 │
│ ├─ Grayscale + CLAHE                    3ms                 │
│ ├─ Binarization + Morphology            3ms                 │
│ ├─ Contour Detection                    2ms                 │
│ ├─ Frame Detection                      2ms                 │
│ ├─ Perspective Transform                2ms                 │
│ └─ Cell Extraction + Normalization      3ms                 │
├─────────────────────────────────────────────────────────────┤
│ Inference (ExecuTorch CoreML)                    12ms       │
│ ├─ Tensor Creation                      1ms                 │
│ ├─ Forward Pass                         10ms                │
│ └─ Softmax + Argmax                     1ms                 │
├─────────────────────────────────────────────────────────────┤
│ Postprocessing (Swift)                            2ms       │
│ ├─ Value Interpretation                 1ms                 │
│ └─ Result Construction                  1ms                 │
├─────────────────────────────────────────────────────────────┤
│ Remaining Buffer                                  1.3ms     │
└─────────────────────────────────────────────────────────────┘
```

## 5.3 最適化戦略

### 1. フレームスキップ

```swift
class FrameController {
    private var frameCount = 0
    private let skipInterval: Int
    
    func shouldProcess() -> Bool {
        frameCount += 1
        return frameCount % skipInterval == 0
    }
}

// 60 FPS → 30 FPS 処理
let controller = FrameController(skipInterval: 2)
```

### 2. ROI キャッシュ

```swift
actor ROICache {
    private var lastROI: CGRect?
    private var cacheHitCount = 0
    
    func getROI(currentFrame: CVPixelBuffer) -> CGRect? {
        // 直前のROIが有効なら再利用
        if let roi = lastROI, cacheHitCount < 5 {
            cacheHitCount += 1
            return roi
        }
        return nil
    }
}
```

### 3. バッチ推論

```swift
// 個別推論 (遅い)
for cell in cells {
    results.append(try engine.predict(cell))
}

// バッチ推論 (速い)
let batchedCells = cells.chunked(into: 8)
for batch in batchedCells {
    results.append(contentsOf: try engine.predictBatch(batch))
}
```

### 4. メモリプール

```swift
class TensorPool {
    private var available: [UnsafeMutablePointer<Float>] = []
    
    func acquire(size: Int) -> UnsafeMutablePointer<Float> {
        if let ptr = available.popLast() {
            return ptr
        }
        return UnsafeMutablePointer<Float>.allocate(capacity: size)
    }
    
    func release(_ ptr: UnsafeMutablePointer<Float>) {
        available.append(ptr)
    }
}
```

---

## 6.1 実装ロードマップ

### Phase 1: 基盤整備 (Week 1-2) 🔴 高優先度

| タスク | 工数 | 依存 |
|--------|------|------|
| OpenCV.xcframework 作成・統合 | 3d | - |
| AbacusVision C++ モジュール骨格 | 2d | 上記 |
| 前処理パイプライン実装 (Step 1-6) | 3d | 上記 |
| Swift-C ブリッジ実装 | 2d | 上記 |

### Phase 2: そろばん検出 (Week 3-4) 🔴 高優先度

| タスク | 工数 | 依存 |
|--------|------|------|
| フレーム検出アルゴリズム | 3d | Phase 1 |
| 射影変換実装 | 2d | 上記 |
| セル分割ロジック | 3d | 上記 |
| 単体テスト作成 | 2d | 上記 |

### Phase 3: 推論統合 (Week 5-6) 🟡 中優先度

| タスク | 工数 | 依存 |
|--------|------|------|
| ExecuTorch バッチ推論対応 | 2d | Phase 2 |
| 値解釈ロジック実装 | 2d | 上記 |
| Public API 統合 | 3d | 上記 |
| E2E テスト作成 | 3d | 上記 |

### Phase 4: 安定化・最適化 (Week 7-8) 🟡 中優先度

| タスク | 工数 | 依存 |
|--------|------|------|
| 連続認識安定化 | 3d | Phase 3 |
| パフォーマンスチューニング | 3d | 上記 |
| メモリ最適化 | 2d | 上記 |
| バッテリー消費検証 | 2d | 上記 |

### Phase 5: 配布準備 (Week 9-10) 🟢 低優先度

| タスク | 工数 | 依存 |
|--------|------|------|
| GitHub Releases 更新機構 | 3d | Phase 4 |
| ドキュメント整備 | 3d | 上記 |
| サンプルアプリ作成 | 3d | 上記 |
| CI/CD 構築 | 2d | 上記 |

---

## 6.2 リスク分析

| リスク | 影響度 | 発生確率 | 対策 |
|--------|--------|---------|------|
| OpenCV バイナリサイズ肥大 | 高 | 中 | 必要モジュールのみビルド |
| ExecuTorch SPM 互換性問題 | 高 | 高 | XCFramework に切り替え |
| 30 FPS 未達成 | 高 | 中 | フレームスキップ導入 |
| そろばん検出精度低下 | 中 | 中 | 学習データ追加 |
| メモリ不足 (古いデバイス) | 中 | 低 | 低解像度モード追加 |

---

## 6.3 現在の実装とのギャップ

| 項目 | 現在 | 目標 | 作業量 |
|------|------|------|--------|
| 前処理 | ImageNet正規化のみ | OpenCV フルパイプライン | **大** |
| 検出 | なし | そろばんフレーム検出 | **大** |
| セル分離 | なし | 自動桁・セル分割 | **大** |
| 推論 | 3クラス分類 | バッチ推論 | 中 |
| API | 2系統 (旧/新) | 統合API | 中 |
| モデル配布 | S3 OTA | GitHub Releases | 小 |

---

## 6.4 推奨ディレクトリ構成 (最終形)

```
AbacusKit/
├── Package.swift
├── README.md
├── Documentation/
│   ├── SPEC_*.md
│   └── API_REFERENCE.md
│
├── Sources/
│   ├── AbacusKit/
│   │   ├── Public/
│   │   │   ├── AbacusRecognizer.swift
│   │   │   ├── AbacusConfiguration.swift
│   │   │   └── AbacusKitExports.swift
│   │   ├── Domain/
│   │   │   ├── AbacusResult.swift
│   │   │   ├── CellState.swift
│   │   │   └── DigitInfo.swift
│   │   ├── Core/
│   │   │   ├── AbacusInterpreter.swift
│   │   │   ├── AbacusError.swift
│   │   │   └── StabilizationStrategy.swift
│   │   └── Internal/
│   │       ├── VisionBridge.swift
│   │       └── InferenceBridge.swift
│   │
│   ├── AbacusVision/
│   │   ├── include/
│   │   │   ├── AbacusVision.h
│   │   │   ├── VisionTypes.h
│   │   │   └── module.modulemap
│   │   ├── src/
│   │   │   ├── Preprocessor.cpp/.hpp
│   │   │   ├── AbacusDetector.cpp/.hpp
│   │   │   ├── CellExtractor.cpp/.hpp
│   │   │   └── PerspectiveCorrector.cpp/.hpp
│   │   └── bridge/
│   │       └── AbacusVisionBridge.mm
│   │
│   └── AbacusInference/
│       ├── include/
│       │   ├── AbacusInference.h
│       │   └── InferenceTypes.h
│       └── src/
│           ├── ExecuTorchEngine.mm
│           ├── TensorConverter.mm
│           └── BatchPredictor.mm
│
├── Model/
│   └── abacus_v1.pte
│
├── Tests/
│   ├── AbacusKitTests/
│   ├── AbacusVisionTests/
│   └── AbacusInferenceTests/
│
├── Examples/
│   └── AbacusSampleApp/
│
└── Frameworks/
    ├── opencv2.xcframework (optional, App提供も可)
    └── README_EXECUTORCH.md (Appへの組み込み手順)
```

---

## 6.5 次のアクション

1. **今すぐ**: OpenCV.xcframework を作成し、SPM に統合
2. **今週**: AbacusVision の骨格と前処理パイプライン実装開始
3. **来週**: そろばんフレーム検出アルゴリズムの実装・テスト
4. **2週後**: セル分割ロジックと推論統合

---

**作成日**: 2025-12-04
**バージョン**: 2.0
**ステータス**: ドラフト（レビュー待ち）
