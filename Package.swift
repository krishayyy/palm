// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Palm",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Palm",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/Palm",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
