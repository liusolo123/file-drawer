// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileDrawer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FileDrawerCore", targets: ["FileDrawerCore"]),
        .executable(name: "FileDrawerApp", targets: ["FileDrawerApp"])
    ],
    targets: [
        .target(name: "FileDrawerCore"),
        .executableTarget(
            name: "FileDrawerApp",
            dependencies: ["FileDrawerCore"]
        ),
        .testTarget(
            name: "FileDrawerCoreTests",
            dependencies: ["FileDrawerCore"]
        )
    ]
)
