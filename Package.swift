// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DockAnchor",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DockAnchorApp", targets: ["DockAnchorApp"]),
        .executable(name: "dockanchor", targets: ["DockAnchorCLI"]),
    ],
    targets: [
        .target(name: "DockAnchorCore"),
        .executableTarget(name: "DockAnchorApp", dependencies: ["DockAnchorCore"]),
        .executableTarget(name: "DockAnchorCLI", dependencies: ["DockAnchorCore"]),
        .testTarget(name: "DockAnchorCoreTests", dependencies: ["DockAnchorCore"]),
    ]
)
