#ifndef ABACUS_VISION_TYPES_HPP
#define ABACUS_VISION_TYPES_HPP

#include <cstdint>
#include <vector>

namespace abacus {

/// 矩形領域
struct Rect {
    float x;
    float y;
    float width;
    float height;
    
    Rect() : x(0), y(0), width(0), height(0) {}
    Rect(float x_, float y_, float w_, float h_) : x(x_), y(y_), width(w_), height(h_) {}
};

/// 点
struct Point {
    float x;
    float y;
    
    Point() : x(0), y(0) {}
    Point(float x_, float y_) : x(x_), y(y_) {}
};

/// 4頂点（射影変換用）
struct Quadrilateral {
    Point topLeft;
    Point topRight;
    Point bottomRight;
    Point bottomLeft;
};

/// セル状態
enum class CellState : int32_t {
    Upper = 0,   // 上位置（カウントしない）
    Lower = 1,   // 下位置（カウントする）
    Empty = 2    // 検出不能
};

/// 単一セルの推論結果
struct CellPrediction {
    CellState state;
    float probabilities[3];  // [upper, lower, empty]
    float confidence;
};

/// レーン（1桁分）の情報
struct LaneInfo {
    Rect boundingBox;           // 元画像上の位置
    int32_t digitIndex;         // 桁位置（右から0始まり）
    CellPrediction upperBead;   // 上珠
    CellPrediction lowerBeads[4]; // 下珠 (4個)
    int32_t value;              // 計算された値 (0-9)
    float confidence;           // この桁の信頼度
};

/// そろばんフレーム検出結果
struct FrameDetectionResult {
    bool detected;
    Quadrilateral corners;      // 4隅の座標
    Rect boundingBox;           // バウンディングボックス
    float confidence;
    int32_t laneCount;          // 検出されたレーン数
};

/// 前処理済みテンソル（1セル分）
struct CellTensor {
    float* data;                // CHW format (3 × H × W)
    int32_t channels;
    int32_t height;
    int32_t width;
    
    CellTensor() : data(nullptr), channels(3), height(224), width(224) {}
    
    size_t size() const { return channels * height * width; }
    size_t sizeBytes() const { return size() * sizeof(float); }
};

/// バッチテンソル（複数セル分）
struct BatchTensor {
    float* data;                // N × C × H × W
    int32_t batchSize;
    int32_t channels;
    int32_t height;
    int32_t width;
    
    BatchTensor() : data(nullptr), batchSize(0), channels(3), height(224), width(224) {}
    
    size_t size() const { return batchSize * channels * height * width; }
    size_t sizeBytes() const { return size() * sizeof(float); }
};

/// 抽出結果
struct ExtractionResult {
    bool success;
    FrameDetectionResult frame;
    std::vector<LaneInfo> lanes;
    BatchTensor tensor;         // 全セル分のテンソル
    int32_t totalCells;
    double preprocessingTimeMs;
    
    ExtractionResult() : success(false), totalCells(0), preprocessingTimeMs(0) {}
};

/// 前処理設定
struct PreprocessingConfig {
    // リサイズ
    int32_t targetLongEdge = 1280;
    
    // 色補正
    bool enableWhiteBalance = true;
    bool enableCLAHE = true;
    double claheClipLimit = 2.0;
    int32_t claheTileSize = 8;
    
    // ノイズ低減
    bool enableGaussianBlur = true;
    int32_t gaussianKernelSize = 3;
    bool enableBilateralFilter = false;
    int32_t bilateralD = 9;
    double bilateralSigmaColor = 75.0;
    double bilateralSigmaSpace = 75.0;
    
    // エッジ検出
    double cannyThreshold1 = 50.0;
    double cannyThreshold2 = 150.0;
    
    // Hough変換
    double houghRho = 1.0;
    double houghTheta = 0.01745329; // π/180
    int32_t houghThreshold = 100;
    double houghMinLineLength = 50.0;
    double houghMaxLineGap = 10.0;
    
    // 二値化
    int32_t adaptiveBlockSize = 11;
    double adaptiveC = 2.0;
    
    // モルフォロジー
    int32_t morphKernelSize = 3;
    
    // テンソル正規化（ImageNet）
    float meanR = 0.485f;
    float meanG = 0.456f;
    float meanB = 0.406f;
    float stdR = 0.229f;
    float stdG = 0.224f;
    float stdB = 0.225f;
    
    // 出力サイズ
    int32_t cellOutputSize = 224;
};

/// エラーコード
enum class VisionError : int32_t {
    None = 0,
    InvalidInput = 1,
    FrameNotDetected = 2,
    LaneExtractionFailed = 3,
    TensorConversionFailed = 4,
    MemoryAllocationFailed = 5,
    OpenCVError = 6
};

} // namespace abacus

#endif // ABACUS_VISION_TYPES_HPP
