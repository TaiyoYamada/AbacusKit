import CoreVideo
import Nimble
import Quick
import XCTest
@testable import AbacusKit

final class PreprocessorSpec: QuickSpec {
    override class func spec() {
        describe("PreprocessorImpl") {
            var preprocessor: PreprocessorImpl!

            beforeEach {
                preprocessor = PreprocessorImpl()
            }

            describe("validate") {
                it("should accept valid BGRA pixel buffer") {
                    let pixelBuffer = Self.createPixelBuffer(
                        width: 640,
                        height: 480,
                        format: kCVPixelFormatType_32BGRA
                    )
                    let localPreprocessor = preprocessor!

                    expect { try localPreprocessor.validate(pixelBuffer) }.toNot(throwError())
                }

                it("should accept valid RGBA pixel buffer") {
                    let pixelBuffer = Self.createPixelBuffer(
                        width: 640,
                        height: 480,
                        format: kCVPixelFormatType_32RGBA
                    )
                    let localPreprocessor = preprocessor!

                    expect { try localPreprocessor.validate(pixelBuffer) }.toNot(throwError())
                }

                it("should reject unsupported pixel format") {
                    let pixelBuffer = Self.createPixelBuffer(
                        width: 640,
                        height: 480,
                        format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                    )
                    let localPreprocessor = preprocessor!

                    expect { try localPreprocessor.validate(pixelBuffer) }
                        .to(throwError(AbacusError.preprocessingFailed(reason: "")))
                }
            }
        }
    }

    // MARK: - Helper Methods

    static func createPixelBuffer(width: Int, height: Int, format: OSType) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create pixel buffer")
        }

        return buffer
    }
}
