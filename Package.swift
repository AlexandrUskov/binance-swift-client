// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BinanceClient",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "BinanceClient", targets: ["BinanceClient"]),
    ],
    targets: [
        .target(name: "BinanceClient"),
        .testTarget(name: "BinanceClientTests", dependencies: ["BinanceClient"]),
    ]
)
