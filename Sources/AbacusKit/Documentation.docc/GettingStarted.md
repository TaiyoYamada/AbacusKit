# Getting Started with AbacusKit

そろばん認識 SDK の使い方を学ぶ

## Overview

AbacusKit を使用すると、カメラフレームからそろばんの状態を認識し、
数値として取得できます。

## インストール

### Swift Package Manager

`Package.swift` に以下を追加:

```swift
dependencies: [
    .package(url: "https://github.com/your/AbacusKit.git", from: "1.0.0")
]
```

### 前提条件

- iOS 17.0+
- Xcode 15.0+
- Swift 6.0+

## 基本的な使い方

### 1. 初期化

```swift
import AbacusKit

// デフォルト設定で初期化
let recognizer = try AbacusRecognizer()

// カスタム設定で初期化
let config = AbacusConfiguration(
    inferenceBackend: .coreml,
    confidenceThreshold: 0.8
)
let customRecognizer = try AbacusRecognizer(configuration: config)
```

### 2. 単一フレーム認識

```swift
func processFrame(_ pixelBuffer: CVPixelBuffer) async {
    do {
        let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
        
        print("認識値: \(result.value)")
        print("信頼度: \(String(format: "%.1f%%", result.confidence * 100))")
        print("桁数: \(result.laneCount)")
        
    } catch AbacusError.frameNotDetected {
        print("そろばんが見つかりません")
    } catch {
        print("エラー: \(error)")
    }
}
```

### 3. カメラ統合

```swift
import AVFoundation

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var recognizer: AbacusRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recognizer = try! AbacusRecognizer()
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        Task {
            do {
                let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
                await MainActor.run {
                    updateUI(with: result)
                }
            } catch {
                // エラー処理
            }
        }
    }
}
```

## エラーハンドリング

```swift
do {
    let result = try await recognizer.recognize(pixelBuffer: buffer)
} catch let error as AbacusError {
    switch error {
    case .frameNotDetected:
        // 次のフレームを待つ
        break
        
    case .lowConfidence(let conf, _):
        showWarning("認識精度が低いです")
        
    default:
        print("エラー: \(error.localizedDescription)")
    }
}
```
