// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ShitsuraeCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ShitsuraeCore", targets: ["ShitsuraeCore"]),
        .executable(name: "shitsurae-cli", targets: ["shitsurae-cli"])
    ],
    targets: [
        .target(name: "ShitsuraeCore"),
        .executableTarget(name: "shitsurae-cli", dependencies: ["ShitsuraeCore"]),
        .testTarget(
            name: "ShitsuraeCoreTests",
            dependencies: ["ShitsuraeCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
