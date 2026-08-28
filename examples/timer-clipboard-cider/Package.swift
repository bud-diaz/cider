// swift-tools-version: 6.0
//
// A Cider application is an ordinary SwiftPM executable that links CiderUI.
// `cider build` runs `swift build` here; Cider adds the manifest, the device
// profile and the runtime around it rather than replacing the build system.

import PackageDescription

let package = Package(
    name: "TimerClipboardCider",
    products: [
        // Cider launches the single executable product a project declares.
        .executable(name: "TimerClipboardCider", targets: ["TimerClipboardCider"]),
    ],
    dependencies: [
        // A path dependency while Cider is pre-alpha and unreleased. A real
        // project will point at a tagged version once one exists.
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "TimerClipboardCider",
            dependencies: [.product(name: "CiderUI", package: "Cider")],
            path: "Sources/TimerClipboardCider"
        ),
    ]
)
