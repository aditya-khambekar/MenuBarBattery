// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MenuBarBattery",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "AirPodsBattery", targets: ["AirPodsBattery"]),
    ],
    targets: [
        .target(
            name: "AirPodsBattery",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreAudio"),
            ]
        ),
        .testTarget(
            name: "AirPodsBatteryTests",
            dependencies: ["AirPodsBattery"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
