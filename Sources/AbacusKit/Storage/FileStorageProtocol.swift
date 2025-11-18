import Foundation

/// Protocol for file system operations
///
/// This protocol abstracts file storage operations for dependency inversion
/// and enables easy mocking in tests.
protocol FileStorage: Sendable {
    /// Check if file exists at URL
    /// - Parameter url: The file URL to check
    /// - Returns: True if file exists, false otherwise
    func fileExists(at url: URL) -> Bool
    
    /// Delete file at URL
    /// - Parameter url: The file URL to delete
    /// - Throws: Error if deletion fails
    func deleteFile(at url: URL) throws
    
    /// Get file size in bytes
    /// - Parameter url: The file URL to check
    /// - Returns: File size in bytes
    /// - Throws: Error if file doesn't exist or attributes cannot be read
    func fileSize(at url: URL) throws -> Int64
    
    /// Create directory at URL
    /// - Parameters:
    ///   - url: Directory URL to create
    ///   - createIntermediates: Whether to create intermediate directories
    /// - Throws: Error if creation fails
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws
    
    /// List contents of directory
    /// - Parameter url: Directory URL
    /// - Returns: Array of file URLs in the directory
    /// - Throws: Error if directory cannot be read
    func contentsOfDirectory(at url: URL) throws -> [URL]
}

/// Implementation of FileStorage using FileManager
final class FileStorageImpl: FileStorage {
    private nonisolated(unsafe) let fileManager: FileManager
    private let logger: Logger
    
    init(
        fileManager: FileManager = .default,
        logger: Logger = .make(category: "Storage")
    ) {
        self.fileManager = fileManager
        self.logger = logger
    }
    
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    func deleteFile(at url: URL) throws {
        logger.info("Deleting file", metadata: ["path": url.path])
        do {
            try fileManager.removeItem(at: url)
            logger.info("File deleted successfully")
        } catch {
            logger.error("Failed to delete file", error: error)
            throw error
        }
    }
    
    func fileSize(at url: URL) throws -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber else {
                throw AbacusError.storageFailed(reason: "Unable to read file size")
            }
            return size.int64Value
        } catch {
            logger.error("Failed to get file size", error: error)
            throw error
        }
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        logger.info("Creating directory", metadata: ["path": url.path])
        do {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: createIntermediates
            )
            logger.info("Directory created successfully")
        } catch {
            logger.error("Failed to create directory", error: error)
            throw error
        }
    }
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )
            return contents
        } catch {
            logger.error("Failed to list directory contents", error: error)
            throw error
        }
    }
}
