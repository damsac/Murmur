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
        .executable(name: "TranscriptionTest", targets: ["TranscriptionTest"]),
        .executable(name: "ScenarioRunner", targets: ["ScenarioRunner"]),
    ],
    targets: [
        .target(name: "MurmurCore"),
        .executableTarget(
            name: "TranscriptionTest",
            dependencies: ["MurmurCore"]
        ),
        .executableTarget(
            name: "ScenarioRunner",
            dependencies: ["MurmurCore"]
        ),
        .testTarget(
            name: "MurmurCoreTests",
            dependencies: ["MurmurCore"]
        ),
    ]
)
