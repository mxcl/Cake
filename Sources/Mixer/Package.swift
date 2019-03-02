// swift-tools-version:5.0

import PackageDescription

let pkg = Package(name: "Mixer")
pkg.products = [
    .executable(name: "mixer", targets: ["Mixer"]),
]
pkg.dependencies = [
    .package(url: "https://github.com/apple/swift-package-manager.git", .branch("swift-DEVELOPMENT-SNAPSHOT-2019-02-03-a")),
    .package(url: "https://github.com/Weebly/OrderedSet", from: "3.1.0"),
    .package(url: "https://github.com/mxcl/Path.swift", from: "0.16.0"),
]
pkg.targets = [
    .target(name: "Mixer", dependencies: ["OrderedSet", "Modelize"], path: ".", sources: ["main.swift"]),
    .target(name: "Modelize", dependencies: ["SwiftPM", "Base", "Path"], path: "Modelize"),
    .target(name: "Base", dependencies: ["Path"], path: "Base"),
]
pkg.platforms = [
    .macOS(.v10_14)
]
pkg.swiftLanguageVersions = [
    .v5
]
