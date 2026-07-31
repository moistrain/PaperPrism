// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PaperPrism",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PaperPrism", targets: ["PaperPrism"])
    ],
    targets: [
        .executableTarget(
            name: "PaperPrism",
            path: "Sources/PaperPrism"
        )
    ]
)
