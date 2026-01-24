// AbacusVision - Swift Bridge Implementation
// C API の Swift 互換実装

#include "AbacusVisionBridge.h"
#include "AbacusVision.hpp"

#if ABACUS_HAS_OPENCV

// ============================================================
// Helper Functions
// ============================================================

namespace {

/// abacus::Rect → ABRect 変換
ABRect convertRect(const abacus::Rect& r) {
    return ABRect{r.x, r.y, r.width, r.height};
}

/// abacus::Point → ABPoint 変換
ABPoint convertPoint(const abacus::Point& p) {
    return ABPoint{p.x, p.y};
}

/// abacus::Quadrilateral → ABQuadrilateral 変換
ABQuadrilateral convertQuad(const abacus::Quadrilateral& q) {
    ABQuadrilateral result;
    result.topLeft = convertPoint(q.topLeft);
    result.topRight = convertPoint(q.topRight);
    result.bottomRight = convertPoint(q.bottomRight);
    result.bottomLeft = convertPoint(q.bottomLeft);
    return result;
}

/// abacus::FrameDetectionResult → ABFrameResult 変換
ABFrameResult convertFrameResult(const abacus::FrameDetectionResult& f) {
    ABFrameResult result;
    result.detected = f.detected;
    result.corners = convertQuad(f.corners);
    result.boundingBox = convertRect(f.boundingBox);
    result.confidence = f.confidence;
    result.laneCount = f.laneCount;
    return result;
}

} // anonymous namespace

// ============================================================
// C API Implementation
// ============================================================

extern "C" {

void* ab_vision_create(void) {
    try {
        return new abacus::AbacusVision();
    } catch (...) {
        return nullptr;
    }
}

void ab_vision_destroy(void* instance) {
    if (instance) {
        delete static_cast<abacus::AbacusVision*>(instance);
    }
}

int32_t ab_vision_process(
    void* instance,
    const void* pixelBuffer,
    ABExtractionResult* result
) {
    if (!instance || !pixelBuffer || !result) {
        return ABVisionErrorInvalidInput;
    }
    
    // 結果を初期化
    *result = ABExtractionResult{};
    result->success = false;
    
    try {
        abacus::AbacusVision* vision = static_cast<abacus::AbacusVision*>(instance);
        abacus::ExtractionResult cppResult = vision->processPixelBuffer(pixelBuffer);
        
        if (!cppResult.success) {
            return ABVisionErrorFrameNotDetected;
        }
        
        // 基本情報をコピー
        result->success = true;
        result->frame = convertFrameResult(cppResult.frame);
        result->totalCells = cppResult.totalCells;
        result->preprocessingTimeMs = cppResult.preprocessingTimeMs;
        
        // レーン配列をコピー
        result->laneCount = static_cast<int32_t>(cppResult.lanes.size());
        if (result->laneCount > 0) {
            result->lanes = new ABLaneInfo[result->laneCount];
            for (size_t i = 0; i < cppResult.lanes.size(); ++i) {
                const auto& lane = cppResult.lanes[i];
                result->lanes[i].boundingBox = convertRect(lane.boundingBox);
                result->lanes[i].digitIndex = lane.digitIndex;
                result->lanes[i].value = lane.value;
                result->lanes[i].confidence = lane.confidence;
            }
        }
        
        // テンソルデータをコピー
        const auto& tensor = cppResult.tensor;
        if (tensor.data && tensor.batchSize > 0) {
            size_t tensorSize = tensor.size();
            result->tensorData = new float[tensorSize];
            std::memcpy(result->tensorData, tensor.data, tensor.sizeBytes());
            result->tensorBatchSize = tensor.batchSize;
            result->tensorChannels = tensor.channels;
            result->tensorHeight = tensor.height;
            result->tensorWidth = tensor.width;
        }
        
        return ABVisionErrorNone;
        
    } catch (...) {
        return ABVisionErrorOpenCVError;
    }
}

void ab_vision_free_result(ABExtractionResult* result) {
    if (!result) return;
    
    if (result->lanes) {
        delete[] result->lanes;
        result->lanes = nullptr;
    }
    
    if (result->tensorData) {
        delete[] result->tensorData;
        result->tensorData = nullptr;
    }
    
    result->laneCount = 0;
    result->tensorBatchSize = 0;
}

} // extern "C"

#else // !ABACUS_HAS_OPENCV

// Stub implementation when OpenCV is not available
extern "C" {

void* ab_vision_create(void) {
    return nullptr;
}

void ab_vision_destroy(void* /* instance */) {
    // No-op
}

int32_t ab_vision_process(
    void* /* instance */,
    const void* /* pixelBuffer */,
    ABExtractionResult* result
) {
    if (result) {
        *result = ABExtractionResult{};
        result->success = false;
    }
    return ABVisionErrorOpenCVError;
}

void ab_vision_free_result(ABExtractionResult* /* result */) {
    // No-op
}

} // extern "C"

#endif // ABACUS_HAS_OPENCV
