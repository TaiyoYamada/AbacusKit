# AbacusKit API Reference

Complete reference for all public APIs in AbacusKit.

## Table of Contents

- [ExecuTorchInferenceEngine](#executorchinferenceengine)
- [AbacusCellState](#abacuscellstate)
- [ExecuTorchInferenceResult](#executorchinferenceresult)
- [ExecuTorchInferenceError](#executorchinferenceerror)
- [ExecuTorchModuleBridge](#executorchmodulebridge)

---

## ExecuTorchInferenceEngine

The main actor-based inference engine for performing real-time abacus cell state detection.

### Declaration

```swift
public actor ExecuTorchInferenceEngine
```

### Overview

`ExecuTorchInferenceEngine` is the primary interface for loading ExecuTorch models and performing inference. It uses Swift's actor model to ensure thread-safe access and prevent data races.

All methods are `async` and must be called from an async context. The actor serializes all operations, ensuring that model loading and inference operations never conflict.

### Creating an Engine

```swift
public init()
```

Creates a new inference engine instance.

**Example**:
```swift
let engine = ExecuTorchInferenceEngine()
```

**Thread Safety**: Safe to create from any thread.

---

### Loading a Model

```swift
public func loadModel(at modelPath: URL) throws
```

Loads an ExecuTorch model from the specified file path.

#### Parameters

- **modelPath**: `URL`  
  The file URL pointing to a `.pte` (PyTorch ExecuTorch) model file.

#### Throws

- `ExecuTorchInferenceError.modelLoadFailed(_:)` if the model file is invalid, corrupted, or incompatible.

#### Discussion

This method performs the following operations:
1. Validates the file exists at the specified path
2. Loads the ExecuTorch module from the `.pte` file
3. Validates the model structure
4. Loads the "forward" inference method
5. Prepares the model for inference

Model loading is a relatively expensive operation (100-500ms) and should be performed once during initialization, not before each inference.

#### Example

```swift
let modelURL = Bundle.main.url(forResource: "abacus", withExtension: "pte")!
try await engine.loadModel(at: modelURL)
```

#### Performance

- **Time**: 100-500ms (varies by model size)
- **Memory**: Allocates memory for model weights (~50-200MB)

---

### Performing Inference

```swift
public func predict(pixelBuffer: CVPixelBuffer) throws -> ExecuTorchInferenceResult
```

Performs inference on the provided pixel buffer and returns the predicted abacus cell state.

#### Parameters

- **pixelBuffer**: `CVPixelBuffer`  
  The input image containing the abacus cell to classify.  
  **Expected format**: 224×224 pixels, RGB or BGRA format.

#### Returns

`ExecuTorchInferenceResult` containing:
- The predicted cell state (upper, lower, or empty)
- Probability distribution across all three classes
- Inference time in milliseconds

#### Throws

- `ExecuTorchInferenceError.modelNotLoaded` if `loadModel(at:)` hasn't been called
- `ExecuTorchInferenceError.inferenceFailed(_:)` if inference fails
- `ExecuTorchInferenceError.invalidInput(_:)` if the pixel buffer format is unsupported

#### Discussion

The inference pipeline consists of:
1. **Validation**: Checks that a model is loaded
2. **Preprocessing**: Converts pixel buffer to normalized tensor
3. **Inference**: Executes the model forward pass
4. **Postprocessing**: Applies softmax and extracts predictions

The pixel buffer is locked during preprocessing and unlocked immediately after, so the caller retains ownership.

#### Supported Pixel Formats

- `kCVPixelFormatType_32BGRA` (recommended)
- `kCVPixelFormatType_32RGBA`

#### Example

```swift
// From AVCaptureVideoDataOutput
func captureOutput(_ output: AVCaptureOutput, 
                   didOutput sampleBuffer: CMSampleBuffer, 
                   from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    Task {
        do {
            let result = try await engine.predict(pixelBuffer: pixelBuffer)
            print("State: \(result.predictedState), Confidence: \(result.probabilities[result.predictedState.rawValue])")
        } catch {
            print("Prediction failed: \(error)")
        }
    }
}
```

#### Performance

- **Preprocessing**: ~5-10ms
- **Inference**: 10-50ms (varies by backend)
- **Total**: ~15-60ms

---

## AbacusCellState

An enumeration representing the possible states of an abacus cell.

### Declaration

```swift
public enum AbacusCellState: Int, Sendable
```

### Cases

#### `upper`

```swift
case upper = 0
```

The upper bead position (上玉). This represents the "5" bead in traditional Japanese abacus.

#### `lower`

```swift
case lower = 1
```

The lower bead position (下玉). These represent the "1" beads in traditional Japanese abacus.

#### `empty`

```swift
case empty = 2
```

No bead present or visible (玉なし).

### Conformances

- `Int`: Raw value for interoperability with C layer
- `Sendable`: Safe to pass across concurrency domains

### Example

```swift
let result = try await engine.predict(pixelBuffer: buffer)

switch result.predictedState {
case .upper:
    print("Upper bead detected (value: 5)")
case .lower:
    print("Lower bead detected (value: 1)")
case .empty:
    print("No bead detected")
}
```

---

## ExecuTorchInferenceResult

A structure containing the results of an inference operation.

### Declaration

```swift
public struct ExecuTorchInferenceResult: Sendable
```

### Properties

#### `predictedState`

```swift
public let predictedState: AbacusCellState
```

The predicted abacus cell state with the highest probability.

This is the class with the maximum probability from the model's output.

---

#### `probabilities`

```swift
public let probabilities: [Float]
```

The probability distribution across all three possible states.

**Format**: A 3-element array where:
- `probabilities[0]`: Probability of `upper` state
- `probabilities[1]`: Probability of `lower` state
- `probabilities[2]`: Probability of `empty` state

**Range**: Each value is in [0.0, 1.0]  
**Sum**: All values sum to 1.0 (softmax output)

**Example**:
```swift
let result = try await engine.predict(pixelBuffer: buffer)
print("Upper: \(result.probabilities[0])")
print("Lower: \(result.probabilities[1])")
print("Empty: \(result.probabilities[2])")

// Get confidence of predicted class
let confidence = result.probabilities[result.predictedState.rawValue]
```

---

#### `inferenceTimeMs`

```swift
public let inferenceTimeMs: Double
```

The total inference time in milliseconds.

This includes:
- Pixel buffer preprocessing
- Model forward pass
- Softmax postprocessing

**Use case**: Performance monitoring and optimization.

**Example**:
```swift
let result = try await engine.predict(pixelBuffer: buffer)
if result.inferenceTimeMs > 50 {
    print("Warning: Inference is slower than expected")
}
```

---

### Initializer

```swift
public init(predictedState: AbacusCellState, 
            probabilities: [Float], 
            inferenceTimeMs: Double)
```

Creates a new inference result.

---

### Conformances

- `Sendable`: Safe to pass across actor boundaries

---

## ExecuTorchInferenceError

An enumeration of errors that can occur during inference operations.

### Declaration

```swift
public enum ExecuTorchInferenceError: Error, Sendable
```

### Cases

#### `modelNotLoaded`

```swift
case modelNotLoaded
```

Attempted to perform inference before loading a model.

**Recovery**: Call `loadModel(at:)` before `predict(pixelBuffer:)`.

**Example**:
```swift
do {
    let result = try await engine.predict(pixelBuffer: buffer)
} catch ExecuTorchInferenceError.modelNotLoaded {
    print("Error: Model must be loaded first")
    try await engine.loadModel(at: modelURL)
}
```

---

#### `modelLoadFailed`

```swift
case modelLoadFailed(String)
```

Model loading failed with the specified error message.

**Associated Value**: Detailed error description

**Common Causes**:
- File does not exist
- File is corrupted
- Incompatible model format
- Insufficient memory

**Example**:
```swift
do {
    try await engine.loadModel(at: modelURL)
} catch ExecuTorchInferenceError.modelLoadFailed(let message) {
    print("Failed to load model: \(message)")
}
```

---

#### `inferenceFailed`

```swift
case inferenceFailed(String)
```

Inference execution failed with the specified error message.

**Associated Value**: Detailed error description

**Common Causes**:
- Invalid model state
- Backend unavailable
- Out of memory during inference

---

#### `invalidInput`

```swift
case invalidInput(String)
```

The provided input is invalid or unsupported.

**Associated Value**: Detailed error description

**Common Causes**:
- Unsupported pixel buffer format
- Incorrect image dimensions
- Corrupted pixel data

---

## ExecuTorchModuleBridge

Objective-C++ bridge between Swift and ExecuTorch C++ runtime.

> **Note**: This is a low-level bridge class. Most users should use `ExecuTorchInferenceEngine` instead.

### Declaration

```objc
@interface ExecuTorchModuleBridge : NSObject
```

### Methods

#### Loading a Model

```objc
- (BOOL)loadModelAtPath:(NSString *)path 
                  error:(NSError **)error;
```

Loads an ExecuTorch model from the specified file path.

**Parameters**:
- `path`: Path to the `.pte` model file
- `error`: Error output parameter

**Returns**: `YES` if successful, `NO` otherwise

---

#### Performing Prediction

```objc
- (BOOL)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        result:(ExecuTorchPredictionResult *)result
                         error:(NSError **)error;
```

Performs inference on a pixel buffer.

**Parameters**:
- `pixelBuffer`: Input image buffer (224×224)
- `result`: Output prediction result struct
- `error`: Error output parameter

**Returns**: `YES` if successful, `NO` otherwise

---

#### Checking Model Status

```objc
- (BOOL)isModelLoaded;
```

Returns whether a model is currently loaded.

---

### ExecuTorchPredictionResult Structure

C-compatible structure for passing results from Objective-C++ to Swift.

```objc
typedef struct {
    int32_t predictedClass;
    struct {
        float _0;
        float _1;
        float _2;
    } probabilities;
    double inferenceTimeMs;
} ExecuTorchPredictionResult;
```

---

## Usage Examples

### Complete Integration Example

```swift
import AbacusKit
import AVFoundation

class AbacusClassifier {
    private let engine = ExecuTorchInferenceEngine()
    
    func setup() async throws {
        let modelURL = Bundle.main.url(forResource: "abacus_model", 
                                       withExtension: "pte")!
        try await engine.loadModel(at: modelURL)
    }
    
    func classify(_ pixelBuffer: CVPixelBuffer) async throws -> AbacusCellState {
        let result = try await engine.predict(pixelBuffer: pixelBuffer)
        
        // Log confidence
        let confidence = result.probabilities[result.predictedState.rawValue]
        print("Predicted: \(result.predictedState), Confidence: \(confidence)")
        
        // Warn if inference is slow
        if result.inferenceTimeMs > 50 {
            print("⚠️ Slow inference: \(result.inferenceTimeMs)ms")
        }
        
        return result.predictedState
    }
}
```

### Camera Integration Example

```swift
extension AbacusClassifier: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        Task {
            do {
                let state = try await classify(pixelBuffer)
                await updateUI(with: state)
            } catch {
                print("Classification error: \(error)")
            }
        }
    }
    
    @MainActor
    func updateUI(with state: AbacusCellState) {
        // Update your UI
    }
}
```

---

## Thread Safety

- **ExecuTorchInferenceEngine**: Thread-safe (actor)
- **ExecuTorchModuleBridge**: Not thread-safe (wrapped by actor)
- **Result types**: Thread-safe (`Sendable`)

All public APIs are designed to be called from any thread or async context.

---

**Next**: See [GETTING_STARTED.md](GETTING_STARTED.md) for integration guide.
