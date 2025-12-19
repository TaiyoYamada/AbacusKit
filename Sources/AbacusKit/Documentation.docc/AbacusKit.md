# ``AbacusKit``

Soroban Recognition SDK - Real-time conversion of soroban state to numeric values

## Overview

AbacusKit is an SDK that detects soroban (Japanese abacus) from camera frames and recognizes their state as numeric values.
It combines fast image preprocessing with OpenCV and high-accuracy inference with ExecuTorch to achieve real-time processing at 30+ FPS.

### Key Features

- **Automatic Frame Detection**: Automatically detect soroban frame and normalize with perspective transform
- **Variable Lane Support**: Support for any soroban from 1 to 27 digits
- **High-Speed Processing**: Achieve 30+ FPS with OpenCV + ExecuTorch
- **Swift 6 Ready**: Full support for modern Swift Concurrency

### Architecture

```
┌─────────────────────────────────────┐
│          AbacusRecognizer           │  ← Public API
├─────────────────────────────────────┤
│  AbacusVision     │  InferenceEngine │  ← Internal
│  (C++ / OpenCV)   │  (ExecuTorch)    │
└─────────────────────────────────────┘
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``AbacusRecognizer``
- ``SorobanResult``

### Configuration

- ``AbacusConfiguration``
- ``InferenceBackend``

### Models

- ``SorobanResult``
- ``SorobanLane``
- ``SorobanDigit``
- ``CellState``

### Errors

- ``AbacusError``

### Advanced

- ``AbacusInferenceEngine``
- ``SorobanInterpreter``
