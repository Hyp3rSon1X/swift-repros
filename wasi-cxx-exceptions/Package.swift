// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "repro",
    targets: [
        // Plain C++ with no throw of its own: std::string and std::vector only.
        .target(name: "Words"),
        .executableTarget(name: "repro", dependencies: ["Words"]),
    ]
)
