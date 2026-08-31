// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ShitsuraeCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ShitsuraeCore", targets: ["ShitsuraeCore"]),
        .library(name: "ShitsuraeKit", targets: ["ShitsuraeKit"]),
        .executable(name: "shitsurae-cli", targets: ["shitsurae-cli"])
    ],
    // The project's only third-party dependency: global hotkeys.
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(name: "ShitsuraeCore"),
        .target(
            name: "ShitsuraeKit",
            dependencies: [
                "ShitsuraeCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .executableTarget(name: "shitsurae-cli", dependencies: ["ShitsuraeCore"]),
        .testTarget(
            name: "ShitsuraeCoreTests",
            dependencies: ["ShitsuraeCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "ShitsuraeKitTests", dependencies: ["ShitsuraeKit"])
    ]
)
