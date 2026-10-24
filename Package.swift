// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MenuBarBattery",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "AirPodsBattery", targets: ["AirPodsBattery"]),
        .executable(name: "MenuBarBattery", targets: ["MenuBarBattery"]),
    ],
    targets: [
        .target(
            name: "AirPodsBattery",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreAudio"),
            ]
        ),
        .executableTarget(
            name: "MenuBarBattery",
            dependencies: ["AirPodsBattery"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("ServiceManagement"),
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
        .testTarget(
            name: "MenuBarBatteryTests",
            dependencies: ["MenuBarBattery"]
        ),
    ]
)
