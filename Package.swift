// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "pkram",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PapierkramCore",
            targets: ["PapierkramCore"]
        ),
        .executable(
            name: "pkram",
            targets: ["pkram"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "PapierkramCore"
        ),
        .executableTarget(
            name: "pkram",
            dependencies: [
                "PapierkramCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "PapierkramCoreTests",
            dependencies: ["PapierkramCore"]
        )
    ]
)
