/// AbacusKit - iOS/iPad Real-time Inference SDK
///
/// AbacusKit provides real-time inference capabilities using TorchScript models
/// with automatic model updates from Amazon S3.
///
/// ## Usage
///
/// ```swift
/// import AbacusKit
///
/// let config = AbacusConfig(
///     versionURL: URL(string: "https://s3.amazonaws.com/bucket/version.json")!,
///     modelDirectoryURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
/// )
///
/// try await Abacus.shared.configure(config: config)
/// let result = try await Abacus.shared.predict(pixelBuffer: pixelBuffer)
/// ```

@_exported import Foundation
@_exported import CoreVideo
