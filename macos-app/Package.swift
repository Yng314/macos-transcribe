// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "macos-app",
    platforms: [
        .macOS(.v13),
    ],
    targets: [
        .executableTarget(
            name: "macos-app",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "macos-appTests",
            dependencies: ["macos-app"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
