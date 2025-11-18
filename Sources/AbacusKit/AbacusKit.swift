/// AbacusKit - iOS Real-time Inference SDK
///
/// AbacusKit provides real-time inference capabilities using CoreML models
/// with automatic model updates from Amazon S3.
///
/// ## Features
///
/// - CoreML-based inference with OpenCV preprocessing
/// - Automatic model version checking and updates
/// - S3 presigned URL support for model downloads
/// - Zip archive extraction for model packages
/// - Local model caching with version management
/// - Structured logging with SwiftLog
/// - Dependency injection with Resolver
/// - Full Swift 6 concurrency support
///
/// ## Architecture
///
/// AbacusKit follows Clean Architecture principles with clear separation of concerns:
///
/// - **Domain Layer**: Core business logic and entities
/// - **Use Case Layer**: Application-specific business rules
/// - **Interface Layer**: Protocols for dependency inversion
/// - **Infrastructure Layer**: External frameworks and implementations
///
/// ## Usage
///
/// ```swift
/// import AbacusKit
///
/// // Configure the SDK
/// let config = AbacusConfig(
///     versionURL: URL(string: "https://s3.amazonaws.com/bucket/version.json")!,
///     modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
/// )
///
/// // Initialize and configure
/// let abacus = Abacus()
/// try await abacus.configure(config: config)
///
/// // Perform inference
/// let result = try await abacus.predict(pixelBuffer: pixelBuffer)
/// print("Predicted value: \(result.value), confidence: \(result.confidence)")
/// ```
///
/// ## Thread Safety
///
/// All public APIs are thread-safe and use Swift's structured concurrency.
/// The SDK is designed to be used from any async context.

@_exported import Foundation
@_exported import CoreVideo
