// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexNotch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexNotch", targets: ["CodexNotch"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "CodexNotch",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            resources: [.copy("Resources")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "CodexNotchTests", dependencies: ["CodexNotch"])
    ],
    swiftLanguageVersions: [.v5]
)
