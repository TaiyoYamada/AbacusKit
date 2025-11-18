import Foundation
import CoreVideo

// MARK: - URL Extensions

extension URL {
    /// Check if URL points to an existing file
    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: self.path)
    }
    
    /// Get file size in bytes
    /// - Returns: File size in bytes, or nil if file doesn't exist
    var fileSize: Int64? {
        guard fileExists else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
}

// MARK: - CVPixelBuffer Extensions

extension CVPixelBuffer {
    /// Get pixel format as a human-readable string
    var pixelFormatString: String {
        let format = CVPixelBufferGetPixelFormatType(self)
        let chars = [
            UInt8((format >> 24) & 0xFF),
            UInt8((format >> 16) & 0xFF),
            UInt8((format >> 8) & 0xFF),
            UInt8(format & 0xFF)
        ]
        return String(bytes: chars, encoding: .ascii) ?? "Unknown(\(format))"
    }
    
    /// Get dimensions as a tuple
    var dimensions: (width: Int, height: Int) {
        return (
            width: CVPixelBufferGetWidth(self),
            height: CVPixelBufferGetHeight(self)
        )
    }
    
    /// Check if pixel buffer is planar
    var isPlanar: Bool {
        return CVPixelBufferIsPlanar(self)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date as ISO8601 string
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
