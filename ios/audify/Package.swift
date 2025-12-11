// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "audify",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "audify", targets: ["audify"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "audify",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
