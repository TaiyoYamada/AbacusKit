# AbacusKit Complete Specification v2.0

> Soroban Recognition SDK - OpenCV Preprocessing + ExecuTorch Inference

## Table of Contents

1. [Part 1: Architecture Overview](./SPEC_PART1_ARCHITECTURE.md)
2. [Part 2: Module Structure and Responsibilities](./SPEC_PART2_MODULES.md)
3. [Part 3: Preprocessing and Inference Pipeline](./SPEC_PART3_PIPELINE.md)
4. [Part 4: API Design and Error Design](./SPEC_PART4_API.md)
5. [Part 5: Performance Design](./SPEC_PART5_PERFORMANCE.md)
6. [Part 6: Implementation Roadmap](./SPEC_PART6_ROADMAP.md)

---

## Executive Summary

### Current Status Analysis

| Item | Current Implementation | Target Specification |
|------|------------------------|---------------------|
| **Preprocessing** | Obj-C++ (ImageNet normalization only) | OpenCV C++ (detection/ROI extraction/normalization) |
| **Inference** | ExecuTorch (.pte) | ExecuTorch (.pte) ✅ |
| **Model Distribution** | S3 OTA updates | GitHub Releases + local cache |
| **Swift API** | 2 systems (Abacus + ExecuTorchInferenceEngine) | Unified single system |
| **Target FPS** | Undefined | 30-60 FPS |

### Key Issues

1. **OpenCV integration not implemented** - Currently only simple normalization
2. **No cell detection logic** - Need to separate whole soroban into individual cells
3. **Output is only 3-class classification** - Need to structure the whole soroban value
4. **Two API systems coexist** - Need to unify `Abacus` and `ExecuTorchInferenceEngine`
5. **SPM + ExecuTorch constraints** - Runtime must be embedded on app side

---

## Quick Reference

### Recommended Directory Structure

```
AbacusKit/
├── Sources/
│   ├── AbacusKit/              # Pure Swift (Public API)
│   │   ├── Core/               # Initialization, configuration, facade
│   │   ├── Domain/             # Domain models
│   │   └── Public/             # Public entry point
│   │
│   ├── AbacusVision/           # OpenCV image processing (C++)
│   │   ├── include/            # Public C headers
│   │   ├── src/                # C++ implementation
│   │   └── bridge/             # Swift-C bridge
│   │
│   └── AbacusInference/        # ExecuTorch inference (Obj-C++)
│       ├── include/            # Public ObjC headers
│       └── src/                # Obj-C++ implementation
│
├── Model/                      # .pte model files
├── Tests/
└── Package.swift
```

### Dependency Diagram

```
[App] ─── import ───▶ [AbacusKit] (Swift)
                           │
                           ├──▶ [AbacusVision] (C++/OpenCV) ─── OpenCV.xcframework
                           │
                           └──▶ [AbacusInference] (Obj-C++) ─── ExecuTorch runtime (App provided)
```

---

## Next Steps

Refer to individual files for details on each part.
