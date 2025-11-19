import CoreVideo
import Nimble
import Quick
import XCTest
@testable import AbacusKit

/// Integration tests for the main Abacus SDK interface
final class AbacusSpec: QuickSpec {
    override class func spec() {
        describe("Abacus") {
            var abacus: Abacus!
            var config: AbacusConfig!

            beforeEach {
                abacus = Abacus()
                config = AbacusConfig(
                    versionURL: URL(string: "https://example.com/version.json")!,
                    modelDirectoryURL: FileManager.default.temporaryDirectory
                )
            }

            describe("initialization") {
                it("should create instance successfully") {
                    expect(abacus).toNot(beNil())
                }
            }

            describe("getMetadata") {
                it("should return metadata") {
                    waitUntil { done in
                        Task {
                            let metadata = await abacus.getMetadata()

                            expect(metadata.sdkVersion).toNot(beEmpty())
                            done()
                        }
                    }
                }
            }

            describe("predict without configuration") {
                it("should throw notConfigured error") {
                    let pixelBuffer = Self.createPixelBuffer()

                    waitUntil { done in
                        Task {
                            do {
                                _ = try await abacus.predict(pixelBuffer: pixelBuffer)
                                fail("Should have thrown error")
                            } catch AbacusError.notConfigured {
                                // Expected error
                            } catch {
                                fail("Unexpected error: \(error)")
                            }
                            done()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    static func createPixelBuffer() -> CVPixelBuffer {
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
            fatalError("Failed to create pixel buffer")
        }

        return buffer
    }
}
