// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Magic",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure model/persistence code, kept free of UI so it can be unit tested.
        .target(name: "MagicCore"),
        .executableTarget(name: "Magic", dependencies: ["MagicCore"]),
        .testTarget(name: "MagicCoreTests", dependencies: ["MagicCore"]),
    ],
    swiftLanguageModes: [.v5]
)
