import Cuckoo
import Nimble
import Quick
import XCTest
@testable import AbacusKit

final class ModelCacheSpec: QuickSpec {
    override class func spec() {
        describe("ModelCacheImpl") {
            var cache: ModelCacheImpl!
            var userDefaults: UserDefaults!

            beforeEach {
                // テスト用のUserDefaultsを作成
                userDefaults = UserDefaults(suiteName: "test.abacuskit.cache")!
                userDefaults.removePersistentDomain(forName: "test.abacuskit.cache")

                cache = ModelCacheImpl(userDefaults: userDefaults)
            }

            afterEach {
                userDefaults.removePersistentDomain(forName: "test.abacuskit.cache")
            }

            describe("initial state") {
                it("should have no cached model") {
                    waitUntil { done in
                        Task {
                            let url = await cache.getCurrentModelURL()
                            let version = await cache.getCurrentVersion()

                            expect(url).to(beNil())
                            expect(version).to(beNil())
                            done()
                        }
                    }
                }
            }

            describe("update") {
                it("should cache model information") {
                    let modelURL = URL(fileURLWithPath: "/path/to/model.mlmodelc")
                    let version = 1

                    waitUntil { done in
                        Task { @MainActor in
                            await cache.update(modelURL: modelURL, version: version)

                            let cachedURL = await cache.getCurrentModelURL()
                            let cachedVersion = await cache.getCurrentVersion()

                            expect(cachedURL).to(equal(modelURL))
                            expect(cachedVersion).to(equal(version))
                            done()
                        }
                    }
                }
            }

            describe("clear") {
                it("should clear cached information") {
                    let modelURL = URL(fileURLWithPath: "/path/to/model.mlmodelc")
                    let version = 1

                    waitUntil { done in
                        Task { @MainActor in
                            await cache.update(modelURL: modelURL, version: version)
                            await cache.clear()

                            let cachedURL = await cache.getCurrentModelURL()
                            let cachedVersion = await cache.getCurrentVersion()

                            expect(cachedURL).to(beNil())
                            expect(cachedVersion).to(beNil())
                            done()
                        }
                    }
                }
            }
        }
    }
}
