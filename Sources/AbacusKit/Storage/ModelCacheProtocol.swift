import Foundation

/// Protocol for managing cached model information
///
/// This protocol abstracts model cache operations for dependency inversion.
/// The cache stores information about the currently loaded model.
protocol ModelCache: Sendable {
    /// Get the current model URL
    /// - Returns: URL of the currently cached model, or nil if none
    func getCurrentModelURL() async -> URL?
    
    /// Get the current model version
    /// - Returns: Version number of the currently cached model, or nil if none
    func getCurrentVersion() async -> Int?
    
    /// Update cached model information
    /// - Parameters:
    ///   - modelURL: Local URL of model file
    ///   - version: Model version number
    func update(modelURL: URL, version: Int) async
    
    /// Clear cached model information
    func clear() async
}

/// Implementation of ModelCache using UserDefaults for persistence
actor ModelCacheImpl: ModelCache {
    private var currentModelURL: URL?
    private var currentVersion: Int?
    
    private let userDefaults: UserDefaults
    private let logger: Logger
    
    private let modelURLKey = "com.abacuskit.modelURL"
    private let modelVersionKey = "com.abacuskit.modelVersion"
    
    init(
        userDefaults: UserDefaults = .standard,
        logger: Logger = .make(category: "Storage")
    ) {
        self.userDefaults = userDefaults
        self.logger = logger
        
        // UserDefaultsから永続化された状態を読み込む
        if let urlString = userDefaults.string(forKey: modelURLKey),
           let url = URL(string: urlString) {
            self.currentModelURL = url
            logger.info("Loaded cached model URL", metadata: ["url": url.path])
        }
        
        if userDefaults.object(forKey: modelVersionKey) != nil {
            self.currentVersion = userDefaults.integer(forKey: modelVersionKey)
            if let version = self.currentVersion {
                logger.info("Loaded cached model version", metadata: ["version": "\(version)"])
            }
        }
    }
    
    func getCurrentModelURL() async -> URL? {
        return currentModelURL
    }
    
    func getCurrentVersion() async -> Int? {
        return currentVersion
    }
    
    func update(modelURL: URL, version: Int) async {
        logger.info(
            "Updating model cache",
            metadata: [
                "url": modelURL.path,
                "version": "\(version)"
            ]
        )
        
        self.currentModelURL = modelURL
        self.currentVersion = version
        
        userDefaults.set(modelURL.absoluteString, forKey: modelURLKey)
        userDefaults.set(version, forKey: modelVersionKey)
        
        logger.info("Model cache updated successfully")
    }
    
    func clear() async {
        logger.info("Clearing model cache")
        
        self.currentModelURL = nil
        self.currentVersion = nil
        
        // UserDefaultsから削除
        userDefaults.removeObject(forKey: modelURLKey)
        userDefaults.removeObject(forKey: modelVersionKey)
        
        logger.info("Model cache cleared")
    }
}
