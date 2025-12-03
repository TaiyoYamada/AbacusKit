<div align="center">

# AbacusKit

### High-Performance On-Device Inference SDK for iOS

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20macOS%2014%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![ExecuTorch](https://img.shields.io/badge/ExecuTorch-1.0-red.svg)](https://pytorch.org/executorch/)

**AbacusKit** is a production-ready iOS SDK for real-time **abacus cell state detection** using PyTorch's ExecuTorch runtime. Leverage hardware-accelerated inference with CoreML, MPS, or XNNPACK backends for fast, on-device machine learning.

[Features](#features) •
[Installation](#installation) •
[Quick Start](#quick-start) •
[Documentation](#documentation) •
[Performance](#performance)

</div>

---

## 🚀 Features

### Core Capabilities

- **🔥 ExecuTorch Runtime**: On-device inference using PyTorch's optimized ExecuTorch engine
- **⚡ Hardware Acceleration**: Automatic backend selection (Neural Engine, GPU, or CPU)
- **🎯 Real-Time Detection**: Classify abacus cell states (upper, lower, empty) in milliseconds
- **🧵 Thread-Safe**: Built with Swift 6 concurrency and actors for safe parallelism
- **📦 Lightweight**: Minimal dependencies, optimized for mobile

### Hardware Backends

| Backend | Hardware | Inference Time | Power Consumption |
|---------|----------|----------------|-------------------|
| **CoreML** | Neural Engine | 6-12ms | Very Low ⚡ |
| **MPS** | GPU | 12-25ms | Low 🔋 |
| **XNNPACK** | CPU | 25-50ms | Medium 🔌 |

### Production-Ready

- ✅ **Type-Safe API**: Full Swift 6 type safety with actors
- ✅ **Error Handling**: Comprehensive error types with context
- ✅ **Memory Efficient**: Optimized for iOS memory constraints
- ✅ **Well Tested**: Comprehensive test coverage
- ✅ **Well Documented**: Complete API reference and guides

---

## 📦 Installation

### Swift Package Manager

#### Xcode

1. **File** → **Add Package Dependencies**
2. Enter repository URL:
   ```
   https://github.com/TaiyoYamada/AbacusKit
   ```
3. Select version and add to your target

#### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/TaiyoYamada/AbacusKit.git", from: "1.0.0")
]
```

---

## 🏃 Quick Start

### 1. Import the Framework

```swift
import AbacusKit
```

### 2. Create an Inference Engine

```swift
let engine = ExecuTorchInferenceEngine()

// Load your .pte model
let modelURL = Bundle.main.url(forResource: "abacus_model", withExtension: "pte")!
try await engine.loadModel(at: modelURL)
```

### 3. Perform Inference

```swift
// From camera or image
let result = try await engine.predict(pixelBuffer: pixelBuffer)

print("State: \(result.predictedState)")
print("Confidence: \(result.probabilities[result.predictedState.rawValue])")
print("Inference time: \(result.inferenceTimeMs)ms")
```

### Complete Example

```swift
import AbacusKit
import AVFoundation

class AbacusDetector {
    private let engine = ExecuTorchInferenceEngine()
    
    func setup() async throws {
        let modelURL = Bundle.main.url(forResource: "abacus_model", withExtension: "pte")!
        try await engine.loadModel(at: modelURL)
    }
    
    func detect(in pixelBuffer: CVPixelBuffer) async throws -> AbacusCellState {
        let result = try await engine.predict(pixelBuffer: pixelBuffer)
        return result.predictedState
    }
}
```

---

## 📚 Documentation

### Guides

- **[Getting Started](Documentation/GETTING_STARTED.md)** - Installation and first integration
- **[API Reference](Documentation/API_REFERENCE.md)** - Complete API documentation
- **[Architecture](Documentation/ARCHITECTURE.md)** - System design and internals
- **[Model Preparation](Documentation/MODEL_PREPARATION.md)** - Convert PyTorch models to `.pte`
- **[Performance](Documentation/PERFORMANCE.md)** - Optimization techniques
- **[Integration Guide](Documentation/INTEGRATION_GUIDE.md)** - Advanced patterns

### API Overview

#### ExecuTorchInferenceEngine

```swift
public actor ExecuTorchInferenceEngine {
    public init()
    public func loadModel(at: URL) throws
    public func predict(pixelBuffer: CVPixelBuffer) throws -> ExecuTorchInferenceResult
}
```

#### AbacusCellState

```swift
public enum AbacusCellState: Int, Sendable {
    case upper  // Upper bead (五珠)
    case lower  // Lower bead (一珠)
    case empty  // No bead
}
```

#### ExecuTorchInferenceResult

```swift
public struct ExecuTorchInferenceResult: Sendable {
    public let predictedState: AbacusCellState
    public let probabilities: [Float]
    public let inferenceTimeMs: Double
}
```

---

## ⚡ Performance

### Benchmarks (iPhone 15 Pro)

```
Backend: CoreML (Neural Engine)
Model: MobileNetV3-based classifier
Input: 224×224 RGB

Preprocessing:  5-8ms
Inference:      6-10ms
Postprocessing: <1ms
Total:          12-18ms

Memory Usage:   ~45MB
Model Size:     12MB (3MB quantized)
```

### Optimization Tips

1. **Use CoreML backend** for production (fastest, lowest power)
2. **Quantize models** to INT8 for 4x smaller size, 2-4x faster inference
3. **Load model once** at app startup
4. **Reuse pixel buffers** to reduce allocations
5. **Throttle frame rate** for real-time camera processing

See [Performance Guide](Documentation/PERFORMANCE.md) for detailed optimization strategies.

---

## 🏗️ Architecture

AbacusKit uses a two-layer architecture to bridge Swift and ExecuTorch's C++ runtime:

```
┌─────────────────────────────────────┐
│   Swift Layer (AbacusKit)           │
│   • ExecuTorchInferenceEngine       │
│   • Type-safe API                   │
│   • Actor-based concurrency         │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   Bridge Layer (AbacusKitBridge)    │
│   • Objective-C++ wrapper           │
│   • Memory management               │
│   • Type conversion                 │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   ExecuTorch Runtime (C++)          │
│   • Model execution                 │
│   • Hardware backends               │
│   • Tensor operations               │
└─────────────────────────────────────┘
```

See [Architecture Guide](Documentation/ARCHITECTURE.md) for details.

---

## 🔧 Requirements

- **iOS**: 17.0 or later
- **macOS**: 14.0 or later (for development)
- **Xcode**: 16.0 or later
- **Swift**: 6.0 or later

---

## 📝 Model Format

AbacusKit requires models in **ExecuTorch format** (`.pte` files). Convert your PyTorch models using the ExecuTorch export API:

```python
import torch
from torch.export import export
from executorch.exir import to_edge

# Export PyTorch model
model = YourModel()
model.eval()

example_input = torch.randn(1, 3, 224, 224)
exported = export(model, (example_input,))
edge_program = to_edge(exported)
executorch_program = edge_program.to_executorch()

# Save as .pte file
with open("model.pte", "wb") as f:
    f.write(executorch_program.buffer)
```

See [Model Preparation Guide](Documentation/MODEL_PREPARATION.md) for complete instructions.

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for:

- Code of conduct
- Development setup
- Pull request process
- Coding standards

---

## 📄 License

AbacusKit is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- **[PyTorch Team](https://pytorch.org/)** for ExecuTorch runtime
- **[Apple](https://developer.apple.com/)** for Core ML and Metal frameworks

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/TaiyoYamada/AbacusKit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/TaiyoYamada/AbacusKit/discussions)
- **Documentation**: [Full Documentation](https://taiyoyamada.github.io/AbacusKit/)

---

<div align="center">

**Built with ❤️ for the iOS ML community**

[⭐ Star us on GitHub](https://github.com/TaiyoYamada/AbacusKit)

</div>
