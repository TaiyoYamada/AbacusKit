<div align="center">

# AbacusKit

### Soroban Recognition SDK for iOS

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20macOS%2014%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![ExecuTorch](https://img.shields.io/badge/ExecuTorch-1.0.1-red.svg)](https://pytorch.org/executorch/)
[![OpenCV](https://img.shields.io/badge/OpenCV-4.12.0-green.svg)](https://opencv.org/)

**AbacusKit** is an iOS SDK that recognizes soroban (Japanese abacus) in real-time and retrieves values as numbers.  
It integrates fast image preprocessing with OpenCV and high-accuracy inference with ExecuTorch.

[Features](#-features) •
[Installation](#-installation) •
[Usage](#-usage) •
[Documentation](#-documentation)

</div>

---

## 🚀 Features

- **📷 Variable Lane Support** - Automatically detect 1-27 digit soroban
- **⚡ Real-time Processing** - High-speed recognition at 30+ FPS
- **🎯 High Accuracy** - OpenCV preprocessing + ExecuTorch inference
- **🧵 Swift 6 Ready** - Actor-based thread-safe design
- **📦 All-in-One** - ExecuTorch and OpenCV bundled

---

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/TaiyoYamada/AbacusKit.git", from: "1.0.0")
]
```

> **Note**: ExecuTorch and OpenCV xcframeworks (~150MB) will be downloaded on first build.

---

## 🏃 Usage

### Basic Example

```swift
import AbacusKit

// Initialize the recognition engine
let recognizer = AbacusRecognizer()

// Load the model
try await recognizer.configure(.default)

// Recognize from camera frame
let result = try await recognizer.recognize(pixelBuffer: cameraFrame)

print("Recognized value: \(result.value)")           // e.g., 12345
print("Number of lanes: \(result.laneCount)")        // e.g., 5
print("Confidence: \(result.confidence)")            // e.g., 0.95
print("Processing time: \(result.timing.totalMs)ms")
```

### Camera Integration

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
                // Soroban not detected - wait for next frame
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) | Architecture design |
| [XCFRAMEWORK_SETUP.md](Documentation/XCFRAMEWORK_SETUP.md) | xcframework setup |

### API Reference

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
    public let value: Int              // Recognized numeric value
    public let lanes: [SorobanLane]    // Information for each digit
    public let confidence: Float       // Overall confidence (0.0-1.0)
    public let timing: TimingBreakdown // Processing time
}
```

#### AbacusConfiguration

```swift
// Presets
let defaultConfig = AbacusConfiguration.default
let fastConfig = AbacusConfiguration.fast
let accurateConfig = AbacusConfiguration.highAccuracy

// Custom
let custom = AbacusConfiguration(
    inferenceBackend: .coreml,
    confidenceThreshold: 0.8,
    maxLaneCount: 15
)
```

---

## ⚡ Performance

| Metric | iPhone 15 Pro |
|--------|---------------|
| Preprocessing (OpenCV) | 10-15ms |
| Inference (ExecuTorch) | 6-10ms |
| Total | 16-25ms |
| FPS | 40-60 |

---

## 🔧 Requirements

- iOS 17.0+
- macOS 14.0+
- Xcode 16.0+
- Swift 6.0+

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🛠 Development

### Building & Testing

This SDK uses Swift Package Manager and does not depend on Xcode-specific configurations.

```bash
# Build
swift build

# Run tests
swift test

# Generate documentation
swift package generate-documentation
```

### Code Style

We use CLI-based tools for formatting and linting. These are run manually during local development and automatically verified in CI.

| Tool | Purpose | Config |
|------|---------|--------|
| [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | Code formatting | `.swiftformat` |
| [SwiftLint](https://github.com/realm/SwiftLint) | Linting | `.swiftlint.yml` |

#### Running Locally

```bash
# Format code
swiftformat .

# Lint code
swiftlint
```

> **Note**: Code is not auto-formatted on save or commit. Run these tools manually before opening a PR.

### CI

Pull requests are automatically checked for:

- Build success (`swift build`)
- Test pass (`swift test`)
- Format/lint compliance

---

<div align="center">

**Made with ❤️ for iOS developers**

</div>
