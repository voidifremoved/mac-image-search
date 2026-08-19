// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalImageSearch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LocalImageSearch",
            targets: ["LocalImageSearchApp"]
        ),
        .library(
            name: "LocalImageSearchCore",
            targets: ["LocalImageSearchCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "LocalImageSearchCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "LocalImageSearchCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "LocalImageSearchApp",
            dependencies: ["LocalImageSearchCore"],
            path: "LocalImageSearchApp",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "LocalImageSearchTests",
            dependencies: ["LocalImageSearchCore"],
            path: "LocalImageSearchTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
