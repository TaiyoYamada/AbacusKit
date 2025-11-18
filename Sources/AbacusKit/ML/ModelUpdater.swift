import Foundation
import Zip

/// Protocol for managing model updates from remote server
///
/// This protocol coordinates the model update pipeline:
/// 1. Check version from version.json
/// 2. Download model zip from S3
/// 3. Extract zip file
/// 4. Store and cache model
protocol ModelUpdater: Sendable {
    /// Check and update model if necessary
    /// - Parameters:
    ///   - config: Configuration containing version URL and storage directory
    ///   - forceUpdate: Whether to force update even if cached version matches
    /// - Returns: URL of the model file (either cached or newly downloaded)
    /// - Throws: Error if update fails
    func updateModelIfNeeded(config: AbacusConfig, forceUpdate: Bool) async throws -> URL
}

/// Implementation of ModelUpdater coordinating version check, download, and extraction
final class ModelUpdaterImpl: ModelUpdater {
    private let versionAPI: ModelVersionAPI
    private let downloader: S3Downloader
    private let cache: ModelCache
    private let storage: FileStorage
    private let logger: Logger
    
    init(
        versionAPI: ModelVersionAPI,
        downloader: S3Downloader,
        cache: ModelCache,
        storage: FileStorage,
        logger: Logger = .make(category: "ML")
    ) {
        self.versionAPI = versionAPI
        self.downloader = downloader
        self.cache = cache
        self.storage = storage
        self.logger = logger
    }
    
    func updateModelIfNeeded(config: AbacusConfig, forceUpdate: Bool) async throws -> URL {
        logger.info("Checking for model updates")
        
        let remoteVersion: ModelVersion
        do {
            remoteVersion = try await versionAPI.fetchVersion(from: config.versionURL)
        } catch {
            logger.error("Failed to fetch remote version", error: error)
            throw AbacusError.versionCheckFailed(underlying: error)
        }
        
        let cachedVersion = await cache.getCurrentVersion()
        let cachedModelURL = await cache.getCurrentModelURL()
        
        let needsUpdate = forceUpdate ||
                         cachedVersion == nil ||
                         cachedModelURL == nil ||
                         remoteVersion.version > (cachedVersion ?? 0) ||
                         !storage.fileExists(at: cachedModelURL!)
        
        if !needsUpdate, let cachedURL = cachedModelURL {
            logger.info(
                "Using cached model",
                metadata: [
                    "version": "\(cachedVersion ?? 0)",
                    "path": cachedURL.path
                ]
            )
            return cachedURL
        }
        
        logger.info(
            "Downloading new model",
            metadata: ["version": "\(remoteVersion.version)"]
        )
        
        let zipFileName = "model_v\(remoteVersion.version).zip"
        let zipURL = config.modelDirectoryURL.appendingPathComponent(zipFileName)
        
        do {
            let downloadedZipURL = try await downloader.download(
                from: remoteVersion.modelURL,
                to: zipURL
            )
            
            logger.info("Extracting model archive")
            let extractedURL = try await extractModel(
                zipURL: downloadedZipURL,
                destinationDirectory: config.modelDirectoryURL
            )
            
            try? storage.deleteFile(at: downloadedZipURL)
            
            await cache.update(modelURL: extractedURL, version: remoteVersion.version)
            
            if let oldModelURL = cachedModelURL,
               oldModelURL != extractedURL,
               storage.fileExists(at: oldModelURL) {
                logger.info("Cleaning up old model", metadata: ["path": oldModelURL.path])
                try? storage.deleteFile(at: oldModelURL)
            }
            
            logger.info(
                "Model update completed successfully",
                metadata: [
                    "version": "\(remoteVersion.version)",
                    "path": extractedURL.path
                ]
            )
            
            return extractedURL
        } catch let error as AbacusError {
            throw error
        } catch {
            logger.error("Model update failed", error: error)
            throw AbacusError.downloadFailed(underlying: error)
        }
    }
    
    // MARK: - Private Helpers
    
    /// ZIPファイルを解凍してモデルファイルのURLを返す
    private func extractModel(zipURL: URL, destinationDirectory: URL) async throws -> URL {
        do {
            let extractDirectory = destinationDirectory.appendingPathComponent("extracted_\(UUID().uuidString)")
            try storage.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
            
            try Zip.unzipFile(
                zipURL,
                destination: extractDirectory,
                overwrite: true,
                password: nil
            )
            
            let contents = try storage.contentsOfDirectory(at: extractDirectory)
            
            if let modelURL = contents.first(where: { $0.pathExtension == "mlmodelc" }) {
                logger.info("Found compiled model", metadata: ["path": modelURL.path])
                return modelURL
            }
            
            if let modelURL = contents.first(where: { $0.pathExtension == "mlmodel" }) {
                logger.info("Found uncompiled model", metadata: ["path": modelURL.path])
                return modelURL
            }
            
            logger.error("No model file found in archive")
            throw AbacusError.extractionFailed(
                underlying: NSError(
                    domain: "ModelUpdater",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No .mlmodel or .mlmodelc file found in archive"]
                )
            )
        } catch let error as AbacusError {
            throw error
        } catch {
            logger.error("Failed to extract model archive", error: error)
            throw AbacusError.extractionFailed(underlying: error)
        }
    }
}
