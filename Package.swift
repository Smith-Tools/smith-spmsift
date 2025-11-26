// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "smith-spmsift",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "smith-spmsift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Collections", package: "swift-collections")
            ],
            resources: [
                .copy("../../spmsift.1")
            ]
        ),
        .testTarget(
            name: "smith-spmsiftTests",
            dependencies: ["smith-spmsift"],
            path: "Tests"
        ),
    ]
)
