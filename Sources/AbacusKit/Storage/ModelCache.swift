import Foundation

actor ModelCache {
    private(set) var currentModelURL: URL?
    private(set) var currentVersion: Int?
    
    private let userDefaults: UserDefaults
    private let modelURLKey = "com.abacuskit.modelURL"
    private let modelVersionKey = "com.abacuskit.modelVersion"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load persisted state from UserDefaults
        if let urlString = userDefaults.string(forKey: modelURLKey),
           let url = URL(string: urlString) {
            self.currentModelURL = url
        }
        
        if userDefaults.object(forKey: modelVersionKey) != nil {
            self.currentVersion = userDefaults.integer(forKey: modelVersionKey)
        }
    }
    
    /// Update cached model information
    /// - Parameters:
    ///   - modelURL: Local URL of model file
    ///   - version: Model version number
    func update(modelURL: URL, version: Int) async {
        self.currentModelURL = modelURL
        self.currentVersion = version
        
        // Persist to UserDefaults
        userDefaults.set(modelURL.absoluteString, forKey: modelURLKey)
        userDefaults.set(version, forKey: modelVersionKey)
    }
    
    /// Clear cached model information
    func clear() async {
        self.currentModelURL = nil
        self.currentVersion = nil
        
        // Remove from UserDefaults
        userDefaults.removeObject(forKey: modelURLKey)
        userDefaults.removeObject(forKey: modelVersionKey)
    }
}
