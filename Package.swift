// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fx-cli",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "fx-photo", targets: ["fx-photo"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/JohnSundell/Files.git", from: "4.3.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.2.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4")
    ],
    targets: [
        .executableTarget(
            name: "fx-photo",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Files", package: "Files"),
                .product(name: "Rainbow", package: "Rainbow"),
                .product(name: "ShellOut", package: "ShellOut"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
