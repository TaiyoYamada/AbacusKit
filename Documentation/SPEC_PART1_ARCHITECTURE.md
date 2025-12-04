# Part 1: アーキテクチャ概要

## 1.1 システム概要図

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              iOS Application                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  AVFoundation (Camera)                                                   │ │
│  │  CMSampleBuffer → CVPixelBuffer (1920x1080 / 30-60 FPS)                 │ │
│  └───────────────────────────────────┬─────────────────────────────────────┘ │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           AbacusKit SDK                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │ │
│  │  │  AbacusKit (Swift) - Public API Layer                           │    │ │
│  │  │  • AbacusRecognizer (メインファサード)                           │    │ │
│  │  │  • AbacusConfiguration                                          │    │ │
│  │  │  • AbacusResult / AbacusValue / CellState                       │    │ │
│  │  └────────────────────────────────┬────────────────────────────────┘    │ │
│  │                                   │                                      │ │
│  │            ┌──────────────────────┴──────────────────────┐              │ │
│  │            ▼                                              ▼              │ │
│  │  ┌──────────────────────────┐        ┌──────────────────────────────┐   │ │
│  │  │  AbacusVision (C++)      │        │  AbacusInference (Obj-C++)   │   │ │
│  │  │  • 画像前処理             │        │  • ExecuTorch 推論           │   │ │
│  │  │  • そろばん検出           │        │  • テンソル変換              │   │ │
│  │  │  • ROI 抽出              │        │  • softmax/argmax           │   │ │
│  │  │  • セル分離              │        │                              │   │ │
│  │  └──────────┬───────────────┘        └──────────────┬───────────────┘   │ │
│  │             │                                        │                   │ │
│  │             ▼                                        ▼                   │ │
│  │  ┌──────────────────────────┐        ┌──────────────────────────────┐   │ │
│  │  │  OpenCV.xcframework      │        │  ExecuTorch Runtime          │   │ │
│  │  │  (バンドル or App提供)   │        │  (App側で埋め込み必須)        │   │ │
│  │  └──────────────────────────┘        └──────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  App UI Layer                                                            │ │
│  │  AbacusResult → 表示・保存・検証                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1.2 レイヤー構成

| レイヤー | 言語 | 責務 | 依存関係 |
|---------|------|------|---------|
| **AbacusKit** | Swift | Public API / ファサード / ドメインモデル | AbacusVision, AbacusInference |
| **AbacusVision** | C++ | OpenCV 画像処理 / セル検出 | OpenCV.xcframework |
| **AbacusInference** | Obj-C++ | ExecuTorch 推論 / テンソル操作 | ExecuTorch (App提供) |

## 1.3 データフロー

```
CVPixelBuffer (1920x1080, BGRA)
    │
    ▼  [AbacusVision::preprocess()]
┌─────────────────────────────────┐
│ 1. リサイズ (長辺1280px)         │
│ 2. グレースケール変換            │
│ 3. コントラスト強調 (CLAHE)      │
│ 4. 二値化 (適応的閾値)           │
│ 5. 輪郭検出                      │
│ 6. そろばんフレーム検出          │
│ 7. 射影変換 (パースペクティブ補正)│
│ 8. 桁・セル領域分割              │
└─────────────────────────────────┘
    │
    ▼  N個の Cell ROI (224x224 RGB float tensor)
    │
    ▼  [AbacusInference::predict()]
┌─────────────────────────────────┐
│ 1. ImageNet正規化               │
│ 2. ExecuTorch forward()         │
│ 3. softmax + argmax             │
│ 4. CellState (upper/lower/empty)│
└─────────────────────────────────┘
    │
    ▼  CellState[] (各セルの状態)
    │
    ▼  [AbacusKit::interpret()]
┌─────────────────────────────────┐
│ 1. 上珠/下珠の状態から値を計算   │
│ 2. 桁ごとに集計                  │
│ 3. 整数値に変換                  │
└─────────────────────────────────┘
    │
    ▼  AbacusResult { value: Int, cells: [CellState], confidence: Float }
```

## 1.4 SPM制約と回避策

### 問題点

1. **ExecuTorch は SwiftPM 経由だと依存解決が不安定**
2. **OpenCV は XCFramework として配布が必要**
3. **C++ モジュールの相互参照が複雑**

### 解決策

| 制約 | 回避策 |
|------|--------|
| ExecuTorch の SPM 依存 | **アプリ側で XCFramework として埋め込み**。AbacusKit は `@_implementationOnly import` で参照 |
| OpenCV の配布 | **AbacusKit にバンドル** or **アプリ側で提供** (設定で選択可能) |
| C++ モジュール分離 | **modulemap** を使い、clang モジュールとして公開 |

### Package.swift 構成

```swift
targets: [
    // Pure Swift - 公開API
    .target(
        name: "AbacusKit",
        dependencies: ["AbacusVision", "AbacusInference"]
    ),
    
    // C++ OpenCV 画像処理
    .target(
        name: "AbacusVision",
        dependencies: [],
        cxxSettings: [.unsafeFlags(["-std=c++17"])],
        linkerSettings: [.linkedFramework("opencv2")]
    ),
    
    // Obj-C++ ExecuTorch 推論
    .target(
        name: "AbacusInference",
        dependencies: [],
        // ExecuTorchはApp側で提供されることを前提
        cxxSettings: [.unsafeFlags(["-std=c++17"])]
    )
]
```

## 1.5 設計原則

1. **責務分離**: 前処理・推論・解釈を明確に分離
2. **プロトコル指向**: すべての主要コンポーネントはプロトコルで抽象化
3. **Swift 6 対応**: actor で排他制御、Sendable でスレッド安全性保証
4. **テスタビリティ**: DI コンテナで全依存を差し替え可能
5. **オフライン動作**: ネットワーク不要（モデルはバンドル or 事前DL）
