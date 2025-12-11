// swift-tools-version: 6.0
// AbacusKit - そろばん認識 SDK

import PackageDescription

// GitHub Releases からダウンロードする xcframework の設定
// 初回リリース時に checksum を計算して設定する必要があります
// let execuTorchURL = "https://github.com/TaiyoYamada/AbacusKit/releases/download/v1.0.0/ExecuTorch.xcframework.zip"
// let execuTorchChecksum = "PLACEHOLDER_CHECKSUM_EXECUTORCH"

let opencvURL = "https://github.com/TaiyoYamada/AbacusKit/releases/download/v1.0.0/opencv2.xcframework.zip"
let opencvChecksum = "PLACEHOLDER_CHECKSUM_OPENCV"

let package = Package(
    name: "AbacusKit",
    platforms: [
        .iOS(.v17),
        // .macOS(.v14),
    ],
    products: [
        .library(
            name: "AbacusKit",
            targets: ["AbacusKit"] 
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/TaiyoYamada/ExecuTorch.git", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.2.0"),
    ],
    targets: [
        // MARK: - Binary Targets (xcframework)
        
        // ExecuTorch - PyTorch モデル推論ランタイム
        // .binaryTarget(
        //     name: "ExecuTorch",
        //     url: execuTorchURL,
        //     checksum: execuTorchChecksum
        // ),
        
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
                "ExecuTorch",
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
