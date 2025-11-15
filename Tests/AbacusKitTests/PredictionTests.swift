import XCTest
import CoreVideo
@testable import AbacusKit

final class PredictionTests: XCTestCase {
    
    // MARK: - Test modelNotLoaded Error
    
    func testPredictThrowsModelNotLoadedWhenCalledBeforeConfigure() async throws {
        // Create a fresh Abacus instance (using shared singleton)
        let abacus = Abacus.shared
        
        // Create a dummy pixel buffer
        let pixelBuffer = try createDummyPixelBuffer()
        
        // Attempt to predict without configuring
        do {
            _ = try await abacus.predict(pixelBuffer: pixelBuffer)
            XCTFail("Expected AbacusError.modelNotLoaded to be thrown")
        } catch let error as AbacusError {
            // Verify the correct error is thrown
            if case .modelNotLoaded = error {
                // Test passes
            } else {
                XCTFail("Expected AbacusError.modelNotLoaded, got \(error)")
            }
        } catch {
            XCTFail("Expected AbacusError.modelNotLoaded, got \(error)")
        }
    }
    
    // MARK: - Test Valid PredictionResult Structure
    
    func testPredictionResultStructure() {
        // Create a PredictionResult with known values
        let result = PredictionResult(
            value: 42,
            confidence: 0.95,
            inferenceTimeMs: 150
        )
        
        // Verify all properties are correctly stored
        XCTAssertEqual(result.value, 42)
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(result.inferenceTimeMs, 150)
    }
    
    func testPredictionResultWithDifferentValues() {
        // Test with different values to ensure structure is flexible
        let result = PredictionResult(
            value: 0,
            confidence: 0.0,
            inferenceTimeMs: 0
        )
        
        XCTAssertEqual(result.value, 0)
        XCTAssertEqual(result.confidence, 0.0)
        XCTAssertEqual(result.inferenceTimeMs, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createDummyPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            640,
            480,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(
                domain: "PredictionTests",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"]
            )
        }
        
        return buffer
    }
}
