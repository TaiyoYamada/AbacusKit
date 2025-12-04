// swift-tools-version: 6.0
// AbacusKit - そろばん認識 SDK

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
        // ドキュメント生成
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        
        // テスト
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.2.0"),
    ],
    targets: [
        // MARK: - AbacusKit (Swift)
        .target(
            name: "AbacusKit",
            dependencies: [
                "AbacusVision",
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
            ]
        ),
        
        // MARK: - AbacusVision (C++)
        .target(
            name: "AbacusVision",
            dependencies: [],
            path: "Sources/AbacusVision",
            sources: [
                "src/AbacusVision.cpp",
                "src/ImagePreprocessor.cpp",
                "src/SorobanDetector.cpp",
                "src/TensorConverter.cpp",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-std=c++17"]),
                .unsafeFlags(["-Wno-shorten-64-to-32"]),
                .unsafeFlags(["-Wno-deprecated-declarations"]),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreVideo"),
                .linkedLibrary("c++"),
                // OpenCV.xcframework はアプリ側で提供
                // ExecuTorch runtime はアプリ側で提供
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "AbacusKitTests",
            dependencies: [
                "AbacusKit",
                "Quick",
                "Nimble",
            ],
            path: "Tests/AbacusKitTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
