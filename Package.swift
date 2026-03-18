// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImageBlur",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ImageBlur", targets: ["ImageBlur"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")
    ],
    targets: [
        .executableTarget(
            name: "ImageBlur",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ImageBlur",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
