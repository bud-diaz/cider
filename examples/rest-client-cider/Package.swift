// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RESTClientCider",
    products: [
        .executable(name: "RESTClientCider", targets: ["RESTClientCider"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "RESTClientCider",
            dependencies: [.product(name: "CiderUI", package: "Cider")],
            path: "Sources/RESTClientCider"
        ),
    ]
)
