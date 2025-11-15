#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge to C++ TorchScript module
@interface TorchModuleBridge : NSObject

/// Load a TorchScript model from the specified file path
/// - Parameters:
///   - path: File path to the .pt model file
///   - error: Error pointer for failure cases
/// - Returns: YES if model loaded successfully, NO otherwise
- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error;

/// Perform inference on a CVPixelBuffer
/// - Parameters:
///   - pixelBuffer: Input pixel buffer from camera
///   - error: Error pointer for failure cases
/// - Returns: Array of NSNumber containing inference output values, or nil on failure
- (nullable NSArray<NSNumber *> *)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer 
                                                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
