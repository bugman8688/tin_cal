// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinCal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TinCal",
            path: "Sources/TinCal",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TinCalTests",
            dependencies: ["TinCal"],
            path: "Tests/TinCalTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
