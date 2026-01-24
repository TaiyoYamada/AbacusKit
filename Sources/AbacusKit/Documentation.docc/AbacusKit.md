# ``AbacusKit``

Real-time soroban (Japanese abacus) recognition SDK for iOS.

@Metadata {
    @DisplayName("AbacusKit")
    @Available(iOS, introduced: "17.0")
    @Available(macOS, introduced: "14.0")
}

## Overview

AbacusKit is a powerful SDK that detects and recognizes soroban (Japanese abacus) 
from camera frames, converting bead positions to numeric values in real-time.

The framework combines:
- **OpenCV** for high-speed image preprocessing and frame detection
- **ExecuTorch** for on-device neural network inference
- **Swift Concurrency** for safe, responsive async APIs

### Key Features

| Feature | Description |
|---------|-------------|
| **Real-time Processing** | 30+ FPS on modern iPhones |
| **Variable Lane Support** | Recognizes 1 to 27 digit sorobans |
| **Automatic Frame Detection** | Finds and tracks soroban position |
| **Perspective Correction** | Handles tilted camera angles |
| **Confidence Scoring** | Reports recognition reliability |

### Architecture

```
┌─────────────────────────────────────────────┐
│              AbacusRecognizer               │  ← Public API
├─────────────────┬───────────────────────────┤
│  AbacusVision   │    AbacusInferenceEngine  │
│   (C++/OpenCV)  │      (ExecuTorch)         │
└─────────────────┴───────────────────────────┘
```

### Quick Start

```swift
import AbacusKit

// 1. Create a recognizer
let recognizer = AbacusRecognizer()

// 2. Process camera frames
let result = try await recognizer.recognize(pixelBuffer: cameraFrame)

// 3. Use the result
print("Value: \(result.value)")
print("Confidence: \(result.confidence)")
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``AbacusRecognizer``
- ``SorobanResult``

### Configuration

- ``AbacusConfiguration``
- ``InferenceBackend``

### Data Models

- ``SorobanResult``
- ``SorobanLane``
- ``SorobanDigit``
- ``CellState``
- ``CellPrediction``
- ``TimingBreakdown``

### Error Handling

- ``AbacusError``

### Advanced Components

- ``AbacusInferenceEngine``
- ``SorobanInterpreter``
