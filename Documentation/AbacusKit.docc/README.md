# AbacusKit

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade iOS SDK for real-time CoreML inference with automatic model updates from S3.

## Features

- **CoreML Integration**: Native iOS machine learning with Metal acceleration
- **Automatic Updates**: Download and cache models from S3 with version management
- **Clean Architecture**: SOLID principles with protocol-driven design
- **Fully Testable**: 100% mockable through dependency injection
- **Swift 6**: Strict concurrency with async/await throughout
- **SwiftDocC**: Comprehensive API documentation
- **Type Safe**: Explicit error handling with typed errors

## Architecture

AbacusKit follows Clean Architecture principles with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│        Presentation Layer               │
│         (Public API - Abacus)           │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          Use Case Layer                 │
│    (AbacusCoordinator, ModelUpdater)    │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          Interface Layer                │
│  (Protocols: ModelManager, S3Downloader,│
│   ModelCache, FileStorage, etc.)        │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│       Infrastructure Layer              │
│  (Implementations: CoreML, URLSession,  │
│   FileManager, UserDefaults)            │
└─────────────────────────────────────────┘
```

## Installation

### Swift Package Manager

Add AbacusKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AbacusKit.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your target

## Quick Start

### Basic Usage

```swift
import AbacusKit

// 1. Configure the SDK
let config = AbacusConfig(
    versionURL: URL(string: "https://s3.amazonaws.com/your-bucket/version.json")!,
    modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
)

// 2. Initialize AbacusKit
let abacus = Abacus()
try await abacus.configure(config: config)

// 3. Perform inference
let result = try await abacus.predict(pixelBuffer: pixelBuffer)
print("Predicted value: \(result.value)")
print("Confidence: \(result.confidence)")
print("Inference time: \(result.inferenceTimeMs)ms")
```

### Camera Integration

```swift
import AVFoundation
import AbacusKit

class CameraViewController: UIViewController {
    let abacus = Abacus()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            let config = AbacusConfig(
                versionURL: URL(string: "https://your-s3-url/version.json")!,
                modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            )
            try await abacus.configure(config: config)
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task {
            do {
                let result = try await abacus.predict(pixelBuffer: pixelBuffer)
                await MainActor.run {
                    updateUI(with: result)
                }
            } catch {
                print("Prediction failed: \(error)")
            }
        }
    }
}
```

## Model Format

### version.json

Your S3 bucket should host a `version.json` file:

```json
{
  "version": 1,
  "model_url": "https://s3.amazonaws.com/your-bucket/model_v1.zip",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### Model Package

The model URL should point to a zip file containing:
- `.mlmodelc` (compiled CoreML model) or
- `.mlmodel` (uncompiled CoreML model)

AbacusKit will automatically:
1. Download the zip file
2. Extract the model
3. Compile if necessary
4. Load into CoreML
5. Cache for future use

## Configuration

### AbacusConfig

```swift
let config = AbacusConfig(
    versionURL: URL(string: "https://s3.amazonaws.com/bucket/version.json")!,
    modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
    forceUpdate: false  // Set to true to always download latest model
)
```

### Supported Pixel Formats

- `kCVPixelFormatType_32BGRA`
- `kCVPixelFormatType_32RGBA`
- `kCVPixelFormatType_24RGB`

## Error Handling

AbacusKit provides comprehensive error types:

```swift
do {
    let result = try await abacus.predict(pixelBuffer: pixelBuffer)
} catch AbacusError.notConfigured {
    print("SDK not configured. Call configure() first.")
} catch AbacusError.modelNotLoaded {
    print("Model failed to load.")
} catch AbacusError.preprocessingFailed(let reason) {
    print("Invalid input: \(reason)")
} catch AbacusError.inferenceFailed(let error) {
    print("Inference failed: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Testing

AbacusKit is designed for testability with protocol-driven architecture:

```swift
import XCTest
@testable import AbacusKit

class MyTests: XCTestCase {
    func testPrediction() async throws {
        // Use mock implementations
        let mockModelManager = MockModelManager()
        mockModelManager.predictResult = .success([42.0, 0.95])
        
        // Test your code with mocks
        // ...
    }
}
```

All protocols have corresponding mock implementations in the test target.

## Performance

- **Inference Time**: Typically 10-50ms on modern iOS devices
- **Model Loading**: 100-500ms depending on model size
- **Memory Usage**: Depends on model size, typically 50-200MB

## Requirements

- iOS 17.0+
- macOS 14.0+ (for development)
- Swift 6.0+
- Xcode 16.0+

## Dependencies

- [Resolver](https://github.com/hmlongco/Resolver) - Dependency injection
- [SwiftLog](https://github.com/apple/swift-log) - Structured logging
- [Zip](https://github.com/marmelroy/Zip) - Archive extraction
- [Quick](https://github.com/Quick/Quick) - Testing framework
- [Nimble](https://github.com/Quick/Nimble) - Matcher framework

## Documentation

Generate full documentation using SwiftDocC:

```bash
swift package generate-documentation
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## License

AbacusKit is released under the MIT License. See [LICENSE](LICENSE) for details.

## Credits

Developed with ❤️ following Clean Architecture and SOLID principles.

## Support

For issues and questions:
- Open an issue on [GitHub](https://github.com/yourusername/AbacusKit/issues)
- Check the [documentation](https://yourusername.github.io/AbacusKit)

---

**Note**: This SDK uses CoreML for inference. Ensure your models are compatible with CoreML format (.mlmodel or .mlmodelc).
