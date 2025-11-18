import XCTest
import Quick
import Nimble
@testable import AbacusKit

final class AbacusConfigSpec: QuickSpec {
    override class func spec() {
        describe("AbacusConfig") {
            var versionURL: URL!
            var modelDirectoryURL: URL!
            
            beforeEach {
                versionURL = URL(string: "https://example.com/version.json")!
                modelDirectoryURL = FileManager.default.temporaryDirectory
            }
            
            describe("initialization") {
                it("should initialize with valid parameters") {
                    let config = AbacusConfig(
                        versionURL: versionURL,
                        modelDirectoryURL: modelDirectoryURL
                    )
                    
                    expect(config.versionURL).to(equal(versionURL))
                    expect(config.modelDirectoryURL).to(equal(modelDirectoryURL))
                    expect(config.forceUpdate).to(beFalse())
                }
                
                it("should initialize with forceUpdate flag") {
                    let config = AbacusConfig(
                        versionURL: versionURL,
                        modelDirectoryURL: modelDirectoryURL,
                        forceUpdate: true
                    )
                    
                    expect(config.forceUpdate).to(beTrue())
                }
            }
            
            describe("validation") {
                it("should validate correct configuration") {
                    let localVersionURL = versionURL!
                    let localModelDirURL = modelDirectoryURL!
                    let config = AbacusConfig(
                        versionURL: localVersionURL,
                        modelDirectoryURL: localModelDirURL
                    )
                    
                    expect { try config.validate() }.toNot(throwError())
                }
                
                it("should reject non-HTTP version URL") {
                    let invalidURL = URL(string: "file:///path/to/version.json")!
                    let localModelDirURL = modelDirectoryURL!
                    let config = AbacusConfig(
                        versionURL: invalidURL,
                        modelDirectoryURL: localModelDirURL
                    )
                    
                    expect { try config.validate() }.to(throwError(AbacusError.invalidConfiguration(reason: "")))
                }
                
                it("should reject non-file model directory URL") {
                    let invalidURL = URL(string: "https://example.com/models")!
                    let localVersionURL = versionURL!
                    let config = AbacusConfig(
                        versionURL: localVersionURL,
                        modelDirectoryURL: invalidURL
                    )
                    
                    expect { try config.validate() }.to(throwError(AbacusError.invalidConfiguration(reason: "")))
                }
            }
        }
    }
}
