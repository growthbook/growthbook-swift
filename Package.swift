// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GrowthBook-IOS",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "GrowthBook-IOS",
            targets: ["GrowthBook"])
    ],
    dependencies: [
        // no dependencies
    ],
    targets: [
        .target(
            name: "GrowthBook",
            dependencies: [],
            path: "Sources/CommonMain"
        )
    ]
)
