// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    dependencies: [
        .package(name: "Models", path: "../Models"),
    ],
    targets: [
        .target(name: "Persistence", dependencies: ["Models"]),
    ]
)
