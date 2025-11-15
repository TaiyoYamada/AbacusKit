import Foundation

/// Actor responsible for fetching remote model version information from S3
@available(iOS 15.0, macOS 12.0, *)
actor VersionChecker {
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    /// Fetch remote model version from S3
    /// - Parameter url: URL to version.json
    /// - Returns: Decoded ModelVersion
    /// - Throws: Error if network request or decoding fails
    func fetchRemoteVersion(from url: URL) async throws -> ModelVersion {
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let modelVersion = try decoder.decode(ModelVersion.self, from: data)
            return modelVersion
        } catch {
            throw error
        }
    }
}
