// swift-tools-version:5.0

import PackageDescription

let pkg = Package(name: "Kitchenware")
pkg.products = [
    .library(name: "Cakefile", type: .static, targets: ["Cakefile"]),
]
pkg.dependencies = [
    .package(url: "https://github.com/mxcl/Version", from: "1.0.0"),
]
pkg.targets = [
    .target(name: "Cakefile", dependencies: ["Version"]),
]
