// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Teamodoro",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SynchronizedTimerCore", targets: ["SynchronizedTimerCore"]),
    ],
    targets: [
        .target(
            name: "SynchronizedTimerCore",
            path: "Sources/SynchronizedTimerCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SynchronizedTimerCoreTests",
            dependencies: ["SynchronizedTimerCore"],
            path: "Tests/SynchronizedTimerCoreTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
