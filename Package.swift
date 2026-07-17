// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MorseTrainer",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MorseKit", targets: ["MorseKit"]),
        .library(name: "MorseUI", targets: ["MorseUI"]),
    ],
    targets: [
        .target(name: "MorseKit"),
        .target(name: "MorseUI", dependencies: ["MorseKit"]),
        .testTarget(name: "MorseKitTests", dependencies: ["MorseKit"]),
        .testTarget(name: "MorseUITests", dependencies: ["MorseUI"]),
    ]
)
