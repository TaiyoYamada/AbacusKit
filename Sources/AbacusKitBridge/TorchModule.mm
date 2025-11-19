#import "TorchModule.h"
#import "TorchModule.hpp"
#import <Accelerate/Accelerate.h>
#import <CoreVideo/CoreVideo.h>

// Error domain
static NSString * const TorchModuleErrorDomain = @"com.abacuskit.torchmodule";

@implementation TorchModuleBridge {
    std::unique_ptr<abacuskit::TorchInferenceEngine> _engine;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _engine = std::make_unique<abacuskit::TorchInferenceEngine>();
    }
    return self;
}

- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model file not found"}];
        }
        return NO;
    }
    
    try {
        bool success = _engine->loadModel([path UTF8String]);
        if (!success) {
            if (error) {
                *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to load TorchScript model"}];
            }
            return NO;
        }
        return YES;
    } catch (const std::exception& e) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Exception during model loading: %s", e.what()];
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }
}

- (BOOL)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        result:(TorchPredictionResult *)result
                         error:(NSError **)error {
    if (!_engine->isLoaded()) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model not loaded"}];
        }
        return NO;
    }
    
    // PixelBuffer を float 配列に変換
    std::vector<float> inputTensor;
    if (![self convertPixelBuffer:pixelBuffer toTensor:inputTensor error:error]) {
        return NO;
    }
    
    // 推論実行
    NSDate *startTime = [NSDate date];
    std::vector<float> probabilities;
    
    try {
        probabilities = _engine->predict(inputTensor);
    } catch (const std::exception& e) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Inference failed: %s", e.what()];
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }
    
    NSTimeInterval inferenceTime = -[startTime timeIntervalSinceNow] * 1000.0; // ms
    
    // 結果を構造体に格納
    if (probabilities.size() != 3) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:2003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid output size"}];
        }
        return NO;
    }
    
    // 最大確率のクラスを取得
    NSInteger maxIndex = 0;
    float maxProb = probabilities[0];
    for (size_t i = 1; i < probabilities.size(); i++) {
        if (probabilities[i] > maxProb) {
            maxProb = probabilities[i];
            maxIndex = i;
        }
    }
    
    result->predictedClass = maxIndex;
    result->probabilities[0] = probabilities[0];
    result->probabilities[1] = probabilities[1];
    result->probabilities[2] = probabilities[2];
    result->inferenceTimeMs = inferenceTime;
    
    return YES;
}

- (BOOL)isModelLoaded {
    return _engine->isLoaded();
}

#pragma mark - Private Methods

- (BOOL)convertPixelBuffer:(CVPixelBufferRef)pixelBuffer
                  toTensor:(std::vector<float>&)tensor
                     error:(NSError **)error {
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    // 224x224 を想定
    if (width != 224 || height != 224) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:3001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid image size. Expected 224x224"}];
        }
        return NO;
    }
    
    // RGB 形式を想定（BGRA も対応可能）
    if (pixelFormat != kCVPixelFormatType_32BGRA &&
        pixelFormat != kCVPixelFormatType_32RGBA) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:3002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unsupported pixel format"}];
        }
        return NO;
    }
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    // テンソル形状: (1, 3, 224, 224) = 150528 要素
    tensor.resize(1 * 3 * 224 * 224);
    
    // ImageNet 正規化パラメータ
    const float mean[3] = {0.485f, 0.456f, 0.406f};
    const float std[3] = {0.229f, 0.224f, 0.225f};
    
    // CHW 形式に変換 + 正規化
    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            size_t pixelIndex = y * bytesPerRow + x * 4;
            
            uint8_t r, g, b;
            if (pixelFormat == kCVPixelFormatType_32BGRA) {
                b = baseAddress[pixelIndex + 0];
                g = baseAddress[pixelIndex + 1];
                r = baseAddress[pixelIndex + 2];
            } else { // RGBA
                r = baseAddress[pixelIndex + 0];
                g = baseAddress[pixelIndex + 1];
                b = baseAddress[pixelIndex + 2];
            }
            
            // CHW インデックス計算
            size_t hwIndex = y * width + x;
            size_t rIndex = 0 * (height * width) + hwIndex;
            size_t gIndex = 1 * (height * width) + hwIndex;
            size_t bIndex = 2 * (height * width) + hwIndex;
            
            // 正規化: (pixel / 255.0 - mean) / std
            tensor[rIndex] = (r / 255.0f - mean[0]) / std[0];
            tensor[gIndex] = (g / 255.0f - mean[1]) / std[1];
            tensor[bIndex] = (b / 255.0f - mean[2]) / std[2];
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return YES;
}

@end

#pragma mark - C++ Implementation

namespace abacuskit {

bool TorchInferenceEngine::loadModel(const std::string& modelPath) {
    try {
        module_ = std::make_unique<torch::jit::script::Module>(
            torch::jit::load(modelPath)
        );
        module_->eval(); // 推論モードに設定
        return true;
    } catch (const c10::Error& e) {
        return false;
    }
}

std::vector<float> TorchInferenceEngine::predict(const std::vector<float>& inputTensor) {
    if (!isLoaded()) {
        throw std::runtime_error("Model not loaded");
    }
    
    // テンソル作成: (1, 3, 224, 224)
    auto options = torch::TensorOptions().dtype(torch::kFloat32);
    torch::Tensor tensor = torch::from_blob(
        const_cast<float*>(inputTensor.data()),
        {1, 3, 224, 224},
        options
    ).clone(); // clone() で所有権を確保
    
    // 推論実行
    std::vector<torch::jit::IValue> inputs;
    inputs.push_back(tensor);
    
    torch::Tensor output = module_->forward(inputs).toTensor();
    
    // Softmax 適用
    output = torch::softmax(output, 1);
    
    // CPU に移動して vector に変換
    output = output.to(torch::kCPU);
    std::vector<float> result(output.data_ptr<float>(), 
                              output.data_ptr<float>() + output.numel());
    
    return result;
}

} // namespace abacuskit
