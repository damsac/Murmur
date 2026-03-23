// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MurmurCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MurmurCore", targets: ["MurmurCore"]),
    ],
    targets: [
        .target(name: "MurmurCore"),
        .testTarget(
            name: "MurmurCoreTests",
            dependencies: ["MurmurCore"]
        ),
    ]
)
