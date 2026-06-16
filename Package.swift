// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "iGlance",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "iGlance", targets: ["iGlance"])
    ],
    targets: [
        .executableTarget(
            name: "iGlance",
            dependencies: [],
            path: "Sources/iGlance",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
