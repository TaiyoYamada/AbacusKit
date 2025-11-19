#import "ExecuTorchModule.h"
#import <Accelerate/Accelerate.h>
#import <CoreVideo/CoreVideo.h>

// ExecuTorch Objective-C headers
#import <ExecuTorch/ExecuTorchModule.h>
#import <ExecuTorch/ExecuTorchValue.h>
#import <ExecuTorch/ExecuTorchTensor.h>

// Error domain
static NSString * const ExecuTorchModuleErrorDomain = @"com.abacuskit.executorch";

@implementation ExecuTorchModuleBridge {
    ExecuTorchModule *_module;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _module = nil;
    }
    return self;
}

- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model file not found"}];
        }
        return NO;
    }
    
    // ExecuTorch Module を初期化
    _module = [[ExecuTorchModule alloc] initWithFilePath:path];
    
    // モデルをロード
    NSError *loadError = nil;
    if (![_module load:&loadError]) {
        if (error) {
            *error = loadError ?: [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                                      code:1002
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to load model"}];
        }
        _module = nil;
        return NO;
    }
    
    // forward メソッドをロード
    NSError *methodError = nil;
    if (![_module loadMethod:@"forward" error:&methodError]) {
        if (error) {
            *error = methodError ?: [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                                        code:1003
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to load forward method"}];
        }
        _module = nil;
        return NO;
    }
    
    return YES;
}

- (BOOL)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        result:(ExecuTorchPredictionResult *)result
                         error:(NSError **)error {
    if (!_module) {
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model not loaded"}];
        }
        return NO;
    }
    
    // PixelBuffer を float 配列に変換
    NSMutableData *tensorData = [NSMutableData dataWithLength:1 * 3 * 224 * 224 * sizeof(float)];
    if (![self convertPixelBuffer:pixelBuffer toTensorData:tensorData error:error]) {
        return NO;
    }
    
    // 推論実行
    NSDate *startTime = [NSDate date];
    
    // ExecuTorchTensor を作成（1, 3, 224, 224）
    NSArray<NSNumber *> *shape = @[@1, @3, @224, @224];
    ExecuTorchTensor *inputTensor = [[ExecuTorchTensor alloc] initWithData:tensorData
                                                                      shape:shape
                                                                   dataType:ExecuTorchDataTypeFloat];
    
    if (!inputTensor) {
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create input tensor"}];
        }
        return NO;
    }
    
    // ExecuTorchValue でラップ
    ExecuTorchValue *inputValue = [ExecuTorchValue valueWithTensor:inputTensor];
    
    // forward メソッドを実行
    NSError *executeError = nil;
    NSArray<ExecuTorchValue *> *outputs = [_module executeMethod:@"forward"
                                                       withInputs:@[inputValue]
                                                            error:&executeError];
    
    if (!outputs || executeError) {
        if (error) {
            *error = executeError ?: [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                                         code:2003
                                                     userInfo:@{NSLocalizedDescriptionKey: @"Forward execution failed"}];
        }
        return NO;
    }
    
    if (outputs.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:2004
                                     userInfo:@{NSLocalizedDescriptionKey: @"No output from model"}];
        }
        return NO;
    }
    
    // 出力テンソルを取得
    ExecuTorchValue *outputValue = outputs[0];
    if (outputValue.tag != ExecuTorchValueTagTensor) {
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:2005
                                     userInfo:@{NSLocalizedDescriptionKey: @"Output is not a tensor"}];
        }
        return NO;
    }
    
    ExecuTorchTensor *outputTensor = outputValue.tensorValue;
    
    NSTimeInterval inferenceTime = -[startTime timeIntervalSinceNow] * 1000.0; // ms
    
    // 出力データを float 配列として取得（ヒープに確保）
    float *probabilities = (float *)malloc(3 * sizeof(float));
    __block BOOL extractionSuccess = NO;
    
    [outputTensor bytesWithHandler:^(const void *pointer, NSInteger count, ExecuTorchDataType dataType) {
        if (count != 3 || dataType != ExecuTorchDataTypeFloat) {
            return;
        }
        
        const float *outputFloats = (const float *)pointer;
        
        // データをコピー（ブロック外で使用するため）
        memcpy(probabilities, outputFloats, 3 * sizeof(float));
        extractionSuccess = YES;
    }];
    
    if (!extractionSuccess) {
        free(probabilities);
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:2006
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid output size or type. Expected 3 float values"}];
        }
        return NO;
    }
    
    // Softmax を適用（モデルが logits を返す場合）
    float softmaxProbs[3];
    [self applySoftmax:probabilities size:3 output:softmaxProbs];
    
    free(probabilities);
    
    // 最大確率のクラスを取得
    NSInteger maxIndex = 0;
    float maxProb = softmaxProbs[0];
    for (int i = 1; i < 3; i++) {
        if (softmaxProbs[i] > maxProb) {
            maxProb = softmaxProbs[i];
            maxIndex = i;
        }
    }
    
    // 結果を構造体に格納
    result->predictedClass = maxIndex;
    result->probabilities[0] = softmaxProbs[0];
    result->probabilities[1] = softmaxProbs[1];
    result->probabilities[2] = softmaxProbs[2];
    result->inferenceTimeMs = inferenceTime;
    
    return YES;
}

- (BOOL)isModelLoaded {
    return _module != nil && [_module isLoaded];
}

#pragma mark - Private Methods

- (BOOL)convertPixelBuffer:(CVPixelBufferRef)pixelBuffer
              toTensorData:(NSMutableData *)tensorData
                     error:(NSError **)error {
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    // 224x224 を想定
    if (width != 224 || height != 224) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        if (error) {
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
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
            *error = [NSError errorWithDomain:ExecuTorchModuleErrorDomain
                                         code:3002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unsupported pixel format"}];
        }
        return NO;
    }
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    // テンソルデータへのポインタを取得
    float *tensorPtr = (float *)tensorData.mutableBytes;
    
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
            tensorPtr[rIndex] = (r / 255.0f - mean[0]) / std[0];
            tensorPtr[gIndex] = (g / 255.0f - mean[1]) / std[1];
            tensorPtr[bIndex] = (b / 255.0f - mean[2]) / std[2];
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return YES;
}

- (void)applySoftmax:(const float *)input size:(size_t)size output:(float *)output {
    // Softmax: exp(x_i) / sum(exp(x_j))
    float maxVal = input[0];
    for (size_t i = 1; i < size; i++) {
        if (input[i] > maxVal) {
            maxVal = input[i];
        }
    }
    
    float sum = 0.0f;
    for (size_t i = 0; i < size; i++) {
        output[i] = expf(input[i] - maxVal); // 数値安定性のため maxVal を引く
        sum += output[i];
    }
    
    for (size_t i = 0; i < size; i++) {
        output[i] /= sum;
    }
}

@end
