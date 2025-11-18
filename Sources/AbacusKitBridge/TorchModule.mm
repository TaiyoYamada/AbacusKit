#import "TorchModule.h"

// Error domain for TorchModule errors
static NSString * const TorchModuleErrorDomain = @"com.abacuskit.torchmodule";

@implementation TorchModuleBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        // Bridge is now deprecated - CoreML is used instead
        // This implementation is kept for backward compatibility only
    }
    return self;
}

- (void)dealloc {
    // No cleanup needed
}

- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error {
    // This method is deprecated - CoreML is used instead
    if (error) {
        *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                     code:1001
                                 userInfo:@{NSLocalizedDescriptionKey: @"TorchModule bridge is deprecated. Use CoreML ModelManager instead."}];
    }
    return NO;
}

- (nullable NSArray<NSNumber *> *)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer 
                                                    error:(NSError **)error {
    // This method is deprecated - CoreML is used instead
    if (error) {
        *error = [NSError errorWithDomain:TorchModuleErrorDomain
                                     code:2001
                                 userInfo:@{NSLocalizedDescriptionKey: @"TorchModule bridge is deprecated. Use CoreML ModelManager instead."}];
    }
    return nil;
}

@end
