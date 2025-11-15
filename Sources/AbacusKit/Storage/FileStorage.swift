import Foundation

struct FileStorage {
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    /// Check if file exists at URL
    /// - Parameter url: The file URL to check
    /// - Returns: True if file exists, false otherwise
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Delete file at URL
    /// - Parameter url: The file URL to delete
    /// - Throws: Error if deletion fails
    func deleteFile(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }
    
    /// Get file size in bytes
    /// - Parameter url: The file URL to check
    /// - Returns: File size in bytes
    /// - Throws: Error if file doesn't exist or attributes cannot be read
    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw NSError(
                domain: "FileStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to read file size"]
            )
        }
        return size.int64Value
    }
}
