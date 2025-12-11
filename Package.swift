// swift-tools-version: 6.0
// AbacusKit - そろばん認識 SDK

import PackageDescription

let opencvURL = "https://github.com/TaiyoYamada/AbacusKit/releases/download/v0.0.1/opencv2.xcframework.zip"
let opencvChecksum = "1bdc6cb6de340a0ad4fd406890c066f63da256cf2c29b9252aec1096b47a5639"

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
        .package(url: "https://github.com/pytorch/executorch.git", branch: "swiftpm-1.0.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.2.0"),
    ],
    targets: [
        // MARK: - Binary Targets (xcframework)
        // OpenCV - 画像処理ライブラリ
        .binaryTarget(
            name: "opencv2",
            url: opencvURL,
            checksum: opencvChecksum
        ),
        
        // MARK: - AbacusKit (Swift)
        .target(
            name: "AbacusKit",
            dependencies: [
                "AbacusVision",
                .product(name: "executorch", package: "executorch"),
                .product(name: "backend_coreml", package: "executorch"),
                .product(name: "kernels_optimized", package: "executorch"),
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
                // Force load all symbols from static libraries to trigger backends and kernels registration
                .unsafeFlags(["-Wl,-all_load"]),
            ]
        ),
        
        // MARK: - AbacusVision (C++)
        .target(
            name: "AbacusVision",
            dependencies: [
                "opencv2",
            ],
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
