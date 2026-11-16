// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WaterReminder",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WaterReminder", targets: ["WaterReminder"])],
    targets: [
        .target(name: "WaterCore"),
        .executableTarget(name: "WaterReminder", dependencies: ["WaterCore"]),
        .executableTarget(name: "WaterCoreChecks", dependencies: ["WaterCore"], path: "Tests/WaterCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
