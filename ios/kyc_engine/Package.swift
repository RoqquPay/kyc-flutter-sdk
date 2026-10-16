// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "kyc_engine",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "kyc-engine", targets: ["kyc_engine"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "kyc_engine",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("VideoToolbox"),
            ]
        )
    ]
)
