import Nimble
import Quick
import XCTest
@testable import AbacusKit

final class ModelVersionSpec: QuickSpec {
    override class func spec() {
        describe("ModelVersion") {
            describe("JSON decoding") {
                it("should decode valid JSON") {
                    let json = """
                    {
                        "version": 1,
                        "model_url": "https://example.com/model.zip",
                        "updated_at": "2024-01-01T00:00:00Z"
                    }
                    """

                    let data = json.data(using: .utf8)!
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601

                    let modelVersion = try? decoder.decode(ModelVersion.self, from: data)

                    expect(modelVersion).toNot(beNil())
                    expect(modelVersion?.version).to(equal(1))
                    expect(modelVersion?.modelURL.absoluteString).to(equal("https://example.com/model.zip"))
                    expect(modelVersion?.updatedAt).toNot(beNil())
                }

                it("should decode JSON without updated_at") {
                    let json = """
                    {
                        "version": 2,
                        "model_url": "https://example.com/model_v2.zip"
                    }
                    """

                    let data = json.data(using: .utf8)!
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601

                    let modelVersion = try? decoder.decode(ModelVersion.self, from: data)

                    expect(modelVersion).toNot(beNil())
                    expect(modelVersion?.version).to(equal(2))
                    expect(modelVersion?.updatedAt).to(beNil())
                }
            }

            describe("equality") {
                it("should compare versions correctly") {
                    let version1 = ModelVersion(
                        version: 1,
                        modelURL: URL(string: "https://example.com/model.zip")!
                    )
                    let version2 = ModelVersion(
                        version: 1,
                        modelURL: URL(string: "https://example.com/model.zip")!
                    )
                    let version3 = ModelVersion(
                        version: 2,
                        modelURL: URL(string: "https://example.com/model.zip")!
                    )

                    expect(version1).to(equal(version2))
                    expect(version1).toNot(equal(version3))
                }
            }
        }
    }
}
