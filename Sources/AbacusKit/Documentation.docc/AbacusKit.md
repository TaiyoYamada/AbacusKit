# ``AbacusKit``

そろばん認識 SDK - リアルタイムでそろばんの状態を数値に変換

## Overview

AbacusKit は、カメラフレームからそろばんを検出し、その状態を数値として認識する SDK です。
OpenCV による高速な画像前処理と ExecuTorch による高精度な推論を組み合わせ、
30FPS 以上のリアルタイム処理を実現します。

### 主な機能

- **自動フレーム検出**: そろばんの外枠を自動検出し、射影変換で正規化
- **可変レーン対応**: 1〜27桁の任意のそろばんに対応
- **高速処理**: OpenCV + ExecuTorch で 30FPS 以上を達成
- **Swift 6 対応**: モダンな Swift Concurrency に完全対応

### アーキテクチャ

```
┌─────────────────────────────────────┐
│          AbacusRecognizer           │  ← Public API
├─────────────────────────────────────┤
│  AbacusVision     │  InferenceEngine │  ← Internal
│  (C++ / OpenCV)   │  (ExecuTorch)    │
└─────────────────────────────────────┘
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``AbacusRecognizer``
- ``SorobanResult``

### Configuration

- ``AbacusConfiguration``
- ``InferenceBackend``

### Models

- ``SorobanResult``
- ``SorobanLane``
- ``SorobanDigit``
- ``CellState``

### Errors

- ``AbacusError``

### Advanced

- ``AbacusInferenceEngine``
- ``SorobanInterpreter``
