import Foundation
import CoreVideo

/// Protocol for preprocessing input data before inference
///
/// This protocol abstracts preprocessing operations for dependency inversion.
protocol Preprocessor: Sendable {
    /// Validate CVPixelBuffer format and properties
    /// - Parameter pixelBuffer: Input pixel buffer to validate
    /// - Throws: AbacusError.preprocessingFailed if validation fails
    func validate(_ pixelBuffer: CVPixelBuffer) throws
}

/// Implementation of Preprocessor for CVPixelBuffer validation
final class PreprocessorImpl: Preprocessor {
    private let logger: Logger
    
    init(logger: Logger = .make(category: "ML")) {
        self.logger = logger
    }
    
    func validate(_ pixelBuffer: CVPixelBuffer) throws {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        let supportedFormats: [OSType] = [
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_32RGBA,
            kCVPixelFormatType_24RGB
        ]
        
        guard supportedFormats.contains(pixelFormat) else {
            let formatString = pixelFormatToString(pixelFormat)
            logger.error(
                "Unsupported pixel format",
                metadata: ["format": formatString]
            )
            throw AbacusError.preprocessingFailed(
                reason: "Unsupported pixel format: \(formatString). Supported formats: BGRA, RGBA, RGB"
            )
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard width > 0 && height > 0 else {
            logger.error(
                "Invalid pixel buffer dimensions",
                metadata: ["width": "\(width)", "height": "\(height)"]
            )
            throw AbacusError.preprocessingFailed(
                reason: "Invalid pixel buffer dimensions: \(width)x\(height)"
            )
        }
        
        let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
        guard !isPlanar else {
            logger.error("Planar pixel buffers are not supported")
            throw AbacusError.preprocessingFailed(
                reason: "Planar pixel buffers are not supported"
            )
        }
        
        logger.debug(
            "Pixel buffer validation passed",
            metadata: [
                "width": "\(width)",
                "height": "\(height)",
                "format": pixelFormatToString(pixelFormat)
            ]
        )
    }
    
    private func pixelFormatToString(_ format: OSType) -> String {
        let chars = [
            UInt8((format >> 24) & 0xFF),
            UInt8((format >> 16) & 0xFF),
            UInt8((format >> 8) & 0xFF),
            UInt8(format & 0xFF)
        ]
        return String(bytes: chars, encoding: .ascii) ?? "Unknown(\(format))"
    }
}
