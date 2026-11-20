// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WaterCompanionCore",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "WaterCompanionCore", targets: ["WaterCompanionCore"])
    ],
    targets: [
        .target(name: "WaterCompanionCore", path: "Shared"),
        .testTarget(
            name: "WaterCompanionCoreTests",
            dependencies: ["WaterCompanionCore"],
            path: "Tests/WaterCompanionCoreTests"
        )
    ]
)
