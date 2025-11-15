import XCTest
@testable import AbacusKit

final class ModelCacheTests: XCTestCase {
    
    var mockUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Create a unique suite name for each test to avoid conflicts
        let suiteName = "com.abacuskit.tests.\(UUID().uuidString)"
        mockUserDefaults = UserDefaults(suiteName: suiteName)!
    }
    
    override func tearDown() {
        // Clean up UserDefaults
        if let suiteName = mockUserDefaults.dictionaryRepresentation().keys.first {
            mockUserDefaults.removePersistentDomain(forName: suiteName)
        }
        mockUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Test Update Method
    
    func testUpdateStoresModelURLAndVersion() async {
        // Create ModelCache with mock UserDefaults
        let modelCache = ModelCache(userDefaults: mockUserDefaults)
        
        // Create test URL and version
        let testURL = URL(string: "file:///path/to/model_v5.pt")!
        let testVersion = 5
        
        // Update the cache
        await modelCache.update(modelURL: testURL, version: testVersion)
        
        // Verify the values are stored in the actor
        let storedURL = await modelCache.currentModelURL
        let storedVersion = await modelCache.currentVersion
        
        XCTAssertEqual(storedURL, testURL)
        XCTAssertEqual(storedVersion, testVersion)
        
        // Verify persistence to UserDefaults
        let persistedURLString = mockUserDefaults.string(forKey: "com.abacuskit.modelURL")
        let persistedVersion = mockUserDefaults.integer(forKey: "com.abacuskit.modelVersion")
        
        XCTAssertEqual(persistedURLString, testURL.absoluteString)
        XCTAssertEqual(persistedVersion, testVersion)
    }
    
    func testUpdateOverwritesPreviousValues() async {
        // Create ModelCache with mock UserDefaults
        let modelCache = ModelCache(userDefaults: mockUserDefaults)
        
        // Set initial values
        let initialURL = URL(string: "file:///path/to/model_v3.pt")!
        let initialVersion = 3
        await modelCache.update(modelURL: initialURL, version: initialVersion)
        
        // Update with new values
        let newURL = URL(string: "file:///path/to/model_v7.pt")!
        let newVersion = 7
        await modelCache.update(modelURL: newURL, version: newVersion)
        
        // Verify new values are stored
        let storedURL = await modelCache.currentModelURL
        let storedVersion = await modelCache.currentVersion
        
        XCTAssertEqual(storedURL, newURL)
        XCTAssertEqual(storedVersion, newVersion)
    }
    
    // MARK: - Test Clear Method
    
    func testClearRemovesModelInfo() async {
        // Create ModelCache with mock UserDefaults
        let modelCache = ModelCache(userDefaults: mockUserDefaults)
        
        // Set initial values
        let testURL = URL(string: "file:///path/to/model_v5.pt")!
        let testVersion = 5
        await modelCache.update(modelURL: testURL, version: testVersion)
        
        // Verify values are set
        var storedURL = await modelCache.currentModelURL
        var storedVersion = await modelCache.currentVersion
        XCTAssertNotNil(storedURL)
        XCTAssertNotNil(storedVersion)
        
        // Clear the cache
        await modelCache.clear()
        
        // Verify values are cleared
        storedURL = await modelCache.currentModelURL
        storedVersion = await modelCache.currentVersion
        
        XCTAssertNil(storedURL)
        XCTAssertNil(storedVersion)
        
        // Verify UserDefaults are cleared
        let persistedURLString = mockUserDefaults.string(forKey: "com.abacuskit.modelURL")
        let persistedVersionExists = mockUserDefaults.object(forKey: "com.abacuskit.modelVersion") != nil
        
        XCTAssertNil(persistedURLString)
        XCTAssertFalse(persistedVersionExists)
    }
    
    func testClearOnEmptyCacheDoesNotCrash() async {
        // Create ModelCache with mock UserDefaults
        let modelCache = ModelCache(userDefaults: mockUserDefaults)
        
        // Clear without setting any values (should not crash)
        await modelCache.clear()
        
        // Verify values are nil
        let storedURL = await modelCache.currentModelURL
        let storedVersion = await modelCache.currentVersion
        
        XCTAssertNil(storedURL)
        XCTAssertNil(storedVersion)
    }
    
    // MARK: - Test Actor Isolation
    
    func testActorIsolationWithConcurrentAccess() async {
        // Create ModelCache with mock UserDefaults
        let modelCache = ModelCache(userDefaults: mockUserDefaults)
        
        // Perform concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    let url = URL(string: "file:///path/to/model_v\(i).pt")!
                    await modelCache.update(modelURL: url, version: i)
                }
            }
        }
        
        // Verify final state is consistent (should be one of the versions)
        let finalURL = await modelCache.currentModelURL
        let finalVersion = await modelCache.currentVersion
        
        XCTAssertNotNil(finalURL)
        XCTAssertNotNil(finalVersion)
        
        // Verify the URL and version match
        if let finalVersion = finalVersion {
            XCTAssertTrue(finalURL?.absoluteString.contains("model_v\(finalVersion).pt") ?? false)
        }
    }
    
    func testActorIsolationPreventsConcurrentModification() async {
        // Create ModelCache with mock UserDefaults
        let modelCache = ModelCache(userDefaults: mockUserDefaults)
        
        // Set initial value
        let initialURL = URL(string: "file:///path/to/model_v1.pt")!
        await modelCache.update(modelURL: initialURL, version: 1)
        
        // Perform concurrent read and write operations
        async let readTask1 = modelCache.currentVersion
        async let readTask2 = modelCache.currentModelURL
        async let writeTask = modelCache.update(
            modelURL: URL(string: "file:///path/to/model_v2.pt")!,
            version: 2
        )
        
        // Wait for all tasks to complete
        _ = await (readTask1, readTask2, writeTask)
        
        // Verify final state is consistent
        let finalVersion = await modelCache.currentVersion
        XCTAssertNotNil(finalVersion)
        XCTAssertTrue(finalVersion == 1 || finalVersion == 2)
    }
    
    // MARK: - Test Persistence Across Instances
    
    func testPersistenceAcrossInstances() async {
        // Create first ModelCache instance
        let modelCache1 = ModelCache(userDefaults: mockUserDefaults)
        
        // Set values
        let testURL = URL(string: "file:///path/to/model_v5.pt")!
        let testVersion = 5
        await modelCache1.update(modelURL: testURL, version: testVersion)
        
        // Create second ModelCache instance with same UserDefaults
        let modelCache2 = ModelCache(userDefaults: mockUserDefaults)
        
        // Verify values are loaded from UserDefaults
        let loadedURL = await modelCache2.currentModelURL
        let loadedVersion = await modelCache2.currentVersion
        
        XCTAssertEqual(loadedURL, testURL)
        XCTAssertEqual(loadedVersion, testVersion)
    }
}
