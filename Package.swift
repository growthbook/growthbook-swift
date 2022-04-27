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
        .binaryTarget(
            name: "GrowthBook",
    url: "https://github.com/growthbook/growthbook-swift/releases/download/1.0.0/GrowthBook.xcframework.zip",
    checksum: "756609fcbf0f44a697cbe73304fbd3317495ea2080c89c7b240bd99a80ac57a6"
        ),
    ]
)
