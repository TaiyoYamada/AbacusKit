// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AbacusKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AbacusKit",
            targets: ["AbacusKit"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AbacusKit",
            cxxSettings: [
                // C++17 standard required for LibTorch
                .unsafeFlags(["-std=c++17"]),
            ],
            swiftSettings: [
                // Enable strict concurrency checking for Swift 6
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                // IMPORTANT: LibTorch Binary Linking Instructions
                // 
                // LibTorch is not included in this package and must be linked manually.
                // 
                // Option 1: Manual Binary Integration
                // 1. Download LibTorch iOS binary from: https://pytorch.org/mobile/ios/
                // 2. Extract and add libtorch_lite_interpreter.a to your Xcode project
                // 3. Add the following to your app target's "Other Linker Flags":
                //    -force_load $(PROJECT_DIR)/path/to/libtorch_lite_interpreter.a
                // 4. Add LibTorch include path to "Header Search Paths":
                //    $(PROJECT_DIR)/path/to/libtorch/include
                //
                // Option 2: CocoaPods Integration
                // 1. Add to your Podfile:
                //    pod 'LibTorch-Lite', '~> 2.0.0'
                // 2. Run: pod install
                //
                // Required Frameworks:
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreML"),
                .linkedFramework("MetalPerformanceShaders"),
            ]
        ),
        .testTarget(
            name: "AbacusKitTests",
            dependencies: ["AbacusKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
