// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoveeMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GoveeMac", targets: ["GoveeMac"]),
        .library(name: "GoveeKit", targets: ["GoveeKit"])
    ],
    targets: [
        .target(name: "GoveeKit"),
        .executableTarget(name: "GoveeMac", dependencies: ["GoveeKit"]),
        .testTarget(name: "GoveeKitTests", dependencies: ["GoveeKit"])
    ]
)
