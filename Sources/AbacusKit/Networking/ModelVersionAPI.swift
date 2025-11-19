import Foundation

/// Protocol for fetching model version information from remote server
///
/// This protocol abstracts the network layer for version checking,
/// enabling dependency inversion and testability.
protocol ModelVersionAPI: Sendable {
    /// Fetch the latest model version information
    /// - Parameter url: URL to version.json
    /// - Returns: Decoded ModelVersion
    /// - Throws: Error if network request or decoding fails
    func fetchVersion(from url: URL) async throws -> ModelVersion
}

/// Implementation of ModelVersionAPI using URLSession
final class ModelVersionAPIImpl: ModelVersionAPI {
    private let urlSession: URLSession
    private let logger: Logger

    init(
        urlSession: URLSession = .shared,
        logger: Logger = .make(category: "Networking")
    ) {
        self.urlSession = urlSession
        self.logger = logger
    }

    func fetchVersion(from url: URL) async throws -> ModelVersion {
        logger.info("Fetching model version", metadata: ["url": url.absoluteString])

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                logger.error(
                    "Version fetch failed with status code",
                    metadata: ["statusCode": "\(httpResponse.statusCode)"]
                )
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let modelVersion = try decoder.decode(ModelVersion.self, from: data)

            logger.info(
                "Successfully fetched model version",
                metadata: ["version": "\(modelVersion.version)"]
            )

            return modelVersion
        } catch {
            logger.error("Failed to fetch model version", error: error)
            throw error
        }
    }
}
