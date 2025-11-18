// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AbacusKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AbacusKit",
            targets: ["AbacusKit"]
        ),
    ],
    dependencies: [
        // 依存性注入: Resolver
        .package(url: "https://github.com/hmlongco/Resolver.git", from: "1.5.0"),

        // ロギング: SwiftLog
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),

        // モデル解凍: Zip
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),

        // テスト: Quick & Nimble
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.2.0"),
        
        // モック生成: Cuckoo
        .package(url: "https://github.com/Brightify/Cuckoo.git", from: "2.0.0"),
    ],
    targets: [
        // MARK: - Swift Target
        .target(
            name: "AbacusKit",
            dependencies: [
                "AbacusKitBridge",
                "Resolver",
                .product(name: "Logging", package: "swift-log"),
                "Zip"
            ],
            path: "Sources/AbacusKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreML"),
                .linkedFramework("MetalPerformanceShaders"),
            ]
        ),

        // MARK: - Bridge (Objective-C++/C++)
        // Note: Bridge is kept for OpenCV preprocessing support
        // LibTorch functionality has been replaced with CoreML
        .target(
            name: "AbacusKitBridge",
            dependencies: [],
            path: "Sources/AbacusKitBridge",
            sources: ["TorchModule.mm"],  // Only compile .mm file
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-std=c++17"]),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "AbacusKitTests",
            dependencies: [
                "AbacusKit",
                "Quick",
                "Nimble",
                .product(name: "Cuckoo", package: "Cuckoo")
            ],
            path: "Tests/AbacusKitTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
