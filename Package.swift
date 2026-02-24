// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MMS1eImager",
    platforms: [.macOS(.v10_15)],
    targets: [
        .systemLibrary(
            name: "CZlib",
            path: "Sources/CZlib"
        ),
        .executableTarget(
            name: "MMS1eImager",
            path: "Sources/MMS1eImager"
        ),
        .executableTarget(
            name: "mms-writer",
            dependencies: ["CZlib"],
            path: "Sources/Writer"
        )
    ]
)
