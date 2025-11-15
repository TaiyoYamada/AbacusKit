import Foundation
import CoreVideo

/// Preprocessor for validating CVPixelBuffer inputs before inference
struct Preprocessor {
    
    /// Validate CVPixelBuffer format and properties
    /// - Parameter pixelBuffer: Input pixel buffer to validate
    /// - Throws: AbacusError.preprocessingFailed if validation fails
    func validate(_ pixelBuffer: CVPixelBuffer) throws {
        // Check pixel format
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        let supportedFormats: [OSType] = [
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_32RGBA,
            kCVPixelFormatType_24RGB
        ]
        
        guard supportedFormats.contains(pixelFormat) else {
            let formatString = String(format: "%c%c%c%c",
                                    (pixelFormat >> 24) & 0xFF,
                                    (pixelFormat >> 16) & 0xFF,
                                    (pixelFormat >> 8) & 0xFF,
                                    pixelFormat & 0xFF)
            throw AbacusError.preprocessingFailed(
                reason: "Unsupported pixel format: \(formatString). Supported formats: BGRA, RGBA, RGB"
            )
        }
        
        // Check dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard width > 0 && height > 0 else {
            throw AbacusError.preprocessingFailed(
                reason: "Invalid pixel buffer dimensions: \(width)x\(height)"
            )
        }
        
        // Check if pixel buffer is planar (we only support non-planar formats)
        let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
        guard !isPlanar else {
            throw AbacusError.preprocessingFailed(
                reason: "Planar pixel buffers are not supported"
            )
        }
    }
}
