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
        self.resolver = Resolver.main
        registerDependencies()
    }
    
    /// Register all dependencies in the container
    /// 依存関係を登録（プロトコルベースで疎結合を実現）
    private func registerDependencies() {
        // MARK: - Core
        resolver.register { Logger.make(category: "Core") }
            .scope(.shared)
        
        // MARK: - Networking
        resolver.register { URLSession.shared }
            .scope(.shared)
        
        resolver.register { ModelVersionAPIImpl() as ModelVersionAPI }
            .scope(.shared)
        
        resolver.register { S3DownloaderImpl() as S3Downloader }
            .scope(.shared)
        
        // MARK: - Storage
        resolver.register { FileStorageImpl() as FileStorage }
            .scope(.shared)
        
        resolver.register { ModelCacheImpl() as ModelCache }
            .scope(.shared)
        
        // MARK: - ML
        resolver.register { PreprocessorImpl() as Preprocessor }
            .scope(.shared)
        
        resolver.register { ModelManagerImpl() as ModelManager }
            .scope(.shared)
        
        resolver.register { [weak self] in
            guard let self = self else { fatalError("Container deallocated") }
            return ModelUpdaterImpl(
                versionAPI: self.resolver.resolve(),
                downloader: self.resolver.resolve(),
                cache: self.resolver.resolve(),
                storage: self.resolver.resolve()
            ) as ModelUpdater
        }
        .scope(.shared)
    }
    
    /// Resolve a dependency by type
    /// - Returns: The resolved instance
    public func resolve<T>() -> T {
        return resolver.resolve(T.self)
    }
    
    /// Reset all registrations (useful for testing)
    /// テスト用にコンテナをリセット
    public func reset() {
        Resolver.reset()
        registerDependencies()
    }
}
