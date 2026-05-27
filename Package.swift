// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-comment-reflow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "swift-comment-reflow", targets: ["SwiftCommentReflow"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.1"),
        .package(url: "https://github.com/davbeck/swift-glob.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftCommentReflowCore",
            dependencies: []
        ),
        .executableTarget(
            name: "SwiftCommentReflow",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser"),
                           .product(name: "Glob", package: "swift-glob"),
                           "SwiftCommentReflowCore"]
        ),
        .testTarget(
            name: "SwiftCommentReflowTests",
            dependencies: ["SwiftCommentReflowCore"]
        ),
    ],

    swiftLanguageModes: [.v6]
)
