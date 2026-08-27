// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LongChat",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "LongChat",
            path: "Sources/GlassChat",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
