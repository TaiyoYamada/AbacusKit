# Performance Optimization Guide

This guide provides strategies and best practices for optimizing AbacusKit inference performance.

## Table of Contents

- [Performance Benchmarks](#performance-benchmarks)
- [Backend Comparison](#backend-comparison)
- [Optimization Strategies](#optimization-strategies)
- [Profiling Tools](#profiling-tools)
- [Best Practices](#best-practices)

## Performance Benchmarks

Typical performance metrics for AbacusKit on recent iOS devices:

### iPhone 15 Pro (A17 Pro)

| Backend | Model Size | Inference Time | Memory | Power |
|---------|-----------|----------------|---------|-------|
| CoreML | 12 MB | 8-12 ms | 45 MB | Very Low |
| MPS | 12 MB | 12-18 ms | 60 MB | Low |
| XNNPACK | 12 MB | 25-35 ms | 50 MB | Medium |
| Quantized (INT8) + CoreML | 3 MB | 6-10 ms | 30 MB | Very Low |

### iPhone 13 (A15 Bionic)

| Backend | Model Size | Inference Time | Memory | Power |
|---------|-----------|----------------|---------|-------|
| CoreML | 12 MB | 12-18 ms | 50 MB | Very Low |
| MPS | 12 MB | 18-25 ms | 65 MB | Low |
| XNNPACK | 12 MB | 35-50 ms | 55 MB | Medium |

### iPad Pro (M2)

| Backend | Model Size | Inference Time | Memory | Power |
|---------|-----------|----------------|---------|-------|
| CoreML | 12 MB | 6-10 ms | 40 MB | Very Low |
| MPS | 12 MB | 8-14 ms | 55 MB | Very Low |
| XNNPACK | 12 MB | 20-30 ms | 50 MB | Low |

**Note**: Benchmarks assume 224×224 RGB input, MobileNetV3-based architecture.

## Backend Comparison

### CoreML Backend

**Hardware**: Apple Neural Engine

**Pros**:
- ✅ Fastest inference (6-12ms)
- ✅ Lowest power consumption
- ✅ Best for battery-powered devices
- ✅ Automatic precision optimization

**Cons**:
- ❌ Limited operator support
- ❌ Requires CoreML-compatible model
- ❌ Not available in iOS Simulator

**Best For**: Production apps with optimized models

**When to Use**:
```python
# Export with CoreML backend
python export_model.py --input model.pt --output model.pte --backend CoreML
```

### MPS (Metal Performance Shaders) Backend

**Hardware**: Apple GPU

**Pros**:
- ✅ Fast inference (12-25ms)
- ✅ Good power efficiency
- ✅ Broader operator support than CoreML
- ✅ Works in iOS Simulator

**Cons**:
- ❌ Higher power than CoreML
- ❌ Slightly larger memory footprint

**Best For**: Models with operators unsupported by CoreML

**When to Use**:
```python
# Export with MPS backend
python export_model.py --input model.pt --output model.pte --backend MPS
```

### XNNPACK Backend

**Hardware**: CPU with SIMD optimizations

**Pros**:
- ✅ Universal compatibility
- ✅ Broadest operator support
- ✅ Predictable performance
- ✅ Works everywhere (simulator included)

**Cons**:
- ❌ Slowest inference (25-50ms)
- ❌ Higher power consumption
- ❌ Not optimal for real-time apps

**Best For**: Development, testing, maximum compatibility

**When to Use**:
```python
# Export with XNNPACK backend
python export_model.py --input model.pt --output model.pte --backend XNNPACK
```

## Optimization Strategies

### Strategy 1: Model Quantization

**Impact**: 4x smaller size, 2-4x faster inference

Quantize your model to INT8 precision:

```python
import torch
from torch.ao.quantization import quantize_dynamic

# Quantize model
quantized_model = quantize_dynamic(
    model,
    {torch.nn.Linear, torch.nn.Conv2d},
    dtype=torch.qint8
)

# Export
exported = export(quantized_model, (example_input,))
```

**Benefits**:
- Model size: 12 MB → 3 MB
- Inference time: 15 ms → 8 ms
- Accuracy loss: <1% (typically)

**Trade-offs**:
- Slight accuracy degradation
- More complex export process

### Strategy 2: Input Resolution Reduction

**Impact**: 4x faster preprocessing, 2x faster inference

Use smaller input resolution when possible:

| Resolution | Preprocessing | Inference | Total | Accuracy |
|-----------|--------------|-----------|-------|----------|
| 224×224 | 8 ms | 15 ms | 23 ms | 100% (baseline) |
| 160×160 | 4 ms | 8 ms | 12 ms | 98.5% |
| 128×128 | 3 ms | 5 ms | 8 ms | 96.2% |

**Implementation**:
```python
# Retrain model with 160×160 inputs instead of 224×224
input_size = 160
```

### Strategy 3: Model Architecture Optimization

**Impact**: Variable (model-dependent)

Choose efficient architectures:

| Architecture | Params | Inference | Accuracy |
|--------------|--------|-----------|----------|
| ResNet-18 | 11.7M | 35 ms | High |
| MobileNetV3-Small | 2.5M | 12 ms | Medium-High |
| EfficientNet-B0 | 5.3M | 18 ms | High |
| Custom Lightweight | 0.8M | 6 ms | Medium |

**Recommendation**: Start with MobileNetV3 for best speed/accuracy trade-off.

### Strategy 4: Batch Processing

**Impact**: Better throughput for multiple images

Process multiple images in a single batch:

```swift
// Instead of processing one by one
for image in images {
    let result = try await engine.predict(pixelBuffer: image)
}

// Process as batch (requires model changes)
let results = try await engine.predictBatch(pixelBuffers: images)
```

**Note**: Requires re-exporting model with batch dimension support.

### Strategy 5: Preprocessing Optimization

**Impact**: 2-3x faster preprocessing

Use Metal for GPU-accelerated preprocessing:

```swift
import MetalKit

func preprocessOnGPU(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
    // Use Metal compute shader for:
    // - Format conversion
    // - Resizing
    // - Normalization
    
    // TODO: Implement Metal preprocessing pipeline
}
```

**Benefits**:
- Preprocessing: 8 ms → 3 ms
- Offloads CPU
- Parallel with other operations

### Strategy 6: Model Caching

**Impact**: Eliminates 100-500ms loading time

Load model once, reuse across multiple predictions:

```swift
// ✅ Good: Load once
class ModelManager {
    private let engine = ExecuTorchInferenceEngine()
    private var isLoaded = false
    
    func initialize() async throws {
        if !isLoaded {
            try await engine.loadModel(at: modelURL)
            isLoaded = true
        }
    }
}

// ❌ Bad: Load repeatedly
func processImage() async throws {
    let engine = ExecuTorchInferenceEngine()
    try await engine.loadModel(at: modelURL)  // Slow!
}
```

## Profiling Tools

### Built-in Performance Measurement

```swift
func measurePerformance() async throws {
    var preprocessingTimes: [Double] = []
    var inferenceTimes: [Double] = []
    var totalTimes: [Double] = []
    
    for _ in 0..<100 {
        let startTotal = CFAbsoluteTimeGetCurrent()
        
        // Measure preprocessing
        let startPreproc = CFAbsoluteTimeGetCurrent()
        let pixelBuffer = createTestPixelBuffer()
        let preprocTime = (CFAbsoluteTimeGetCurrent() - startPreproc) * 1000
        
        // Measure inference
        let result = try await engine.predict(pixelBuffer: pixelBuffer)
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTotal) * 1000
        
        preprocessingTimes.append(preprocTime)
        inferenceTimes.append(result.inferenceTimeMs)
        totalTimes.append(totalTime)
    }
    
    print("Preprocessing: \(average(preprocessingTimes))ms ± \(stdDev(preprocessingTimes))ms")
    print("Inference: \(average(inferenceTimes))ms ± \(stdDev(inferenceTimes))ms")
    print("Total: \(average(totalTimes))ms ± \(stdDev(totalTimes))ms")
}
```

### Instruments (Xcode)

Profile your app with Xcode Instruments:

1. **Time Profiler**:
   - Identify CPU bottlenecks
   - Track function call times
   - Find hot paths

2. **Allocations**:
   - Monitor memory usage
   - Detect memory leaks
   - Track object allocations

3. **Metal System Trace**:
   - Profile GPU operations
   - Analyze shader performance
   - Monitor Metal API calls

**How to Profile**:
```bash
# In Xcode:
# 1. Product → Profile (Cmd+I)
# 2. Select "Time Profiler"
# 3. Record while running inference
# 4. Analyze call tree
```

### MetricKit

Track performance in production:

```swift
import MetricKit

class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Analyze CPU time
            if let cpuMetrics = payload.cpuMetrics {
                print("CPU time: \(cpuMetrics.cumulativeCPUTime)")
            }
            
            // Analyze memory
            if let memoryMetrics = payload.memoryMetrics {
                print("Peak memory: \(memoryMetrics.peakMemoryUsage)")
            }
        }
    }
}
```

## Best Practices

### 1. Async/Await Pattern

Use Swift's concurrency for non-blocking inference:

```swift
// ✅ Good: Non-blocking
Task {
    let result = try await engine.predict(pixelBuffer: buffer)
    await updateUI(result)
}

// ❌ Bad: Blocking main thread
let result = try await engine.predict(pixelBuffer: buffer)  // Don't call from main thread
```

### 2. Frame Throttling

Don't process every camera frame:

```swift
class FrameProcessor {
    private var lastProcessedTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.1  // 10 FPS max
    
    func shouldProcess() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastProcessedTime) >= minimumInterval {
            lastProcessedTime = now
            return true
        }
        return false
    }
}
```

### 3. Buffer Pooling

Reuse pixel buffers to reduce allocations:

```swift
class PixelBufferPool {
    private var buffers: [CVPixelBuffer] = []
    private let maxPoolSize = 5
    
    func acquire() -> CVPixelBuffer? {
        if let buffer = buffers.popLast() {
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
    
    func release(_ buffer: CVPixelBuffer) {
        if buffers.count < maxPoolSize {
            buffers.append(buffer)
        }
    }
}
```

### 4. Warmup Inference

Run a warmup inference to initialize backends:

```swift
func warmupModel() async throws {
    // Create dummy input
    var dummyBuffer: CVPixelBuffer?
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        224, 224,
        kCVPixelFormatType_32BGRA,
        nil,
        &dummyBuffer
    )
    
    // Run warmup inference (discard result)
    if let buffer = dummyBuffer {
        _ = try await engine.predict(pixelBuffer: buffer)
    }
}

// Call after loading model
try await engine.loadModel(at: modelURL)
try await warmupModel()
```

### 5. Monitor Performance in Production

Track inference times in production:

```swift
class PerformanceTracker {
    private var measurements: [Double] = []
    
    func recordInference(timeMs: Double) {
        measurements.append(timeMs)
        
        if measurements.count >= 100 {
            let avg = measurements.reduce(0, +) / Double(measurements.count)
            let p95 = percentile95(measurements)
            
            print("Average: \(avg)ms, P95: \(p95)ms")
            
            // Send to analytics
            Analytics.track("inference_performance", [
                "average_ms": avg,
                "p95_ms": p95
            ])
            
            measurements.removeAll()
        }
    }
}
```

## Performance Checklist

Before deploying to production, verify:

- [ ] Model uses CoreML backend (or MPS if CoreML unsupported)
- [ ] Model is quantized (INT8) if acceptable accuracy loss
- [ ] Input resolution is optimized (balance speed vs accuracy)
- [ ] Model is loaded once at app startup
- [ ] Warmup inference performed after loading
- [ ] Frame rate is throttled (don't process every frame)
- [ ] Profiling done with Instruments
- [ ] Performance metrics tracked in production
- [ ] Memory usage is acceptable (<200 MB)
- [ ] Inference time is acceptable for use case (<50ms for real-time)

## Performance Targets

### Real-Time Video (30 FPS)

- **Latency budget**: <33ms per frame
- **Recommended**: CoreML + Quantization
- **Target inference**: <15ms
- **Preprocessing budget**: <10ms
- **Postprocessing budget**: <8ms

### Near Real-Time (10 FPS)

- **Latency budget**: <100ms per frame
- **Recommended**: CoreML or MPS
- **Target inference**: <50ms
- **More flexibility for accuracy

### Batch Processing

- **Latency**: Not critical
- **Recommended**: Any backend
- **Optimize for**: Throughput, not latency
- **Consider**: Batch inference

## Troubleshooting Slow Performance

### Symptom: Inference >100ms

**Diagnosis**:
```swift
let result = try await engine.predict(pixelBuffer: buffer)
print("Inference time: \(result.inferenceTimeMs)ms")
```

**Solutions**:
1. Check backend (should be CoreML or MPS)
2. Verify model is quantized
3. Reduce input resolution
4. Profile with Instruments

### Symptom: High Memory Usage

**Diagnosis**:
```swift
let memory = ProcessInfo.processInfo.physicalMemory
print("Memory: \(memory / 1024 / 1024) MB")
```

**Solutions**:
1. Use quantized model (4x smaller)
2. Unload unused resources
3. Check for memory leaks with Instruments
4. Reduce buffer pool size

### Symptom: Battery Drain

**Solutions**:
1. Use CoreML backend (lowest power)
2. Throttle frame rate
3. Process only when app is active
4. Reduce inference frequency

---

**Next**: See [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) for advanced usage patterns.
