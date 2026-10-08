// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TodoApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TodoApp", targets: ["TodoApp"])
    ],
    targets: [
        .executableTarget(
            name: "TodoApp"
        ),
        .testTarget(
            name: "TodoAppTests",
            dependencies: ["TodoApp"]
        ),
    ]
)
