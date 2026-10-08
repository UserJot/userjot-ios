// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UserJot",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "UserJot",
            targets: ["UserJot"]),
    ],
    targets: [
        .target(
            name: "UserJot"),
        .testTarget(
            name: "UserJotTests",
            dependencies: ["UserJot"]),
    ]
)
