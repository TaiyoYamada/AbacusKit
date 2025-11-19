import Foundation
@preconcurrency import Resolver

/// Dependency Injection container for AbacusKit
///
/// This container manages all dependencies using the Resolver framework,
/// following the Dependency Inversion Principle for testability and modularity.
///
/// ## Architecture
///
/// The container registers:
/// - Domain protocols (interfaces)
/// - Infrastructure implementations
/// - Use case coordinators
///
/// All dependencies are resolved through protocols to enable easy mocking in tests.
public final class AbacusContainer: @unchecked Sendable {
    /// Shared container instance
    public static let shared = AbacusContainer()

    private nonisolated(unsafe) let resolver: Resolver

    private init() {
        resolver = Resolver.main
        registerDependencies()
    }

    /// Register all dependencies in the container
    private func registerDependencies() {
        resolver.register { Logger.make(category: "Core") }
            .scope(.shared)

        resolver.register { URLSession.shared }
            .scope(.shared)

        resolver.register { ModelVersionAPIImpl() as ModelVersionAPI }
            .scope(.shared)

        resolver.register { S3DownloaderImpl() as S3Downloader }
            .scope(.shared)

        resolver.register { FileStorageImpl() as FileStorage }
            .scope(.shared)

        resolver.register { ModelCacheImpl() as ModelCache }
            .scope(.shared)

        resolver.register { PreprocessorImpl() as Preprocessor }
            .scope(.shared)

        resolver.register { ModelManagerImpl() as ModelManager }
            .scope(.shared)

        resolver.register { [weak self] in
            guard let self else {
                fatalError("Container deallocated")
            }
            return ModelUpdaterImpl(
                versionAPI: resolver.resolve(),
                downloader: resolver.resolve(),
                cache: resolver.resolve(),
                storage: resolver.resolve()
            ) as ModelUpdater
        }
        .scope(.shared)
    }

    /// Resolve a dependency by type
    /// - Returns: The resolved instance
    public func resolve<T>() -> T {
        resolver.resolve(T.self)
    }

    /// Reset all registrations (useful for testing)
    public func reset() {
        Resolver.reset()
        registerDependencies()
    }
}
