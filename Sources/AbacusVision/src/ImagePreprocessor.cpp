#include "ImagePreprocessor.hpp"

#if ABACUS_HAS_OPENCV
#include <opencv2/imgproc.hpp>
#include <opencv2/photo.hpp>
#include <CoreVideo/CoreVideo.h>

namespace abacus {

ImagePreprocessor::ImagePreprocessor() : config_() {
    initCLAHE();
}

ImagePreprocessor::ImagePreprocessor(const PreprocessingConfig& config) : config_(config) {
    initCLAHE();
}

ImagePreprocessor::~ImagePreprocessor() = default;

void ImagePreprocessor::setConfig(const PreprocessingConfig& config) {
    config_ = config;
    initCLAHE();
}

void ImagePreprocessor::initCLAHE() {
    clahe_ = cv::createCLAHE(
        config_.claheClipLimit,
        cv::Size(config_.claheTileSize, config_.claheTileSize)
    );
}

VisionError ImagePreprocessor::convertFromPixelBuffer(const void* pixelBuffer, cv::Mat& output) {
    if (!pixelBuffer) {
        return VisionError::InvalidInput;
    }
    
    CVPixelBufferRef buffer = (CVPixelBufferRef)pixelBuffer;
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    void* baseAddress = CVPixelBufferGetBaseAddress(buffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer);
    
    if (!baseAddress) {
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        return VisionError::InvalidInput;
    }
    
    cv::Mat temp;
    
    if (pixelFormat == kCVPixelFormatType_32BGRA) {
        temp = cv::Mat(static_cast<int>(height), static_cast<int>(width), CV_8UC4, baseAddress, bytesPerRow);
        cv::cvtColor(temp, output, cv::COLOR_BGRA2BGR);
    } else if (pixelFormat == kCVPixelFormatType_32RGBA) {
        temp = cv::Mat(static_cast<int>(height), static_cast<int>(width), CV_8UC4, baseAddress, bytesPerRow);
        cv::cvtColor(temp, output, cv::COLOR_RGBA2BGR);
    } else {
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        return VisionError::InvalidInput;
    }
    
    output = output.clone();
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return VisionError::None;
}

cv::Mat ImagePreprocessor::resize(const cv::Mat& input) {
    int longEdge = std::max(input.cols, input.rows);
    if (longEdge <= config_.targetLongEdge) {
        return input.clone();
    }
    
    double scale = static_cast<double>(config_.targetLongEdge) / longEdge;
    cv::Mat output;
    cv::resize(input, output, cv::Size(), scale, scale, cv::INTER_LINEAR);
    return output;
}

cv::Mat ImagePreprocessor::toGrayscale(const cv::Mat& input) {
    if (input.channels() == 1) {
        return input.clone();
    }
    
    cv::Mat gray;
    cv::cvtColor(input, gray, cv::COLOR_BGR2GRAY);
    return gray;
}

cv::Mat ImagePreprocessor::applyWhiteBalance(const cv::Mat& input) {
    if (!config_.enableWhiteBalance) {
        return input.clone();
    }
    
    cv::Scalar avg = cv::mean(input);
    double avgGray = (avg[0] + avg[1] + avg[2]) / 3.0;
    
    std::vector<cv::Mat> channels;
    cv::split(input, channels);
    
    for (int i = 0; i < 3; ++i) {
        if (avg[i] > 0) {
            channels[i].convertTo(channels[i], -1, avgGray / avg[i], 0);
        }
    }
    
    cv::Mat output;
    cv::merge(channels, output);
    return output;
}

cv::Mat ImagePreprocessor::applyCLAHE(const cv::Mat& gray) {
    if (!config_.enableCLAHE || gray.channels() != 1) {
        return gray.clone();
    }
    
    cv::Mat output;
    clahe_->apply(gray, output);
    return output;
}

cv::Mat ImagePreprocessor::applyGaussianBlur(const cv::Mat& input) {
    if (!config_.enableGaussianBlur) {
        return input.clone();
    }
    
    cv::Mat output;
    int ksize = config_.gaussianKernelSize;
    if (ksize % 2 == 0) ksize++;
    cv::GaussianBlur(input, output, cv::Size(ksize, ksize), 0);
    return output;
}

cv::Mat ImagePreprocessor::applyBilateralFilter(const cv::Mat& input) {
    if (!config_.enableBilateralFilter) {
        return input.clone();
    }
    
    cv::Mat output;
    cv::bilateralFilter(
        input, output,
        config_.bilateralD,
        config_.bilateralSigmaColor,
        config_.bilateralSigmaSpace
    );
    return output;
}

cv::Mat ImagePreprocessor::adaptiveThreshold(const cv::Mat& gray) {
    if (gray.channels() != 1) {
        return cv::Mat();
    }
    
    cv::Mat binary;
    int blockSize = config_.adaptiveBlockSize;
    if (blockSize % 2 == 0) blockSize++;
    
    cv::adaptiveThreshold(
        gray, binary,
        255,
        cv::ADAPTIVE_THRESH_GAUSSIAN_C,
        cv::THRESH_BINARY,
        blockSize,
        config_.adaptiveC
    );
    return binary;
}

cv::Mat ImagePreprocessor::morphologyClean(const cv::Mat& binary) {
    cv::Mat kernel = cv::getStructuringElement(
        cv::MORPH_RECT,
        cv::Size(config_.morphKernelSize, config_.morphKernelSize)
    );
    
    cv::Mat output;
    cv::morphologyEx(binary, output, cv::MORPH_CLOSE, kernel);
    cv::morphologyEx(output, output, cv::MORPH_OPEN, kernel);
    return output;
}

cv::Mat ImagePreprocessor::detectEdges(const cv::Mat& gray) {
    cv::Mat edges;
    cv::Canny(gray, edges, config_.cannyThreshold1, config_.cannyThreshold2);
    return edges;
}

VisionError ImagePreprocessor::preprocess(
    const cv::Mat& input,
    cv::Mat& preprocessed,
    cv::Mat& binary,
    cv::Mat& edges
) {
    if (input.empty()) {
        return VisionError::InvalidInput;
    }
    
    try {
        cv::Mat resized = resize(input);
        cv::Mat balanced = applyWhiteBalance(resized);
        cv::Mat denoised = applyGaussianBlur(balanced);
        if (config_.enableBilateralFilter) {
            denoised = applyBilateralFilter(denoised);
        }
        cv::Mat gray = toGrayscale(denoised);
        cv::Mat enhanced = applyCLAHE(gray);
        cv::Mat binarized = adaptiveThreshold(enhanced);
        binary = morphologyClean(binarized);
        edges = detectEdges(enhanced);
        preprocessed = denoised;
        
        return VisionError::None;
    } catch (const cv::Exception& e) {
        return VisionError::OpenCVError;
    }
}

} // namespace abacus

#else // !ABACUS_HAS_OPENCV

// Stub implementation when OpenCV is not available
namespace abacus {

ImagePreprocessor::ImagePreprocessor() : config_() {}
ImagePreprocessor::ImagePreprocessor(const PreprocessingConfig& config) : config_(config) {}
ImagePreprocessor::~ImagePreprocessor() = default;
void ImagePreprocessor::setConfig(const PreprocessingConfig& config) { config_ = config; }
void ImagePreprocessor::initCLAHE() {}
VisionError ImagePreprocessor::convertFromPixelBuffer(const void*, cv::Mat&) { return VisionError::OpenCVError; }
cv::Mat ImagePreprocessor::resize(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::toGrayscale(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::applyWhiteBalance(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::applyCLAHE(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::applyGaussianBlur(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::applyBilateralFilter(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::adaptiveThreshold(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::morphologyClean(const cv::Mat& input) { return input; }
cv::Mat ImagePreprocessor::detectEdges(const cv::Mat& input) { return input; }
VisionError ImagePreprocessor::preprocess(const cv::Mat&, cv::Mat&, cv::Mat&, cv::Mat&) { return VisionError::OpenCVError; }

} // namespace abacus

#endif // ABACUS_HAS_OPENCV
