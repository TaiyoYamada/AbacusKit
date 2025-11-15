// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AbacusKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AbacusKit",
            targets: ["AbacusKit"]
        ),
    ],
    targets: [
        // MARK: - Swift Target
        .target(
            name: "AbacusKit",
            dependencies: ["AbacusKitBridge"],
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
            dependencies: [],
            path: "Sources/AbacusKitBridge",
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
            dependencies: ["AbacusKit"],
            path: "Tests/AbacusKitTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
