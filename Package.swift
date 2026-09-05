// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmarchyAudio",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OmarchyAudio", targets: ["OmarchyAudio"]),
        .executable(name: "AudioChecks", targets: ["AudioChecks"]),
    ],
    targets: [
        .target(name: "AudioCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "OmarchyAudio", dependencies: ["AudioCore"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "AudioChecks", dependencies: ["AudioCore"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
