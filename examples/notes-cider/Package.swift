// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotesCider",
    products: [
        .executable(name: "NotesCider", targets: ["NotesCider"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "NotesCider",
            dependencies: [.product(name: "CiderUI", package: "Cider")],
            path: "Sources/NotesCider"
        ),
    ]
)
