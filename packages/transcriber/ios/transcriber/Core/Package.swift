// swift-tools-version: 5.9
import PackageDescription

// No platforms line on purpose: tool/checks.sh runs `swift test` on the host.
let package = Package(
    name: "TranscriberCore",
    products: [.library(name: "TranscriberCore", targets: ["TranscriberCore"])],
    targets: [
        .target(name: "TranscriberCore"),
        .testTarget(name: "TranscriberCoreTests", dependencies: ["TranscriberCore"]),
    ]
)
