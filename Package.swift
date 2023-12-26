// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HIDPP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HIDPP",
            targets: [
                "HIDPP"
            ]
        ),
        .executable(
            name: "hidppcli",
            targets: [
                "HIDPPCLI"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"
        )
    ],
    targets: [
        .target(
            name: "HIDPP"
        ),
        .executableTarget(
            name: "HIDPPCLI",
            dependencies: [
                .target(
                    name: "HIDPP"
                ),
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                )
            ]
        ),
    ]
)

for target in package.targets {
    var swiftSettings = target.swiftSettings ?? []
    swiftSettings.append(contentsOf: [
        // Use `-strict-concurrency=complete`.
        // See <https://github.com/apple/swift/pull/66991>.
        .enableExperimentalFeature("StrictConcurrency")
    ])
    target.swiftSettings = swiftSettings
}
