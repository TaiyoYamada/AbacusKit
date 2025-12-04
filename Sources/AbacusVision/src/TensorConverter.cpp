#include "TensorConverter.hpp"

#if ABACUS_HAS_OPENCV
#include <opencv2/imgproc.hpp>
#include <cstring>

namespace abacus {

TensorConverter::TensorConverter() : config_() {}
TensorConverter::TensorConverter(const PreprocessingConfig& config) : config_(config) {}
TensorConverter::~TensorConverter() = default;

VisionError TensorConverter::convertCell(const cv::Mat& cell, CellTensor& tensor) {
    if (cell.empty()) return VisionError::InvalidInput;
    
    try {
        cv::Mat resized;
        cv::resize(cell, resized, cv::Size(config_.cellOutputSize, config_.cellOutputSize));
        
        cv::Mat rgb;
        if (resized.channels() == 3) {
            cv::cvtColor(resized, rgb, cv::COLOR_BGR2RGB);
        } else if (resized.channels() == 1) {
            cv::cvtColor(resized, rgb, cv::COLOR_GRAY2RGB);
        } else {
            return VisionError::InvalidInput;
        }
        
        tensor.channels = 3;
        tensor.height = config_.cellOutputSize;
        tensor.width = config_.cellOutputSize;
        tensor.data = new float[tensor.size()];
        
        if (!tensor.data) return VisionError::MemoryAllocationFailed;
        
        normalize(rgb, tensor.data);
        return VisionError::None;
    } catch (...) {
        return VisionError::TensorConversionFailed;
    }
}

VisionError TensorConverter::convertBatch(const std::vector<cv::Mat>& cells, BatchTensor& batch) {
    if (cells.empty()) return VisionError::InvalidInput;
    
    try {
        batch.batchSize = static_cast<int32_t>(cells.size());
        batch.channels = 3;
        batch.height = config_.cellOutputSize;
        batch.width = config_.cellOutputSize;
        batch.data = new float[batch.size()];
        
        if (!batch.data) return VisionError::MemoryAllocationFailed;
        
        size_t cellSize = batch.channels * batch.height * batch.width;
        
        for (size_t i = 0; i < cells.size(); ++i) {
            cv::Mat resized;
            cv::resize(cells[i], resized, cv::Size(config_.cellOutputSize, config_.cellOutputSize));
            
            cv::Mat rgb;
            if (resized.channels() == 3) {
                cv::cvtColor(resized, rgb, cv::COLOR_BGR2RGB);
            } else if (resized.channels() == 1) {
                cv::cvtColor(resized, rgb, cv::COLOR_GRAY2RGB);
            } else {
                delete[] batch.data;
                batch.data = nullptr;
                return VisionError::InvalidInput;
            }
            
            normalize(rgb, batch.data + i * cellSize);
        }
        
        return VisionError::None;
    } catch (...) {
        if (batch.data) {
            delete[] batch.data;
            batch.data = nullptr;
        }
        return VisionError::TensorConversionFailed;
    }
}

void TensorConverter::normalize(const cv::Mat& input, float* output) {
    int h = input.rows;
    int w = input.cols;
    
    float mean[3] = { config_.meanR, config_.meanG, config_.meanB };
    float std_[3] = { config_.stdR, config_.stdG, config_.stdB };
    
    for (int c = 0; c < 3; ++c) {
        for (int y = 0; y < h; ++y) {
            for (int x = 0; x < w; ++x) {
                uint8_t pixel = input.at<cv::Vec3b>(y, x)[c];
                float normalized = (pixel / 255.0f - mean[c]) / std_[c];
                size_t idx = c * h * w + y * w + x;
                output[idx] = normalized;
            }
        }
    }
}

void TensorConverter::freeTensor(CellTensor& tensor) {
    if (tensor.data) {
        delete[] tensor.data;
        tensor.data = nullptr;
    }
}

void TensorConverter::freeBatch(BatchTensor& batch) {
    if (batch.data) {
        delete[] batch.data;
        batch.data = nullptr;
        batch.batchSize = 0;
    }
}

} // namespace abacus

#else // !ABACUS_HAS_OPENCV

namespace abacus {

TensorConverter::TensorConverter() : config_() {}
TensorConverter::TensorConverter(const PreprocessingConfig& config) : config_(config) {}
TensorConverter::~TensorConverter() = default;

VisionError TensorConverter::convertCell(const cv::Mat&, CellTensor&) {
    return VisionError::OpenCVError;
}

VisionError TensorConverter::convertBatch(const std::vector<cv::Mat>&, BatchTensor&) {
    return VisionError::OpenCVError;
}

void TensorConverter::normalize(const cv::Mat&, float*) {}

void TensorConverter::freeTensor(CellTensor& tensor) {
    if (tensor.data) {
        delete[] tensor.data;
        tensor.data = nullptr;
    }
}

void TensorConverter::freeBatch(BatchTensor& batch) {
    if (batch.data) {
        delete[] batch.data;
        batch.data = nullptr;
        batch.batchSize = 0;
    }
}

} // namespace abacus

#endif // ABACUS_HAS_OPENCV
