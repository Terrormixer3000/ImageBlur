// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImageBlur",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ImageBlur", targets: ["ImageBlur"])
    ],
    targets: [
        .executableTarget(
            name: "ImageBlur",
            path: "Sources/ImageBlur"
        )
    ]
)
