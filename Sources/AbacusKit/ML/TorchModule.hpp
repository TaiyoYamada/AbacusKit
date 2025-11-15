#ifndef TorchModule_hpp
#define TorchModule_hpp

#include <string>
#include <vector>
#include <CoreVideo/CoreVideo.h>

/// C++ class for TorchScript model inference
class TorchModuleCpp {
public:
    TorchModuleCpp();
    ~TorchModuleCpp();
    
    /// Load a TorchScript model from file path
    /// - Parameter path: File path to the .pt model file
    /// - Returns: true if successful, false otherwise
    bool loadModel(const std::string& path);
    
    /// Perform inference on a CVPixelBuffer
    /// - Parameter pixelBuffer: Input pixel buffer from camera
    /// - Returns: Vector of float values representing model output
    std::vector<float> predict(CVPixelBufferRef pixelBuffer);
    
private:
    void* module; // Opaque pointer to torch::jit::script::Module
    
    /// Convert CVPixelBuffer to torch::Tensor
    /// - Parameter pixelBuffer: Input pixel buffer
    /// - Returns: Opaque pointer to torch::Tensor
    void* pixelBufferToTensor(CVPixelBufferRef pixelBuffer);
};

#endif /* TorchModule_hpp */
