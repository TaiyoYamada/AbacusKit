# Part 1: Architecture Overview

## 1.1 System Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              iOS Application                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  AVFoundation (Camera)                                                   │ │
│  │  CMSampleBuffer → CVPixelBuffer (1920x1080 / 30-60 FPS)                 │ │
│  └───────────────────────────────────┬─────────────────────────────────────┘ │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                           AbacusKit SDK                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │ │
│  │  │  AbacusKit (Swift) - Public API Layer                           │    │ │
│  │  │  • AbacusRecognizer (main facade)                               │    │ │
│  │  │  • AbacusConfiguration                                          │    │ │
│  │  │  • AbacusResult / AbacusValue / CellState                       │    │ │
│  │  └────────────────────────────────┬────────────────────────────────┘    │ │
│  │                                   │                                      │ │
│  │            ┌──────────────────────┴──────────────────────┐              │ │
│  │            ▼                                              ▼              │ │
│  │  ┌──────────────────────────┐        ┌──────────────────────────────┐   │ │
│  │  │  AbacusVision (C++)      │        │  AbacusInference (Obj-C++)   │   │ │
│  │  │  • Image preprocessing   │        │  • ExecuTorch inference      │   │ │
│  │  │  • Soroban detection     │        │  • Tensor conversion         │   │ │
│  │  │  • ROI extraction        │        │  • softmax/argmax            │   │ │
│  │  │  • Cell separation       │        │                              │   │ │
│  │  └──────────┬───────────────┘        └──────────────┬───────────────┘   │ │
│  │             │                                        │                   │ │
│  │             ▼                                        ▼                   │ │
│  │  ┌──────────────────────────┐        ┌──────────────────────────────┐   │ │
│  │  │  OpenCV.xcframework      │        │  ExecuTorch Runtime          │   │ │
│  │  │  (bundled or App-provided)│       │  (must be embedded in App)   │   │ │
│  │  └──────────────────────────┘        └──────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  App UI Layer                                                            │ │
│  │  AbacusResult → Display / Save / Validate                               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1.2 Layer Structure

| Layer | Language | Responsibilities | Dependencies |
|-------|----------|------------------|--------------|
| **AbacusKit** | Swift | Public API / Facade / Domain Models | AbacusVision, AbacusInference |
| **AbacusVision** | C++ | OpenCV Image Processing / Cell Detection | OpenCV.xcframework |
| **AbacusInference** | Obj-C++ | ExecuTorch Inference / Tensor Operations | ExecuTorch (App-provided) |

## 1.3 Data Flow

```
CVPixelBuffer (1920x1080, BGRA)
    │
    ▼  [AbacusVision::preprocess()]
┌─────────────────────────────────┐
│ 1. Resize (long edge 1280px)    │
│ 2. Grayscale conversion         │
│ 3. Contrast enhancement (CLAHE) │
│ 4. Binarization (adaptive threshold) │
│ 5. Contour detection            │
│ 6. Soroban frame detection      │
│ 7. Perspective transformation   │
│ 8. Digit/cell region division   │
└─────────────────────────────────┘
    │
    ▼  N Cell ROIs (224x224 RGB float tensor)
    │
    ▼  [AbacusInference::predict()]
┌─────────────────────────────────┐
│ 1. ImageNet normalization       │
│ 2. ExecuTorch forward()         │
│ 3. softmax + argmax             │
│ 4. CellState (upper/lower/empty)│
└─────────────────────────────────┘
    │
    ▼  CellState[] (state of each cell)
    │
    ▼  [AbacusKit::interpret()]
┌─────────────────────────────────┐
│ 1. Calculate value from upper/lower bead states │
│ 2. Aggregate by digit           │
│ 3. Convert to integer           │
└─────────────────────────────────┘
    │
    ▼  AbacusResult { value: Int, cells: [CellState], confidence: Float }
```

## 1.4 SPM Constraints and Workarounds

### Issues

1. **ExecuTorch dependency resolution is unstable via SwiftPM**
2. **OpenCV needs to be distributed as XCFramework**
3. **C++ module cross-referencing is complex**

### Solutions

| Constraint | Workaround |
|------------|------------|
| ExecuTorch SPM dependency | **Embed as XCFramework on app side**. AbacusKit references with `@_implementationOnly import` |
| OpenCV distribution | **Bundle in AbacusKit** or **provide from app side** (configurable) |
| C++ module separation | Use **modulemap** to expose as clang modules |

### Package.swift Structure

```swift
targets: [
    // Pure Swift - Public API
    .target(
        name: "AbacusKit",
        dependencies: ["AbacusVision", "AbacusInference"]
    ),
    
    // C++ OpenCV image processing
    .target(
        name: "AbacusVision",
        dependencies: [],
        cxxSettings: [.unsafeFlags(["-std=c++17"])],
        linkerSettings: [.linkedFramework("opencv2")]
    ),
    
    // Obj-C++ ExecuTorch inference
    .target(
        name: "AbacusInference",
        dependencies: [],
        // ExecuTorch is expected to be provided by the App
        cxxSettings: [.unsafeFlags(["-std=c++17"])]
    )
]
```

## 1.5 Design Principles

1. **Separation of Concerns**: Clearly separate preprocessing, inference, and interpretation
2. **Protocol-Oriented**: All major components abstracted through protocols
3. **Swift 6 Ready**: Thread safety guaranteed with actors and Sendable
4. **Testability**: All dependencies replaceable via DI container
5. **Offline Operation**: No network required (model bundled or pre-downloaded)
