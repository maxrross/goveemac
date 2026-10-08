// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoveeMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GoveeMac", targets: ["GoveeMac"]),
        .library(name: "GoveeKit", targets: ["GoveeKit"])
    ],
    dependencies: [
        // Pinned for ShadKit's keyboard-accessible switches and sliders.
        .package(url: "https://github.com/jasonkneen/ShadKit", revision: "6dbefdeb72a276708b7ca748c71ac166c0f4f17d")
    ],
    targets: [
        .target(name: "GoveeKit"),
        .executableTarget(name: "GoveeMac", dependencies: [
            "GoveeKit",
            .product(name: "ShadcnUI", package: "ShadKit")
        ]),
        .testTarget(name: "GoveeKitTests", dependencies: ["GoveeKit"])
    ]
)
