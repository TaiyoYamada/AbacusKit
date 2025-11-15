#include "TorchModule.hpp"
#include <torch/script.h>
#include <torch/torch.h>
#include <stdexcept>
#include <CoreGraphics/CoreGraphics.h>

TorchModuleCpp::TorchModuleCpp() : module(nullptr) {}

TorchModuleCpp::~TorchModuleCpp() {
    if (module) {
        delete static_cast<torch::jit::script::Module*>(module);
        module = nullptr;
    }
}

bool TorchModuleCpp::loadModel(const std::string& path) {
    try {
        auto* mod = new torch::jit::script::Module();
        *mod = torch::jit::load(path);
        mod->eval();
        
        // Clean up old module if exists
        if (module) {
            delete static_cast<torch::jit::script::Module*>(module);
        }
        
        module = mod;
        return true;
    } catch (const c10::Error& e) {
        return false;
    } catch (const std::exception& e) {
        return false;
    }
}

std::vector<float> TorchModuleCpp::predict(CVPixelBufferRef pixelBuffer) {
    if (!module) {
        throw std::runtime_error("Model not loaded");
    }
    
    if (!pixelBuffer) {
        throw std::invalid_argument("Pixel buffer is null");
    }
    
    // Convert CVPixelBuffer to tensor
    void* tensorPtr = pixelBufferToTensor(pixelBuffer);
    if (!tensorPtr) {
        throw std::runtime_error("Failed to convert pixel buffer to tensor");
    }
    
    torch::Tensor inputTensor = *static_cast<torch::Tensor*>(tensorPtr);
    delete static_cast<torch::Tensor*>(tensorPtr);
    
    // Run inference
    torch::jit::script::Module* mod = static_cast<torch::jit::script::Module*>(module);
    
    std::vector<torch::jit::IValue> inputs;
    inputs.push_back(inputTensor);
    
    torch::Tensor output;
    {
        torch::NoGradGuard no_grad;
        output = mod->forward(inputs).toTensor();
    }
    
    // Extract output values to vector
    output = output.cpu();
    auto outputAccessor = output.accessor<float, 1>();
    
    std::vector<float> result;
    result.reserve(outputAccessor.size(0));
    
    for (int i = 0; i < outputAccessor.size(0); i++) {
        result.push_back(outputAccessor[i]);
    }
    
    return result;
}

void* TorchModuleCpp::pixelBufferToTensor(CVPixelBufferRef pixelBuffer) {
    // Lock the pixel buffer for reading
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    // Get pixel buffer properties
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    // Get base address of pixel data
    void* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    torch::Tensor* tensor = nullptr;
    
    try {
        // Determine number of channels based on pixel format
        int channels = 0;
        int bytesPerPixel = 0;
        
        if (pixelFormat == kCVPixelFormatType_32BGRA || 
            pixelFormat == kCVPixelFormatType_32RGBA) {
            channels = 3; // We'll extract RGB, ignore alpha
            bytesPerPixel = 4;
        } else if (pixelFormat == kCVPixelFormatType_24RGB) {
            channels = 3;
            bytesPerPixel = 3;
        } else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            throw std::runtime_error("Unsupported pixel format");
        }
        
        // Create tensor with shape [1, C, H, W] (NCHW format)
        tensor = new torch::Tensor(torch::zeros({1, channels, static_cast<long>(height), static_cast<long>(width)}));
        
        auto tensorAccessor = tensor->accessor<float, 4>();
        
        // Convert pixel data to tensor
        // Handle BGRA/RGBA formats
        if (pixelFormat == kCVPixelFormatType_32BGRA) {
            for (size_t y = 0; y < height; y++) {
                uint8_t* row = static_cast<uint8_t*>(baseAddress) + y * bytesPerRow;
                for (size_t x = 0; x < width; x++) {
                    uint8_t* pixel = row + x * bytesPerPixel;
                    // BGRA format: B=0, G=1, R=2, A=3
                    tensorAccessor[0][0][y][x] = pixel[2] / 255.0f; // R
                    tensorAccessor[0][1][y][x] = pixel[1] / 255.0f; // G
                    tensorAccessor[0][2][y][x] = pixel[0] / 255.0f; // B
                }
            }
        } else if (pixelFormat == kCVPixelFormatType_32RGBA) {
            for (size_t y = 0; y < height; y++) {
                uint8_t* row = static_cast<uint8_t*>(baseAddress) + y * bytesPerRow;
                for (size_t x = 0; x < width; x++) {
                    uint8_t* pixel = row + x * bytesPerPixel;
                    // RGBA format: R=0, G=1, B=2, A=3
                    tensorAccessor[0][0][y][x] = pixel[0] / 255.0f; // R
                    tensorAccessor[0][1][y][x] = pixel[1] / 255.0f; // G
                    tensorAccessor[0][2][y][x] = pixel[2] / 255.0f; // B
                }
            }
        } else if (pixelFormat == kCVPixelFormatType_24RGB) {
            for (size_t y = 0; y < height; y++) {
                uint8_t* row = static_cast<uint8_t*>(baseAddress) + y * bytesPerRow;
                for (size_t x = 0; x < width; x++) {
                    uint8_t* pixel = row + x * bytesPerPixel;
                    // RGB format: R=0, G=1, B=2
                    tensorAccessor[0][0][y][x] = pixel[0] / 255.0f; // R
                    tensorAccessor[0][1][y][x] = pixel[1] / 255.0f; // G
                    tensorAccessor[0][2][y][x] = pixel[2] / 255.0f; // B
                }
            }
        }
        
    } catch (...) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        if (tensor) {
            delete tensor;
        }
        throw;
    }
    
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    return tensor;
}
