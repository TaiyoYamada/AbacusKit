# Part 2: Module Structure and Responsibilities

## 2.1 Module List

```
AbacusKit/
├── AbacusKit          (Swift)    - Public API / Facade
├── AbacusVision       (C++)      - OpenCV image processing
└── AbacusInference    (Obj-C++)  - ExecuTorch inference
```

---

## 2.2 AbacusKit (Swift Layer)

### Responsibilities

- Provide **Public API** (the only entry point from the app)
- **Configuration management** (model path, performance settings)
- **Domain models** (AbacusResult, CellState, etc.)
- **Orchestration** (Vision → Inference → Interpretation)

### File Structure

```
AbacusKit/
├── Public/
│   ├── AbacusRecognizer.swift      # Main facade (actor)
│   ├── AbacusConfiguration.swift   # Configuration
│   └── AbacusKitExports.swift      # @_exported import
│
├── Domain/
│   ├── AbacusResult.swift          # Recognition result
│   ├── AbacusValue.swift           # Soroban value
│   ├── CellState.swift             # Cell state (upper/lower/empty)
│   ├── DigitInfo.swift             # Digit information
│   └── BoundingBox.swift           # Region information
│
├── Core/
│   ├── AbacusInterpreter.swift     # CellState[] → Int conversion
│   ├── AbacusContainer.swift       # DI container
│   └── AbacusError.swift           # Error definitions
│
└── Internal/
    ├── VisionBridge.swift          # Swift wrapper for AbacusVision
    └── InferenceBridge.swift       # Swift wrapper for AbacusInference
```

### Main Classes

#### AbacusRecognizer (Facade)

```swift
public actor AbacusRecognizer {
    private let vision: VisionProcessor
    private let inference: InferenceEngine
    private let interpreter: AbacusInterpreter
    
    public init(configuration: AbacusConfiguration) throws
    
    /// Recognize a frame
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> AbacusResult
    
    /// Continuous recognition (with stabilization)
    public func recognizeContinuous(
        pixelBuffer: CVPixelBuffer,
        stabilization: StabilizationStrategy
    ) async throws -> AbacusResult
}
```

---

## 2.3 AbacusVision (C++ Layer)

### Responsibilities

- **Image preprocessing** (resize, color conversion, noise removal)
- **Soroban detection** (contour detection, frame recognition)
- **Perspective transformation** (perspective correction)
- **Cell division** (ROI extraction)

### File Structure

```
AbacusVision/
├── include/
│   ├── AbacusVision.h              # C interface
│   ├── VisionTypes.h               # C struct definitions
│   └── module.modulemap            # For Swift import
│
├── src/
│   ├── Preprocessor.cpp            # Preprocessing pipeline
│   ├── Preprocessor.hpp
│   ├── AbacusDetector.cpp          # Soroban frame detection
│   ├── AbacusDetector.hpp
│   ├── CellExtractor.cpp           # Cell region extraction
│   ├── CellExtractor.hpp
│   ├── PerspectiveCorrector.cpp    # Perspective transformation
│   └── PerspectiveCorrector.hpp
│
└── bridge/
    └── AbacusVisionBridge.mm       # ObjC wrapper for Swift calls
```

### C Public Interface

```c
// AbacusVision.h

typedef struct {
    float x, y, width, height;
} AVRect;

typedef struct {
    void* data;       // float* (normalized RGB, CHW)
    int width;
    int height;
    int channels;
} AVTensor;

typedef struct {
    AVTensor* cells;  // Array of extracted cells
    int cellCount;
    AVRect* cellRects; // Position of each cell on original image
    float confidence;  // Detection confidence
} AVExtractionResult;

// Initialization / Cleanup
void* av_create_processor(void);
void av_destroy_processor(void* processor);

// Processing
int av_process_frame(
    void* processor,
    const void* pixelBuffer,  // CVPixelBufferRef
    AVExtractionResult* result
);

// Memory cleanup
void av_free_result(AVExtractionResult* result);
```

### Preprocessing Pipeline Details

```cpp
class Preprocessor {
public:
    struct Config {
        int targetLongEdge = 1280;      // Resize target
        bool enableCLAHE = true;         // Contrast enhancement
        double claheClipLimit = 2.0;
        int adaptiveBlockSize = 11;      // Adaptive binarization
        double adaptiveC = 2;
        int morphKernelSize = 3;         // Morphology
    };
    
    cv::Mat preprocess(const cv::Mat& input, const Config& config);
    
private:
    cv::Mat resize(const cv::Mat& input, int targetLongEdge);
    cv::Mat toGrayscale(const cv::Mat& input);
    cv::Mat enhanceContrast(const cv::Mat& gray, const Config& config);
    cv::Mat binarize(const cv::Mat& enhanced, const Config& config);
    cv::Mat morphologyClean(const cv::Mat& binary, const Config& config);
};
```

---

## 2.4 AbacusInference (Obj-C++ Layer)

### Responsibilities

- **ExecuTorch model loading**
- **Tensor creation and normalization**
- **Inference execution**
- **Output interpretation (softmax, argmax)**

### File Structure

```
AbacusInference/
├── include/
│   ├── AbacusInference.h           # ObjC interface
│   └── InferenceTypes.h            # Struct definitions
│
└── src/
    ├── ExecuTorchEngine.mm         # Inference engine
    ├── TensorConverter.mm          # Tensor conversion
    └── BatchPredictor.mm           # Batch inference optimization
```

### ObjC Interface

```objc
// AbacusInference.h

typedef struct {
    NSInteger predictedClass;  // 0: upper, 1: lower, 2: empty
    float probabilities[3];
    double inferenceTimeMs;
} AIInferenceResult;

@interface AbacusInferenceEngine : NSObject

- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error;

// Single cell inference
- (BOOL)predictSingleCell:(const float *)tensorData
                   result:(AIInferenceResult *)result
                    error:(NSError **)error;

// Batch inference (multiple cells at once)
- (BOOL)predictBatch:(const float *)tensorData
           cellCount:(NSInteger)count
             results:(AIInferenceResult *)results
               error:(NSError **)error;

@property (readonly) BOOL isModelLoaded;

@end
```

---

## 2.5 Inter-Module Interfaces

### VisionBridge (Swift ↔ C++)

```swift
// VisionBridge.swift

final class VisionBridge: @unchecked Sendable {
    private let processor: UnsafeMutableRawPointer
    
    init() {
        processor = av_create_processor()
    }
    
    deinit {
        av_destroy_processor(processor)
    }
    
    func extractCells(from pixelBuffer: CVPixelBuffer) throws -> ExtractionResult {
        var cResult = AVExtractionResult()
        let status = av_process_frame(processor, Unmanaged.passUnretained(pixelBuffer).toOpaque(), &cResult)
        defer { av_free_result(&cResult) }
        
        guard status == 0 else {
            throw AbacusError.visionProcessingFailed(code: status)
        }
        
        return ExtractionResult(cResult: cResult)
    }
}
```

### InferenceBridge (Swift ↔ Obj-C++)

```swift
// InferenceBridge.swift

final class InferenceBridge: @unchecked Sendable {
    private let engine: AbacusInferenceEngine
    
    init(modelPath: URL) throws {
        engine = AbacusInferenceEngine()
        try engine.loadModel(atPath: modelPath.path)
    }
    
    func predict(tensorData: UnsafePointer<Float>, cellCount: Int) throws -> [CellState] {
        var results = [AIInferenceResult](repeating: AIInferenceResult(), count: cellCount)
        try engine.predictBatch(tensorData, cellCount: cellCount, results: &results)
        
        return results.map { CellState(rawValue: Int($0.predictedClass))! }
    }
}
```

---

## 2.6 Dependency Matrix

| From \ To | AbacusKit | AbacusVision | AbacusInference | OpenCV | ExecuTorch |
|-----------|-----------|--------------|-----------------|--------|------------|
| **AbacusKit** | - | ✓ | ✓ | - | - |
| **AbacusVision** | - | - | - | ✓ | - |
| **AbacusInference** | - | - | - | - | ✓ (App-provided) |
| **App** | ✓ | - | - | - | ✓ (embedded) |
