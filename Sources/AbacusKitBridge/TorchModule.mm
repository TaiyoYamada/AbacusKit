#import "TorchModule.h"
#import "TorchModule.hpp"

// Error domain for TorchModule errors
static NSString * const TorchModuleErrorDomain = @"com.abacuskit.torchmodule";

@implementation TorchModuleBridge {
    TorchModuleCpp *_module;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _module = new TorchModuleCpp();
    }
    return self;
}

- (void)dealloc {
    if (_module) {
        delete _module;
        _module = nullptr;
    }
}

- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error {
    if (!path || path.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model path is empty"}];
        }
        return NO;
    }
    
    try {
        std::string cppPath = [path UTF8String];
        bool success = _module->loadModel(cppPath);
        
        if (!success) {
            if (error) {
                *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to load model"}];
            }
            return NO;
        }
        
        return YES;
    } catch (const std::exception& e) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"C++ exception: %s", e.what()];
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        }
        return NO;
    } catch (...) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unknown C++ exception"}];
        }
        return NO;
    }
}

- (nullable NSArray<NSNumber *> *)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer 
                                                    error:(NSError **)error {
    if (!pixelBuffer) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Pixel buffer is null"}];
        }
        return nil;
    }
    
    try {
        std::vector<float> output = _module->predict(pixelBuffer);
        
        // Convert std::vector<float> to NSArray<NSNumber *>
        NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:output.size()];
        for (float value : output) {
            [result addObject:@(value)];
        }
        
        return [result copy];
    } catch (const std::exception& e) {
        if (error) {
            NSString *errorMessage = [NSString stringWithFormat:@"Inference failed: %s", e.what()];
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        }
        return nil;
    } catch (...) {
        if (error) {
            *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                         code:2003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unknown inference error"}];
        }
        return nil;
    }
}

@end
