import Foundation

/// Actor responsible for downloading model files from S3
@available(iOS 15.0, macOS 12.0, *)
actor ModelDownloader {
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    /// Download model file from S3
    /// - Parameters:
    ///   - url: Source URL of model.pt
    ///   - destination: Local file URL for saving
    /// - Returns: Final saved file URL
    /// - Throws: Error if download fails
    func downloadModel(from url: URL, to destination: URL) async throws -> URL {
        let (tempURL, response) = try await urlSession.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Validate downloaded file size
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: tempURL.path)
        guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
            throw URLError(.zeroByteResource)
        }
        
        // Implement atomic file replacement
        // First, ensure the destination directory exists
        let destinationDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        
        // Move downloaded file to final destination
        try fileManager.moveItem(at: tempURL, to: destination)
        
        return destination
    }
}
