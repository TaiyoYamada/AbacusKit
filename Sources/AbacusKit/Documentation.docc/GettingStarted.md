# Getting Started with AbacusKit

Learn how to use the Soroban Recognition SDK

## Overview

With AbacusKit, you can recognize the state of a soroban (Japanese abacus) from camera frames and retrieve the value as a number.

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your/AbacusKit.git", from: "1.0.0")
]
```

### Prerequisites

- iOS 17.0+
- Xcode 15.0+
- Swift 6.0+

## Basic Usage

### 1. Initialization

```swift
import AbacusKit

// Initialize with default configuration
let recognizer = try AbacusRecognizer()

// Initialize with custom configuration
let config = AbacusConfiguration(
    inferenceBackend: .coreml,
    confidenceThreshold: 0.8
)
let customRecognizer = try AbacusRecognizer(configuration: config)
```

### 2. Single Frame Recognition

```swift
func processFrame(_ pixelBuffer: CVPixelBuffer) async {
    do {
        let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
        
        print("Recognized value: \(result.value)")
        print("Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
        print("Number of lanes: \(result.laneCount)")
        
    } catch AbacusError.frameNotDetected {
        print("Soroban not found")
    } catch {
        print("Error: \(error)")
    }
}
```

### 3. Camera Integration

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
                // Error handling
            }
        }
    }
}
```

## Error Handling

```swift
do {
    let result = try await recognizer.recognize(pixelBuffer: buffer)
} catch let error as AbacusError {
    switch error {
    case .frameNotDetected:
        // Wait for next frame
        break
        
    case .lowConfidence(let conf, _):
        showWarning("Recognition accuracy is low")
        
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```
