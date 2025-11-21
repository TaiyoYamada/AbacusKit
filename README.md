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


## Installation

### Swift Package Manager

Add AbacusKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/TaiyoYamada/AbacusKit.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your target

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

## Support

For issues and questions:
- Open an issue on [GitHub](https://github.com/TaiyoYamada/AbacusKit/issues)
- Check the [documentation](https://taiyoyamada.github.io/AbacusKit/documentation/abacuskit/)

---

**Note**: This SDK uses CoreML for inference. Ensure your models are compatible with CoreML format (.mlmodel or .mlmodelc).
