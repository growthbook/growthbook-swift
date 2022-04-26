// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GrowthBook",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "GrowthBook",
            targets: ["GrowthBook"])
    ],
    dependencies: [
        // no dependencies
    ],
    targets: [
        .binaryTarget(
            name: "GrowthBook",
    url: "https://github.com/growthbook/growthbook-swift/releases/download/1.0.0/GrowthBook.xcframework.zip",
    checksum: "a9a05c2e5b1f197d7000bf4259264a0270a26196dc765bf58c5e0afb75f222cc"
        ),
    ]
)
