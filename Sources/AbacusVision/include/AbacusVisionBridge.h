// AbacusVision - Swift Bridge Header
// C インターフェース（Swift から呼び出し可能）

#ifndef ABACUS_VISION_BRIDGE_H
#define ABACUS_VISION_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// Types (C-compatible, Swift 互換)
// ============================================================

/// 矩形領域
typedef struct {
    float x;
    float y;
    float width;
    float height;
} ABRect;

/// 点
typedef struct {
    float x;
    float y;
} ABPoint;

/// 4頂点（射影変換用）
typedef struct {
    ABPoint topLeft;
    ABPoint topRight;
    ABPoint bottomRight;
    ABPoint bottomLeft;
} ABQuadrilateral;

/// そろばんフレーム検出結果
typedef struct {
    bool detected;
    ABQuadrilateral corners;
    ABRect boundingBox;
    float confidence;
    int32_t laneCount;
} ABFrameResult;

/// レーン情報（簡略化版）
typedef struct {
    ABRect boundingBox;
    int32_t digitIndex;
    int32_t value;
    float confidence;
} ABLaneInfo;

/// 抽出結果
typedef struct {
    bool success;
    ABFrameResult frame;
    
    // レーン配列（呼び出し側でメモリ管理）
    ABLaneInfo* lanes;
    int32_t laneCount;
    
    // テンソルデータ（N × C × H × W, CHW format）
    float* tensorData;
    int32_t tensorBatchSize;
    int32_t tensorChannels;
    int32_t tensorHeight;
    int32_t tensorWidth;
    
    // セル総数
    int32_t totalCells;
    
    // 処理時間
    double preprocessingTimeMs;
} ABExtractionResult;

/// エラーコード
typedef enum {
    ABVisionErrorNone = 0,
    ABVisionErrorInvalidInput = 1,
    ABVisionErrorFrameNotDetected = 2,
    ABVisionErrorLaneExtractionFailed = 3,
    ABVisionErrorTensorConversionFailed = 4,
    ABVisionErrorMemoryAllocationFailed = 5,
    ABVisionErrorOpenCVError = 6
} ABVisionError;

// ============================================================
// API Functions
// ============================================================

/// AbacusVision インスタンスを作成
/// @return インスタンスへのポインタ（失敗時は NULL）
void* ab_vision_create(void);

/// AbacusVision インスタンスを破棄
/// @param instance インスタンスへのポインタ
void ab_vision_destroy(void* instance);

/// CVPixelBuffer を処理
/// @param instance AbacusVision インスタンス
/// @param pixelBuffer CVPixelBufferRef
/// @param result 結果を格納する構造体へのポインタ
/// @return エラーコード
int32_t ab_vision_process(
    void* instance,
    const void* pixelBuffer,
    ABExtractionResult* result
);

/// 結果のメモリを解放
/// @param result 解放する結果構造体へのポインタ
void ab_vision_free_result(ABExtractionResult* result);

#ifdef __cplusplus
}
#endif

#endif // ABACUS_VISION_BRIDGE_H
