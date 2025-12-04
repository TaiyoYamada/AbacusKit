#include "AbacusVision.hpp"

#if ABACUS_HAS_OPENCV
#include <opencv2/imgproc.hpp>

namespace abacus {

AbacusVision::AbacusVision() : config_() {
    preprocessor_ = std::make_unique<ImagePreprocessor>(config_);
    detector_ = std::make_unique<SorobanDetector>();
    converter_ = std::make_unique<TensorConverter>(config_);
}

AbacusVision::AbacusVision(const PreprocessingConfig& config) : config_(config) {
    preprocessor_ = std::make_unique<ImagePreprocessor>(config_);
    detector_ = std::make_unique<SorobanDetector>();
    converter_ = std::make_unique<TensorConverter>(config_);
}

AbacusVision::~AbacusVision() = default;

void AbacusVision::setConfig(const PreprocessingConfig& config) {
    config_ = config;
    preprocessor_->setConfig(config);
    converter_->setConfig(config);
}

void AbacusVision::setDetectionParams(const SorobanDetector::DetectionParams& params) {
    detector_->setParams(params);
}

ExtractionResult AbacusVision::processPixelBuffer(const void* pixelBuffer) {
    ExtractionResult result;
    auto startTime = std::chrono::high_resolution_clock::now();
    
    cv::Mat image;
    VisionError error = preprocessor_->convertFromPixelBuffer(pixelBuffer, image);
    
    if (error != VisionError::None) {
        result.success = false;
        return result;
    }
    
    result = processInternal(image);
    
    auto endTime = std::chrono::high_resolution_clock::now();
    result.preprocessingTimeMs = std::chrono::duration<double, std::milli>(endTime - startTime).count();
    
    return result;
}

ExtractionResult AbacusVision::processImage(const cv::Mat& image) {
    auto startTime = std::chrono::high_resolution_clock::now();
    ExtractionResult result = processInternal(image);
    auto endTime = std::chrono::high_resolution_clock::now();
    result.preprocessingTimeMs = std::chrono::duration<double, std::milli>(endTime - startTime).count();
    return result;
}

ExtractionResult AbacusVision::processInternal(const cv::Mat& image) {
    ExtractionResult result;
    result.success = false;
    
    if (image.empty()) return result;
    
    cv::Mat preprocessed, binary, edges;
    VisionError error = preprocessor_->preprocess(image, preprocessed, binary, edges);
    
    if (error != VisionError::None) return result;
    
    FrameDetectionResult frame = detector_->detectFrame(preprocessed, binary, edges);
    lastFrame_ = frame;
    result.frame = frame;
    
    if (!frame.detected) return result;
    
    cv::Mat warped = detector_->warpFrame(preprocessed, frame, 800, 200);
    if (warped.empty()) return result;
    
    int laneCount = detector_->detectLaneCount(warped);
    result.frame.laneCount = laneCount;
    if (laneCount <= 0) return result;
    
    std::vector<LaneInfo> lanes = detector_->extractLanes(warped, laneCount);
    result.lanes = lanes;
    
    std::vector<cv::Mat> allCells;
    for (size_t i = 0; i < lanes.size(); ++i) {
        LaneInfo& lane = result.lanes[i];
        cv::Rect roi(
            static_cast<int>(lane.boundingBox.x),
            static_cast<int>(lane.boundingBox.y),
            static_cast<int>(lane.boundingBox.width),
            static_cast<int>(lane.boundingBox.height)
        );
        cv::Mat laneImage = warped(roi);
        std::vector<cv::Mat> cells = detector_->extractCells(laneImage, lane);
        allCells.insert(allCells.end(), cells.begin(), cells.end());
    }
    
    result.totalCells = static_cast<int32_t>(allCells.size());
    
    if (!allCells.empty()) {
        error = converter_->convertBatch(allCells, result.tensor);
        if (error != VisionError::None) return result;
    }
    
    result.success = true;
    return result;
}

cv::Mat AbacusVision::drawDebugOverlay(const cv::Mat& original, const ExtractionResult& result) {
    cv::Mat output = original.clone();
    
    if (!result.success || !result.frame.detected) return output;
    
    std::vector<cv::Point> framePoints = {
        cv::Point(static_cast<int>(result.frame.corners.topLeft.x),
                  static_cast<int>(result.frame.corners.topLeft.y)),
        cv::Point(static_cast<int>(result.frame.corners.topRight.x),
                  static_cast<int>(result.frame.corners.topRight.y)),
        cv::Point(static_cast<int>(result.frame.corners.bottomRight.x),
                  static_cast<int>(result.frame.corners.bottomRight.y)),
        cv::Point(static_cast<int>(result.frame.corners.bottomLeft.x),
                  static_cast<int>(result.frame.corners.bottomLeft.y))
    };
    
    cv::polylines(output, framePoints, true, cv::Scalar(0, 255, 0), 2);
    
    std::string text = "Lanes: " + std::to_string(result.frame.laneCount);
    cv::putText(output, text, cv::Point(10, 30), cv::FONT_HERSHEY_SIMPLEX, 1.0, cv::Scalar(0, 255, 0), 2);
    
    std::string timeText = "Time: " + std::to_string(static_cast<int>(result.preprocessingTimeMs)) + "ms";
    cv::putText(output, timeText, cv::Point(10, 60), cv::FONT_HERSHEY_SIMPLEX, 1.0, cv::Scalar(0, 255, 0), 2);
    
    return output;
}

} // namespace abacus

extern "C" {

void* abacus_vision_create(void) {
    return new abacus::AbacusVision();
}

void abacus_vision_destroy(void* instance) {
    if (instance) {
        delete static_cast<abacus::AbacusVision*>(instance);
    }
}

int32_t abacus_vision_process(void* instance, const void* pixelBuffer, abacus::ExtractionResult* result) {
    if (!instance || !pixelBuffer || !result) {
        return static_cast<int32_t>(abacus::VisionError::InvalidInput);
    }
    
    abacus::AbacusVision* vision = static_cast<abacus::AbacusVision*>(instance);
    *result = vision->processPixelBuffer(pixelBuffer);
    
    return result->success ? static_cast<int32_t>(abacus::VisionError::None)
                           : static_cast<int32_t>(abacus::VisionError::FrameNotDetected);
}

void abacus_vision_free_result(abacus::ExtractionResult* result) {
    if (result) {
        abacus::TensorConverter::freeBatch(result->tensor);
        result->lanes.clear();
    }
}

void abacus_vision_set_config(void* instance, const abacus::PreprocessingConfig* config) {
    if (instance && config) {
        static_cast<abacus::AbacusVision*>(instance)->setConfig(*config);
    }
}

void abacus_vision_set_detection_params(void* instance, const abacus::SorobanDetector::DetectionParams* params) {
    if (instance && params) {
        static_cast<abacus::AbacusVision*>(instance)->setDetectionParams(*params);
    }
}

} // extern "C"

#else // !ABACUS_HAS_OPENCV

namespace abacus {

AbacusVision::AbacusVision() : config_() {}
AbacusVision::AbacusVision(const PreprocessingConfig&) : config_() {}
AbacusVision::~AbacusVision() = default;
void AbacusVision::setConfig(const PreprocessingConfig&) {}
void AbacusVision::setDetectionParams(const SorobanDetector::DetectionParams&) {}
ExtractionResult AbacusVision::processPixelBuffer(const void*) { ExtractionResult r; r.success = false; return r; }
ExtractionResult AbacusVision::processImage(const cv::Mat&) { ExtractionResult r; r.success = false; return r; }
ExtractionResult AbacusVision::processInternal(const cv::Mat&) { ExtractionResult r; r.success = false; return r; }
cv::Mat AbacusVision::drawDebugOverlay(const cv::Mat& o, const ExtractionResult&) { return o; }

} // namespace abacus

extern "C" {

void* abacus_vision_create(void) { return nullptr; }
void abacus_vision_destroy(void*) {}
int32_t abacus_vision_process(void*, const void*, abacus::ExtractionResult*) { return -1; }
void abacus_vision_free_result(abacus::ExtractionResult*) {}
void abacus_vision_set_config(void*, const abacus::PreprocessingConfig*) {}
void abacus_vision_set_detection_params(void*, const abacus::SorobanDetector::DetectionParams*) {}

} // extern "C"

#endif // ABACUS_HAS_OPENCV
