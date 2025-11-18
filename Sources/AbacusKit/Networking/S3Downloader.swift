import Foundation

/// Protocol for downloading files from S3
///
/// This protocol abstracts S3 download operations for dependency inversion.
protocol S3Downloader: Sendable {
    /// Download a file from S3 to local storage
    /// - Parameters:
    ///   - url: Source URL (presigned S3 URL)
    ///   - destination: Local file URL for saving
    /// - Returns: Final saved file URL
    /// - Throws: Error if download fails
    func download(from url: URL, to destination: URL) async throws -> URL
}

/// Implementation of S3Downloader using URLSession
final class S3DownloaderImpl: S3Downloader {
    private let urlSession: URLSession
    private let logger: Logger
    
    init(
        urlSession: URLSession = .shared,
        logger: Logger = .make(category: "Networking")
    ) {
        self.urlSession = urlSession
        self.logger = logger
    }
    
    func download(from url: URL, to destination: URL) async throws -> URL {
        logger.info(
            "Starting model download",
            metadata: [
                "url": url.absoluteString,
                "destination": destination.path
            ]
        )
        
        do {
            let (tempURL, response) = try await urlSession.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error(
                    "Download failed with status code",
                    metadata: ["statusCode": "\(httpResponse.statusCode)"]
                )
                throw URLError(.badServerResponse)
            }
            
            // ダウンロードしたファイルのサイズを検証
            let fileManager = FileManager.default
            let attributes = try fileManager.attributesOfItem(atPath: tempURL.path)
            guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
                logger.error("Downloaded file has zero size")
                throw URLError(.zeroByteResource)
            }
            
            logger.info("Download completed", metadata: ["size": "\(fileSize) bytes"])
            
            // 保存先ディレクトリを作成
            let destinationDirectory = destination.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true
            )
            
            // 既存ファイルがあれば削除
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            
            // ダウンロードしたファイルを最終的な保存先に移動
            try fileManager.moveItem(at: tempURL, to: destination)
            
            logger.info("File saved successfully", metadata: ["path": destination.path])
            
            return destination
        } catch {
            logger.error("Download failed", error: error)
            throw error
        }
    }
}
