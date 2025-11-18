import XCTest
import Quick
import Nimble
import Cuckoo
@testable import AbacusKit

final class ModelVersionAPISpec: QuickSpec {
    override class func spec() {
        describe("ModelVersionAPIImpl") {
            var api: ModelVersionAPIImpl!
            var mockSession: URLSession!
            
            beforeEach {
                mockSession = URLSession.shared
                api = ModelVersionAPIImpl(urlSession: mockSession)
            }
            
            describe("fetchVersion") {
                it("should decode valid JSON") {
                    let json = """
                    {
                        "version": 1,
                        "model_url": "https://example.com/model.zip"
                    }
                    """
                    
                    let data = json.data(using: .utf8)!
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let modelVersion = try? decoder.decode(ModelVersion.self, from: data)
                    
                    expect(modelVersion).toNot(beNil())
                    expect(modelVersion?.version).to(equal(1))
                    expect(modelVersion?.modelURL.absoluteString).to(equal("https://example.com/model.zip"))
                }
            }
        }
    }
}
