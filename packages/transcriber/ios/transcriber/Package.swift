// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "transcriber",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .library(name: "transcriber", targets: ["transcriber"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "TranscriberCore", path: "Core")
    ],
    targets: [
        .target(
            name: "transcriber",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "TranscriberCore", package: "TranscriberCore")
            ]
        )
    ]
)
