import CoreVideo
import Foundation

/// Utility functions for CVPixelBuffer operations
struct ImageUtils {
    
    /// Validate that a CVPixelBuffer has a supported pixel format
    /// - Parameter pixelBuffer: The pixel buffer to validate
    /// - Returns: True if the format is supported, false otherwise
    static func isSupportedFormat(_ pixelBuffer: CVPixelBuffer) -> Bool {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        // Supported formats: 32BGRA, 32ARGB, 24RGB
        let supportedFormats: [OSType] = [
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_32ARGB,
            kCVPixelFormatType_24RGB
        ]
        
        return supportedFormats.contains(pixelFormat)
    }
    
    /// Get the pixel format type as a human-readable string
    /// - Parameter pixelBuffer: The pixel buffer to inspect
    /// - Returns: String representation of the pixel format
    static func pixelFormatString(_ pixelBuffer: CVPixelBuffer) -> String {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            return "32BGRA"
        case kCVPixelFormatType_32ARGB:
            return "32ARGB"
        case kCVPixelFormatType_24RGB:
            return "24RGB"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return "420YpCbCr8BiPlanarFullRange"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return "420YpCbCr8BiPlanarVideoRange"
        default:
            return "Unknown (\(pixelFormat))"
        }
    }
    
    /// Validate pixel buffer dimensions
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer to validate
    ///   - minWidth: Minimum required width (optional)
    ///   - minHeight: Minimum required height (optional)
    /// - Returns: True if dimensions meet requirements, false otherwise
    static func validateDimensions(
        _ pixelBuffer: CVPixelBuffer,
        minWidth: Int? = nil,
        minHeight: Int? = nil
    ) -> Bool {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        if let minWidth = minWidth, width < minWidth {
            return false
        }
        
        if let minHeight = minHeight, height < minHeight {
            return false
        }
        
        return true
    }
    
    /// Get pixel buffer dimensions
    /// - Parameter pixelBuffer: The pixel buffer to inspect
    /// - Returns: Tuple containing (width, height)
    static func getDimensions(_ pixelBuffer: CVPixelBuffer) -> (width: Int, height: Int) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        return (width, height)
    }
    
    /// Check if pixel buffer is planar (multi-plane format like YUV)
    /// - Parameter pixelBuffer: The pixel buffer to check
    /// - Returns: True if planar, false if interleaved
    static func isPlanar(_ pixelBuffer: CVPixelBuffer) -> Bool {
        return CVPixelBufferIsPlanar(pixelBuffer)
    }
    
    /// Get the number of bytes per row for the pixel buffer
    /// - Parameter pixelBuffer: The pixel buffer to inspect
    /// - Returns: Number of bytes per row
    static func getBytesPerRow(_ pixelBuffer: CVPixelBuffer) -> Int {
        return CVPixelBufferGetBytesPerRow(pixelBuffer)
    }
}
