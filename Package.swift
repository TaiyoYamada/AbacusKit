// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AbacusKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AbacusKit",
            targets: ["AbacusKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pytorch/executorch.git",
            branch: "main"
        ),
        .package(url: "https://github.com/hmlongco/Resolver.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.2"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.2.0"),
        .package(url: "https://github.com/Brightify/Cuckoo.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        // MARK: - Swift Target
        .target(
            name: "AbacusKit",
            dependencies: [
                "AbacusKitBridge",
                "Resolver",
                .product(name: "Logging", package: "swift-log"),
                "Zip",
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
        .target(
            name: "AbacusKitBridge",
            dependencies: [
                // コアランタイム（ExecuTorch）
                .product(name: "executorch", package: "executorch"),

                // ハードウェアアクセラレーションバックエンド
                .product(name: "backend_coreml", package: "executorch"),
                .product(name: "backend_mps", package: "executorch"),
                .product(name: "backend_xnnpack", package: "executorch"),

                // 一般的な高速化カーネル
                .product(name: "kernels_optimized", package: "executorch"),
                .product(name: "kernels_quantized", package: "executorch"),
            ],
            path: "Sources/AbacusKitBridge",
            sources: ["ExecuTorchModule.mm"],
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-std=c++17"]),
                .unsafeFlags(["-Wno-shorten-64-to-32"]),
                .unsafeFlags(["-Wno-deprecated-declarations"]),
                .unsafeFlags(["-Wno-unused-parameter"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-Wl,-all_load"]),
                .linkedFramework("Accelerate"),
                .linkedLibrary("c++"),
            ]
        ),
        // MARK: - Tests

        .testTarget(
            name: "AbacusKitTests",
            dependencies: [
                "AbacusKit",
                "Quick",
                "Nimble",
                .product(name: "Cuckoo", package: "Cuckoo"),
            ],
            path: "Tests/AbacusKitTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
