# Part 5: Performance Design & Part 6: Implementation Roadmap

## 5.1 Performance Requirements

| Metric | Target | Realistic Target |
|--------|--------|------------------|
| Frame Rate | 60 FPS | 30 FPS |
| Processing Time per Frame | < 16.7ms | < 33.3ms |
| Memory Usage | < 100MB | < 150MB |
| Model Load Time | < 500ms | < 1000ms |
| Battery Consumption | Low | Medium |

## 5.2 Processing Time Allocation (30 FPS Target)

```
Total Budget: 33.3ms
┌─────────────────────────────────────────────────────────────┐
│ Preprocessing (OpenCV)                           18ms       │
│ ├─ Format conversion                    1ms                 │
│ ├─ Resize                               2ms                 │
│ ├─ Grayscale + CLAHE                    3ms                 │
│ ├─ Binarization + Morphology            3ms                 │
│ ├─ Contour Detection                    2ms                 │
│ ├─ Frame Detection                      2ms                 │
│ ├─ Perspective Transform                2ms                 │
│ └─ Cell Extraction + Normalization      3ms                 │
├─────────────────────────────────────────────────────────────┤
│ Inference (ExecuTorch CoreML)                    12ms       │
│ ├─ Tensor Creation                      1ms                 │
│ ├─ Forward Pass                         10ms                │
│ └─ Softmax + Argmax                     1ms                 │
├─────────────────────────────────────────────────────────────┤
│ Postprocessing (Swift)                            2ms       │
│ ├─ Value Interpretation                 1ms                 │
│ └─ Result Construction                  1ms                 │
├─────────────────────────────────────────────────────────────┤
│ Remaining Buffer                                  1.3ms     │
└─────────────────────────────────────────────────────────────┘
```

## 5.3 Optimization Strategies

### 1. Frame Skipping

```swift
class FrameController {
    private var frameCount = 0
    private let skipInterval: Int
    
    func shouldProcess() -> Bool {
        frameCount += 1
        return frameCount % skipInterval == 0
    }
}

// 60 FPS → 30 FPS processing
let controller = FrameController(skipInterval: 2)
```

### 2. ROI Caching

```swift
actor ROICache {
    private var lastROI: CGRect?
    private var cacheHitCount = 0
    
    func getROI(currentFrame: CVPixelBuffer) -> CGRect? {
        if let roi = lastROI, cacheHitCount < 5 {
            cacheHitCount += 1
            return roi
        }
        return nil
    }
}
```

### 3. Batch Inference

```swift
// Individual inference (slow)
for cell in cells {
    results.append(try engine.predict(cell))
}

// Batch inference (fast)
let batchedCells = cells.chunked(into: 8)
for batch in batchedCells {
    results.append(contentsOf: try engine.predictBatch(batch))
}
```

### 4. Memory Pool

```swift
class TensorPool {
    private var available: [UnsafeMutablePointer<Float>] = []
    
    func acquire(size: Int) -> UnsafeMutablePointer<Float> {
        if let ptr = available.popLast() { return ptr }
        return UnsafeMutablePointer<Float>.allocate(capacity: size)
    }
    
    func release(_ ptr: UnsafeMutablePointer<Float>) {
        available.append(ptr)
    }
}
```

---

## 6.1 Implementation Roadmap

### Phase 1: Foundation (Week 1-2) 🔴 High Priority

| Task | Effort | Dependencies |
|------|--------|--------------|
| Create/integrate OpenCV.xcframework | 3d | - |
| AbacusVision C++ module skeleton | 2d | Above |
| Preprocessing pipeline (Step 1-6) | 3d | Above |
| Swift-C bridge implementation | 2d | Above |

### Phase 2: Soroban Detection (Week 3-4) 🔴 High Priority

| Task | Effort | Dependencies |
|------|--------|--------------|
| Frame detection algorithm | 3d | Phase 1 |
| Perspective transform implementation | 2d | Above |
| Cell division logic | 3d | Above |
| Unit test creation | 2d | Above |

### Phase 3: Inference Integration (Week 5-6) 🟡 Medium Priority

| Task | Effort | Dependencies |
|------|--------|--------------|
| ExecuTorch batch inference support | 2d | Phase 2 |
| Value interpretation logic | 2d | Above |
| Public API integration | 3d | Above |
| E2E test creation | 3d | Above |

### Phase 4: Stabilization & Optimization (Week 7-8) 🟡 Medium Priority

| Task | Effort | Dependencies |
|------|--------|--------------|
| Continuous recognition stabilization | 3d | Phase 3 |
| Performance tuning | 3d | Above |
| Memory optimization | 2d | Above |
| Battery consumption verification | 2d | Above |

### Phase 5: Distribution Preparation (Week 9-10) 🟢 Low Priority

| Task | Effort | Dependencies |
|------|--------|--------------|
| GitHub Releases update mechanism | 3d | Phase 4 |
| Documentation | 3d | Above |
| Sample app creation | 3d | Above |
| CI/CD setup | 2d | Above |

---

## 6.2 Risk Analysis

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| OpenCV binary size bloat | High | Medium | Build only required modules |
| ExecuTorch SPM compatibility | High | High | Switch to XCFramework |
| 30 FPS not achieved | High | Medium | Introduce frame skipping |
| Soroban detection accuracy drop | Medium | Medium | Add training data |
| Memory shortage (older devices) | Medium | Low | Add low-resolution mode |

---

## 6.3 Gap with Current Implementation

| Item | Current | Target | Work Required |
|------|---------|--------|---------------|
| Preprocessing | ImageNet normalization only | OpenCV full pipeline | **Large** |
| Detection | None | Soroban frame detection | **Large** |
| Cell separation | None | Automatic digit/cell division | **Large** |
| Inference | 3-class classification | Batch inference | Medium |
| API | 2 systems (old/new) | Unified API | Medium |
| Model distribution | S3 OTA | GitHub Releases | Small |

---

## 6.4 Recommended Directory Structure (Final)

```
AbacusKit/
├── Package.swift
├── README.md
├── Documentation/
│   ├── SPEC_*.md
│   └── API_REFERENCE.md
│
├── Sources/
│   ├── AbacusKit/
│   │   ├── Public/
│   │   ├── Domain/
│   │   ├── Core/
│   │   └── Internal/
│   │
│   ├── AbacusVision/
│   │   ├── include/
│   │   ├── src/
│   │   └── bridge/
│   │
│   └── AbacusInference/
│       ├── include/
│       └── src/
│
├── Model/
│   └── abacus_v1.pte
│
├── Tests/
├── Examples/
│   └── AbacusSampleApp/
│
└── Frameworks/
    ├── opencv2.xcframework (optional)
    └── README_EXECUTORCH.md
```

---

## 6.5 Next Actions

1. **Immediately**: Create OpenCV.xcframework and integrate with SPM
2. **This week**: Start AbacusVision skeleton and preprocessing pipeline
3. **Next week**: Implement and test soroban frame detection algorithm
4. **Week 2**: Cell division logic and inference integration

---

**Created**: 2025-12-04
**Version**: 2.0
**Status**: Draft (Pending Review)
