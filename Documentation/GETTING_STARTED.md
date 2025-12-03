# Getting Started with AbacusKit

This guide will help you integrate AbacusKit into your iOS application for real-time abacus cell state detection.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Integration Patterns](#integration-patterns)
- [Troubleshooting](#troubleshooting)

## Requirements

- **iOS**: 17.0 or later
- **macOS**: 14.0 or later (for development)
- **Xcode**: 16.0 or later
- **Swift**: 6.0 or later

## Installation

### Swift Package Manager

#### Option 1: Xcode UI

1. Open your project in Xcode
2. Go to **File** → **Add Package Dependencies...**
3. Enter the repository URL:
   ```
   https://github.com/TaiyoYamada/AbacusKit
   ```
4. Select version requirements (recommend: "Up to Next Major")
5. Click **Add Package**
6. Select **AbacusKit** target and click **Add Package**

#### Option 2: Package.swift

Add AbacusKit to your `Package.swift` dependencies:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/TaiyoYamada/AbacusKit.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: ["AbacusKit"]
        )
    ]
)
```

Then run:
```bash
swift package resolve
```

## Quick Start

### Step 1: Import the Framework

```swift
import AbacusKit
import AVFoundation
```

### Step 2: Prepare Your Model

You'll need a `.pte` (PyTorch ExecuTorch) model file. See [MODEL_PREPARATION.md](MODEL_PREPARATION.md) for how to convert your PyTorch model.

Add the model to your Xcode project:
1. Drag the `.pte` file into your project navigator
2. Ensure it's added to your app target
3. Verify it appears in **Build Phases** → **Copy Bundle Resources**

### Step 3: Create an Inference Engine

```swift
import AbacusKit

class AbacusDetector {
    // Create the engine (actor-based, thread-safe)
    private let engine = ExecuTorchInferenceEngine()
    
    // Track loading state
    private var isLoaded = false
    
    func setup() async throws {
        // Get model URL from bundle
        guard let modelURL = Bundle.main.url(
            forResource: "abacus_model",
            withExtension: "pte"
        ) else {
            throw NSError(domain: "AbacusDetector", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Model file not found"])
        }
        
        // Load the model (one-time operation)
        try await engine.loadModel(at: modelURL)
        isLoaded = true
        
        print("✅ Model loaded successfully")
    }
}
```

### Step 4: Perform Inference

```swift
extension AbacusDetector {
    func detectState(in pixelBuffer: CVPixelBuffer) async throws -> AbacusCellState {
        guard isLoaded else {
            throw NSError(domain: "AbacusDetector", 
                         code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        // Perform inference
        let result = try await engine.predict(pixelBuffer: pixelBuffer)
        
        // Log results
        print("Predicted: \(result.predictedState)")
        print("Confidence: \(result.probabilities[result.predictedState.rawValue])")
        print("Inference time: \(result.inferenceTimeMs)ms")
        
        return result.predictedState
    }
}
```

### Step 5: Use in Your App

```swift
import SwiftUI

@main
struct AbacusApp: App {
    @StateObject private var detector = AbacusDetectorViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Load model on app launch
                    await detector.loadModel()
                }
        }
    }
}

@MainActor
class AbacusDetectorViewModel: ObservableObject {
    @Published var currentState: AbacusCellState?
    @Published var isLoading = false
    
    private let detector = AbacusDetector()
    
    func loadModel() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await detector.setup()
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) async {
        do {
            currentState = try await detector.detectState(in: pixelBuffer)
        } catch {
            print("❌ Inference failed: \(error)")
        }
    }
}
```

## Integration Patterns

### Pattern 1: Camera Stream Processing

Integrate with AVFoundation for real-time camera processing:

```swift
import AVFoundation

class CameraProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let detector = AbacusDetector()
    private let processingQueue = DispatchQueue(label: "camera.processing")
    
    func setup() async throws {
        try await detector.setup()
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
                let state = try await detector.detectState(in: pixelBuffer)
                await handleDetection(state)
            } catch {
                print("Detection error: \(error)")
            }
        }
    }
    
    @MainActor
    func handleDetection(_ state: AbacusCellState) {
        // Update UI on main thread
        print("Detected: \(state)")
    }
}
```

### Pattern 2: Image Processing

Process static images:

```swift
import UIKit

extension AbacusDetector {
    func detectState(in image: UIImage) async throws -> AbacusCellState {
        // Convert UIImage to CVPixelBuffer
        guard let pixelBuffer = image.pixelBuffer() else {
            throw NSError(domain: "AbacusDetector", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        return try await detectState(in: pixelBuffer)
    }
}

// Helper extension
extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let cgImage = cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
}
```

### Pattern 3: Batch Processing

Process multiple images efficiently:

```swift
extension AbacusDetector {
    func detectStates(in images: [UIImage]) async throws -> [AbacusCellState] {
        var results: [AbacusCellState] = []
        
        for image in images {
            let state = try await detectState(in: image)
            results.append(state)
        }
        
        return results
    }
}
```

## Error Handling

### Comprehensive Error Handling

```swift
func safeDetection(_ pixelBuffer: CVPixelBuffer) async {
    do {
        let state = try await detector.detectState(in: pixelBuffer)
        print("✅ Success: \(state)")
        
    } catch ExecuTorchInferenceError.modelNotLoaded {
        print("❌ Model not loaded - call setup() first")
        
    } catch ExecuTorchInferenceError.modelLoadFailed(let message) {
        print("❌ Model load failed: \(message)")
        
    } catch ExecuTorchInferenceError.inferenceFailed(let message) {
        print("❌ Inference failed: \(message)")
        
    } catch ExecuTorchInferenceError.invalidInput(let message) {
        print("❌ Invalid input: \(message)")
        
    } catch {
        print("❌ Unknown error: \(error)")
    }
}
```

## Performance Tips

### 1. Load Model Once

```swift
// ✅ Good: Load once during initialization
class AppInitializer {
    let detector = AbacusDetector()
    
    func initialize() async {
        try? await detector.setup()  // Load model once
    }
}

// ❌ Bad: Loading repeatedly
func processImage() async {
    let detector = AbacusDetector()
    try? await detector.setup()  // Don't do this repeatedly!
}
```

### 2. Reuse Pixel Buffers

```swift
class BufferPool {
    private var pool: [CVPixelBuffer] = []
    
    func getBuffer() -> CVPixelBuffer? {
        if let buffer = pool.popLast() {
            return buffer
        }
        
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            224, 224,
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        return buffer
    }
    
    func returnBuffer(_ buffer: CVPixelBuffer) {
        pool.append(buffer)
    }
}
```

### 3. Monitor Performance

```swift
func detectWithMonitoring(_ pixelBuffer: CVPixelBuffer) async throws {
    let start = CFAbsoluteTimeGetCurrent()
    
    let result = try await detector.detectState(in: pixelBuffer)
    
    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
    
    if elapsed > 50 {
        print("⚠️ Slow inference: \(elapsed)ms")
    }
    
    print("Total time: \(elapsed)ms, Model time: \(result.inferenceTimeMs)ms")
}
```

## Troubleshooting

### Model Not Found

**Error**: `Model file not found`

**Solution**:
1. Verify the `.pte` file is in your Xcode project
2. Check **Build Phases** → **Copy Bundle Resources**
3. Ensure the filename matches exactly (case-sensitive)

```swift
// Debug: List all bundle resources
if let resourcePath = Bundle.main.resourcePath {
    let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath)
    print("Bundle files: \(files ?? [])")
}
```

### Model Load Failed

**Error**: `Model load failed: Invalid file format`

**Possible Causes**:
- Model is not in `.pte` format (see [MODEL_PREPARATION.md](MODEL_PREPARATION.md))
- Model was compiled with incompatible ExecuTorch version
- File is corrupted

**Solution**:
```bash
# Verify model file
file abacus_model.pte  # Should show: data

# Check file size
ls -lh abacus_model.pte  # Should be several MB
```

### Inference Failed

**Error**: `Inference failed: Invalid input`

**Possible Causes**:
- Pixel buffer size is not 224×224
- Unsupported pixel format

**Solution**:
```swift
// Verify pixel buffer dimensions
let width = CVPixelBufferGetWidth(pixelBuffer)
let height = CVPixelBufferGetHeight(pixelBuffer)
let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

print("Dimensions: \(width)×\(height), Format: \(format)")
// Expected: 224×224, Format: 1111970369 (BGRA)
```

### Slow Inference

**Symptom**: Inference takes >100ms

**Solutions**:

1. **Check backend**:
   ```swift
   // Model should use CoreML or MPS backend for best performance
   // Rebuild model with backend specification
   ```

2. **Reduce image resolution before processing**:
   ```swift
   // Resize to 224×224 before passing to detector
   ```

3. **Use quantized model**:
   ```bash
   # Use INT8 quantization during model export
   python export_model.py --quantize int8
   ```

## Next Steps

- **[API_REFERENCE.md](API_REFERENCE.md)**: Detailed API documentation
- **[MODEL_PREPARATION.md](MODEL_PREPARATION.md)**: Convert your PyTorch model
- **[PERFORMANCE.md](PERFORMANCE.md)**: Optimization techniques
- **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)**: Advanced integration patterns

---

**Need Help?**

- Open an issue on [GitHub](https://github.com/TaiyoYamada/AbacusKit/issues)
- Check the [documentation](https://taiyoyamada.github.io/AbacusKit/)
