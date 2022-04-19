// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import class Foundation.ProcessInfo

func resolveTargets() -> [Target] {
    let baseTargets: [Target] = [
        .target(name: "GrowthBook",
                path: "Sources",
                exclude: ["Info.plist"])
    ]

    return baseTargets
}

// Only add DocC Plugin when building docs, so that clients of this library won't
// unnecessarily also get the DocC Plugin
let environmentVariables = ProcessInfo.processInfo.environment
let shouldIncludeDocCPlugin = environmentVariables["INCLUDE_DOCC_PLUGIN"] == "true"

var dependencies: [Package.Dependency] = []
if shouldIncludeDocCPlugin {
    dependencies.append(.package(url: "Need the url repo", from: "1.0.0"))
}

let package = Package(
    name: "GrowthBook",
    platforms: [
        .macOS(.v10_15),
        .watchOS("5.0"),
        .tvOS(.v12),
        .iOS(.v12)
    ],
    products: [
        .library(name: "GrowthBook-IOS",
                 targets: ["GrowthBook-IOS"])
        .library(name: "GrowthBook-TV",
                 targets: ["GrowthBook-TV"])
        .library(name: "GrowthBook-Watch",
                 targets: ["GrowthBook-Watch"])
    ],
    dependencies: dependencies,
    targets: resolveTargets()
)
