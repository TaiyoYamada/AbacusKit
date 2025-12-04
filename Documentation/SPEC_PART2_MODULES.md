# Part 2: モジュール構成と責務

## 2.1 モジュール一覧

```
AbacusKit/
├── AbacusKit          (Swift)    - Public API / ファサード
├── AbacusVision       (C++)      - OpenCV 画像処理
└── AbacusInference    (Obj-C++)  - ExecuTorch 推論
```

---

## 2.2 AbacusKit (Swift Layer)

### 責務

- **Public API** の提供（アプリからの唯一のエントリポイント）
- **設定管理**（モデルパス、パフォーマンス設定）
- **ドメインモデル**（AbacusResult, CellState 等）
- **オーケストレーション**（Vision → Inference → 解釈）

### ファイル構成

```
AbacusKit/
├── Public/
│   ├── AbacusRecognizer.swift      # メインファサード (actor)
│   ├── AbacusConfiguration.swift   # 設定
│   └── AbacusKitExports.swift      # @_exported import
│
├── Domain/
│   ├── AbacusResult.swift          # 認識結果
│   ├── AbacusValue.swift           # そろばん値
│   ├── CellState.swift             # セル状態 (upper/lower/empty)
│   ├── DigitInfo.swift             # 桁情報
│   └── BoundingBox.swift           # 領域情報
│
├── Core/
│   ├── AbacusInterpreter.swift     # CellState[] → Int 変換
│   ├── AbacusContainer.swift       # DI コンテナ
│   └── AbacusError.swift           # エラー定義
│
└── Internal/
    ├── VisionBridge.swift          # AbacusVision の Swift ラッパー
    └── InferenceBridge.swift       # AbacusInference の Swift ラッパー
```

### 主要クラス

#### AbacusRecognizer (ファサード)

```swift
public actor AbacusRecognizer {
    private let vision: VisionProcessor
    private let inference: InferenceEngine
    private let interpreter: AbacusInterpreter
    
    public init(configuration: AbacusConfiguration) throws
    
    /// フレームを認識
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> AbacusResult
    
    /// 連続認識（安定化付き）
    public func recognizeContinuous(
        pixelBuffer: CVPixelBuffer,
        stabilization: StabilizationStrategy
    ) async throws -> AbacusResult
}
```

---

## 2.3 AbacusVision (C++ Layer)

### 責務

- **画像前処理**（リサイズ、色変換、ノイズ除去）
- **そろばん検出**（輪郭検出、フレーム認識）
- **射影変換**（パースペクティブ補正）
- **セル分割**（ROI 抽出）

### ファイル構成

```
AbacusVision/
├── include/
│   ├── AbacusVision.h              # C インターフェース
│   ├── VisionTypes.h               # C 構造体定義
│   └── module.modulemap            # Swift インポート用
│
├── src/
│   ├── Preprocessor.cpp            # 前処理パイプライン
│   ├── Preprocessor.hpp
│   ├── AbacusDetector.cpp          # そろばんフレーム検出
│   ├── AbacusDetector.hpp
│   ├── CellExtractor.cpp           # セル領域抽出
│   ├── CellExtractor.hpp
│   ├── PerspectiveCorrector.cpp    # 射影変換
│   └── PerspectiveCorrector.hpp
│
└── bridge/
    └── AbacusVisionBridge.mm       # Swift 呼び出し用 ObjC ラッパー
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
    AVTensor* cells;  // 抽出されたセル配列
    int cellCount;
    AVRect* cellRects; // 各セルの元画像上の位置
    float confidence;  // 検出信頼度
} AVExtractionResult;

// 初期化・解放
void* av_create_processor(void);
void av_destroy_processor(void* processor);

// 処理
int av_process_frame(
    void* processor,
    const void* pixelBuffer,  // CVPixelBufferRef
    AVExtractionResult* result
);

// メモリ解放
void av_free_result(AVExtractionResult* result);
```

### 前処理パイプライン詳細

```cpp
class Preprocessor {
public:
    struct Config {
        int targetLongEdge = 1280;      // リサイズ目標
        bool enableCLAHE = true;         // コントラスト強調
        double claheClipLimit = 2.0;
        int adaptiveBlockSize = 11;      // 適応的二値化
        double adaptiveC = 2;
        int morphKernelSize = 3;         // モルフォロジー
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

### 責務

- **ExecuTorch モデルロード**
- **テンソル作成・正規化**
- **推論実行**
- **出力解釈（softmax, argmax）**

### ファイル構成

```
AbacusInference/
├── include/
│   ├── AbacusInference.h           # ObjC インターフェース
│   └── InferenceTypes.h            # 構造体定義
│
└── src/
    ├── ExecuTorchEngine.mm         # 推論エンジン
    ├── TensorConverter.mm          # テンソル変換
    └── BatchPredictor.mm           # バッチ推論最適化
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

// 単一セル推論
- (BOOL)predictSingleCell:(const float *)tensorData
                   result:(AIInferenceResult *)result
                    error:(NSError **)error;

// バッチ推論（複数セル一括）
- (BOOL)predictBatch:(const float *)tensorData
           cellCount:(NSInteger)count
             results:(AIInferenceResult *)results
               error:(NSError **)error;

@property (readonly) BOOL isModelLoaded;

@end
```

---

## 2.5 モジュール間インターフェース

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

## 2.6 依存関係マトリクス

| From \ To | AbacusKit | AbacusVision | AbacusInference | OpenCV | ExecuTorch |
|-----------|-----------|--------------|-----------------|--------|------------|
| **AbacusKit** | - | ✓ | ✓ | - | - |
| **AbacusVision** | - | - | - | ✓ | - |
| **AbacusInference** | - | - | - | - | ✓ (App提供) |
| **App** | ✓ | - | - | - | ✓ (埋め込み) |
