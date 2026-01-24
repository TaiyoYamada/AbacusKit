# Getting Started with AbacusKit

Learn how to integrate soroban recognition into your iOS application.

@Metadata {
    @PageKind(article)
}

## Overview

AbacusKit enables your app to recognize Japanese soroban (abacus) in real-time
using the device camera. This guide walks you through the basic integration steps.

## Prerequisites

Before you begin, ensure you have:

- **Xcode 15.0** or later
- **iOS 17.0+** deployment target
- **Swift 6.0+**

## Installation

### Swift Package Manager

Add AbacusKit to your project using Swift Package Manager:

1. In Xcode, select **File → Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/your-org/AbacusKit.git
   ```
3. Select the version requirements and add the package

Alternatively, add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/AbacusKit.git", from: "1.0.0")
]
```

## Basic Usage

### Step 1: Import the Framework

```swift
import AbacusKit
```

### Step 2: Create a Recognizer

Create an ``AbacusRecognizer`` instance with default or custom configuration:

```swift
// Default configuration
let recognizer = AbacusRecognizer()

// Or with custom settings
let config = AbacusConfiguration(
    inferenceBackend: .coreml,
    confidenceThreshold: 0.8
)
let recognizer = AbacusRecognizer(configuration: config)
```

### Step 3: Process Camera Frames

Pass `CVPixelBuffer` frames from your camera session to the recognizer:

```swift
func processFrame(_ pixelBuffer: CVPixelBuffer) async {
    do {
        let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
        
        // Access the recognized value
        print("Value: \(result.value)")
        print("Confidence: \(result.confidence)")
        print("Digits: \(result.digitCount)")
        
    } catch AbacusError.frameNotDetected {
        // Soroban not visible in frame
        print("No soroban detected")
    } catch AbacusError.lowConfidence(let conf, _) {
        // Recognition succeeded but confidence is low
        print("Low confidence: \(conf)")
    } catch {
        print("Error: \(error)")
    }
}
```

## Camera Integration

Here's a complete example integrating with AVFoundation:

```swift
import AVFoundation
import AbacusKit
import UIKit

class CameraViewController: UIViewController {
    private let recognizer = AbacusRecognizer()
    private let captureSession = AVCaptureSession()
    
    @Published var recognizedValue: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera"))
        
        captureSession.addInput(input)
        captureSession.addOutput(output)
        
        Task {
            await captureSession.startRunning()
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        Task {
            do {
                let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
                await MainActor.run {
                    self.recognizedValue = result.value
                }
            } catch {
                // Handle errors
            }
        }
    }
}
```

## Configuration Options

AbacusKit provides three built-in configuration presets:

| Preset | Use Case |
|--------|----------|
| `.default` | Balanced performance and accuracy |
| `.highAccuracy` | Maximum recognition accuracy |
| `.fast` | Optimized for speed |

You can also customize individual settings:

```swift
var config = AbacusConfiguration.default
config.confidenceThreshold = 0.9
config.enablePerformanceLogging = true
config.frameSkipInterval = 2  // Process every other frame

let recognizer = AbacusRecognizer(configuration: config)
```

## Error Handling

AbacusKit uses ``AbacusError`` to communicate failures. Common errors include:

```swift
do {
    let result = try await recognizer.recognize(pixelBuffer: frame)
} catch let error as AbacusError {
    switch error {
    case .frameNotDetected:
        // Soroban not visible - guide user to position camera
        showOverlay("Point camera at the soroban")
        
    case .lowConfidence(let confidence, let threshold):
        // Recognition succeeded but uncertain
        showWarning("Recognition uncertain: \(Int(confidence * 100))%")
        
    case .modelNotLoaded:
        // Configuration issue
        // Try reloading the model
        try await recognizer.configure(.default)
        
    default:
        print("Recognition error: \(error.localizedDescription)")
    }
    
    // Check if error might resolve with retry
    if error.isRetryable {
        // Wait for next frame
    }
}
```

## Performance Optimization

For optimal performance:

1. **Use appropriate resolution**: Lower ``AbacusConfiguration/maxInputResolution`` 
   for faster processing
2. **Skip frames if needed**: Set ``AbacusConfiguration/frameSkipInterval`` > 1
3. **Choose the right backend**: `.coreml` uses the Neural Engine efficiently
4. **Disable unused preprocessing**: If lighting is good, disable CLAHE and noise reduction

```swift
var config = AbacusConfiguration.fast
config.maxInputResolution = 720
config.frameSkipInterval = 2
config.enableCLAHE = false
config.enableNoiseReduction = false
```

## Next Steps

- Learn about ``SorobanResult`` to understand recognition output
- Explore ``AbacusConfiguration`` for all configuration options
- See ``AbacusError`` for comprehensive error handling
