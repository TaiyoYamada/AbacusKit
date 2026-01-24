# Performance Optimization

Optimize AbacusKit for your specific use case.

@Metadata {
    @PageKind(article)
}

## Overview

AbacusKit is designed for real-time performance, but different applications
have different requirements. This guide helps you tune the SDK for your needs.

## Understanding the Pipeline

Recognition involves four phases, each with different optimization opportunities:

| Phase | Time | Description |
|-------|------|-------------|
| **Preprocessing** | 2-5ms | Image conversion and enhancement |
| **Detection** | 3-8ms | Frame detection and lane extraction |
| **Inference** | 5-12ms | Neural network bead classification |
| **Postprocessing** | <1ms | Value calculation |

## Configuration Strategies

### For Maximum Speed

Prioritize processing speed when responsiveness is critical:

```swift
var config = AbacusConfiguration.fast
config.maxInputResolution = 640     // Lower resolution
config.frameSkipInterval = 2        // Process alternate frames
config.batchSize = 16               // Larger batches for GPU efficiency
config.enableCLAHE = false          // Skip contrast enhancement
config.enableWhiteBalance = false   // Skip color correction
config.enableNoiseReduction = false // Skip noise filtering
config.confidenceThreshold = 0.5    // Accept lower confidence
```

**Expected performance**: 60+ FPS on iPhone 15 Pro

### For Maximum Accuracy

Prioritize recognition accuracy when reliability is critical:

```swift
var config = AbacusConfiguration.highAccuracy
config.maxInputResolution = 1920    // Higher resolution
config.frameSkipInterval = 1        // Process every frame
config.batchSize = 4                // Smaller batches (more accurate)
config.enableCLAHE = true           // Enhance contrast
config.enableWhiteBalance = true    // Correct colors
config.enableNoiseReduction = true  // Reduce noise
config.confidenceThreshold = 0.9    // Require high confidence
```

**Expected performance**: 25-35 FPS on iPhone 15 Pro

### Balanced Approach

The default configuration balances speed and accuracy:

```swift
let config = AbacusConfiguration.default
// Resolution: 1280px
// All preprocessing enabled
// Confidence threshold: 0.7
```

**Expected performance**: 40-50 FPS on iPhone 15 Pro

## Inference Backend Selection

Different backends suit different scenarios:

```swift
// Neural Engine - Best power efficiency
config.inferenceBackend = .coreml

// GPU - Maximum throughput
config.inferenceBackend = .mps

// CPU - Maximum compatibility
config.inferenceBackend = .xnnpack

// Automatic selection (recommended)
config.inferenceBackend = .auto
```

### Backend Comparison

| Backend | Speed | Power | Availability |
|---------|-------|-------|--------------|
| Core ML | ★★★★ | ★★★★★ | A12+ devices |
| MPS | ★★★★★ | ★★★ | Metal-capable |
| XNNPACK | ★★ | ★★ | All devices |

## Frame Skipping

For battery-sensitive applications, skip frames:

```swift
config.frameSkipInterval = 2  // Process every 2nd frame
config.frameSkipInterval = 3  // Process every 3rd frame
```

**Trade-off**: Increases latency in detecting value changes.

## Monitoring Performance

Enable performance logging during development:

```swift
config.enablePerformanceLogging = true
```

This prints timing breakdowns after each recognition:

```
[AbacusKit] Performance:
  Preprocessing: 3.2ms
  Detection: 5.1ms
  Inference: 8.4ms
  Postprocessing: 0.3ms
  Total: 17.0ms
  FPS: 58.8
```

Access timing programmatically via ``SorobanResult/timing``:

```swift
let result = try await recognizer.recognize(pixelBuffer: frame)
let timing = result.timing

print("Preprocessing: \(timing.preprocessingMs)ms")
print("Inference: \(timing.inferenceMs)ms")
print("Total: \(timing.totalMs)ms")
print("FPS: \(timing.estimatedFPS)")
```

## Memory Optimization

For memory-constrained scenarios:

1. **Lower resolution**: Reduce ``AbacusConfiguration/maxInputResolution``
2. **Smaller batches**: Reduce ``AbacusConfiguration/batchSize``
3. **Single recognizer**: Reuse a single ``AbacusRecognizer`` instance

```swift
// Memory-conscious configuration
var config = AbacusConfiguration.fast
config.maxInputResolution = 480
config.batchSize = 4
```

## Device-Specific Tuning

Consider device capabilities when configuring:

```swift
func optimalConfiguration() -> AbacusConfiguration {
    var config = AbacusConfiguration.default
    
    if ProcessInfo.processInfo.processorCount >= 6 {
        // High-end device
        config.maxInputResolution = 1920
        config.batchSize = 8
    } else {
        // Mid-range device
        config.maxInputResolution = 720
        config.batchSize = 4
        config.frameSkipInterval = 2
    }
    
    return config
}
```
