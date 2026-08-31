// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexNotch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexNotch", targets: ["CodexNotch"])],
    targets: [
        .executableTarget(
            name: "CodexNotch",
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "CodexNotchTests", dependencies: ["CodexNotch"])
    ],
    swiftLanguageVersions: [.v5]
)
