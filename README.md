<div align="center">

# AbacusKit

### そろばん認識 SDK for iOS

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20macOS%2014%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![ExecuTorch](https://img.shields.io/badge/ExecuTorch-1.0.1-red.svg)](https://pytorch.org/executorch/)
[![OpenCV](https://img.shields.io/badge/OpenCV-4.12.0-green.svg)](https://opencv.org/)

**AbacusKit** はリアルタイムでそろばんを認識し、数値として取得できる iOS SDK です。  
OpenCV による高速な画像前処理と ExecuTorch による高精度な推論を統合しています。

[特徴](#-特徴) •
[インストール](#-インストール) •
[使い方](#-使い方) •
[ドキュメント](#-ドキュメント)

</div>

---

## 🚀 特徴

- **📷 可変レーン対応** - 1〜27桁のそろばんを自動検出
- **⚡ リアルタイム処理** - 30FPS 以上の高速認識
- **🎯 高精度** - OpenCV 前処理 + ExecuTorch 推論
- **🧵 Swift 6 対応** - actor ベースの安全な設計
- **📦 オールインワン** - ExecuTorch と OpenCV をバンドル

---

## 📦 インストール

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/TaiyoYamada/AbacusKit.git", from: "1.0.0")
]
```

> **注意**: 初回ビルド時に ExecuTorch と OpenCV の xcframework (~150MB) がダウンロードされます。

---

## 🏃 使い方

### 基本的な使用例

```swift
import AbacusKit

// 認識エンジンを初期化
let recognizer = AbacusRecognizer()

// モデルをロード
try await recognizer.configure(.default)

// カメラフレームから認識
let result = try await recognizer.recognize(pixelBuffer: cameraFrame)

print("認識値: \(result.value)")           // 例: 12345
print("桁数: \(result.laneCount)")         // 例: 5
print("信頼度: \(result.confidence)")      // 例: 0.95
print("処理時間: \(result.timing.totalMs)ms")
```

### カメラ統合

```swift
import AbacusKit
import AVFoundation

class CameraViewController: UIViewController {
    private let recognizer = AbacusRecognizer()
    
    func captureOutput(_ output: AVCaptureOutput, 
                       didOutput sampleBuffer: CMSampleBuffer, 
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task {
            do {
                let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
                await MainActor.run {
                    displayResult(result)
                }
            } catch AbacusError.frameNotDetected {
                // そろばんが検出されなかった - 次のフレームを待つ
            } catch {
                print("エラー: \(error)")
            }
        }
    }
}
```

---

## 📚 ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) | アーキテクチャ設計 |
| [XCFRAMEWORK_SETUP.md](Documentation/XCFRAMEWORK_SETUP.md) | xcframework セットアップ |

### API リファレンス

#### AbacusRecognizer

```swift
public actor AbacusRecognizer {
    public init()
    public init(configuration: AbacusConfiguration)
    public func configure(_ config: AbacusConfiguration) async throws
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> SorobanResult
}
```

#### SorobanResult

```swift
public struct SorobanResult: Sendable {
    public let value: Int              // 認識された数値
    public let lanes: [SorobanLane]    // 各桁の情報
    public let confidence: Float       // 全体信頼度 (0.0-1.0)
    public let timing: TimingBreakdown // 処理時間
}
```

#### AbacusConfiguration

```swift
// プリセット
let defaultConfig = AbacusConfiguration.default
let fastConfig = AbacusConfiguration.fast
let accurateConfig = AbacusConfiguration.highAccuracy

// カスタム
let custom = AbacusConfiguration(
    inferenceBackend: .coreml,
    confidenceThreshold: 0.8,
    maxLaneCount: 15
)
```

---

## ⚡ パフォーマンス

| 項目 | iPhone 15 Pro |
|------|---------------|
| 前処理 (OpenCV) | 10-15ms |
| 推論 (ExecuTorch) | 6-10ms |
| 合計 | 16-25ms |
| FPS | 40-60 |

---

## 🔧 要件

- iOS 17.0+
- macOS 14.0+
- Xcode 16.0+
- Swift 6.0+

---

## 📄 ライセンス

MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ for iOS developers**

</div>
