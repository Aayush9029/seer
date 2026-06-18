// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "seer",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "seer", targets: ["seer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "seer",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "seerTests",
            dependencies: ["seer"]
        ),
    ]
)
