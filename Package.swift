// swift-tools-version: 6.0
//
// Cider — an open compatibility runtime for developing iOS-style Swift
// applications on Linux (and, later, Windows).
//
// The target graph below is the enforced form of the architecture described in
// docs/03-technical-architecture.md. The intended dependency direction is:
//
//     Application  ->  Compatibility  ->  Runtime Core
//                                      ->  Abstract Host Interfaces
//                                      ->  Platform Backend
//
// Nothing at or above CiderRuntime may depend on a platform backend. The single
// module allowed to name a concrete backend is CiderHostBootstrap, which selects
// one per platform. Keeping that knowledge in one file is what makes the Windows
// backend a addition rather than a rewrite.

import PackageDescription

let package = Package(
    name: "Cider",
    products: [
        // The developer-facing toolchain front end.
        .executable(name: "cider", targets: ["cider"]),

        // The library an application imports. It re-exports nothing else, so an
        // application never links the runtime or a backend directly.
        .library(name: "CiderUI", targets: ["CiderUI"]),

        // Exposed so out-of-tree tests and tools can drive the runtime headlessly.
        .library(name: "CiderHostTesting", targets: ["CiderHostTesting"]),
    ],
    targets: [

        // MARK: - Foundation

        // Geometry, colour, the software framebuffer, structured diagnostics and
        // logging. Depends on nothing; everything else depends on it.
        .target(
            name: "CiderCore",
            path: "runtime/Sources/CiderCore"
        ),

        // Deterministic virtual-device descriptions. Generic names only; see
        // docs/07-legal-distribution-boundaries.md.
        .target(
            name: "CiderDeviceProfiles",
            dependencies: ["CiderCore"],
            path: "device-profiles/Sources/CiderDeviceProfiles"
        ),

        // MARK: - UI

        // Normalized UI tree, layout engine, render tree and the portable
        // software rasterizer. Contains no platform code: it turns a tree into
        // pixels in a CiderCore.Canvas.
        .target(
            name: "CiderUITree",
            dependencies: ["CiderCore"],
            path: "ui/Sources/CiderUITree"
        ),

        // MARK: - Host abstraction

        // The interfaces a platform must implement. Protocols only.
        .target(
            name: "CiderHost",
            dependencies: ["CiderCore"],
            path: "host/Sources/CiderHost"
        ),

        // MARK: - Linux backend

        // System libraries. pkgConfig supplies include and link flags, so no
        // unsafe flags leak into the package graph.
        .systemLibrary(
            name: "CX11",
            path: "host/linux/Sources/CX11",
            pkgConfig: "x11",
            providers: [.apt(["libx11-dev"])]
        ),
        .systemLibrary(
            name: "CFreeType",
            path: "host/linux/Sources/CFreeType",
            pkgConfig: "freetype2",
            providers: [.apt(["libfreetype-dev"])]
        ),
        .systemLibrary(
            name: "CFontconfig",
            path: "host/linux/Sources/CFontconfig",
            pkgConfig: "fontconfig",
            providers: [.apt(["libfontconfig-dev"])]
        ),

        // Thin C shims. Xlib and FreeType are macro-heavy C APIs; rather than
        // fight their headers from Swift, each shim exposes a small, flat C
        // surface that maps one-to-one onto the abstract host interfaces.
        .target(
            name: "CX11Shim",
            dependencies: ["CX11"],
            path: "host/linux/Sources/CX11Shim"
        ),
        .target(
            name: "CTextShim",
            dependencies: ["CFreeType", "CFontconfig"],
            path: "host/linux/Sources/CTextShim"
        ),

        .target(
            name: "CiderHostLinux",
            dependencies: ["CiderCore", "CiderHost", "CX11Shim", "CTextShim"],
            path: "host/linux/Sources/CiderHostLinux"
        ),

        // MARK: - Testing backend

        // A second backend, present from day one. Its purpose is to keep the
        // abstraction honest: if shared code ever needs to know it is running on
        // Linux, this target stops compiling.
        .target(
            name: "CiderHostTesting",
            dependencies: ["CiderCore", "CiderHost"],
            path: "host/testing/Sources/CiderHostTesting"
        ),

        // The only module that names concrete backends.
        .target(
            name: "CiderHostBootstrap",
            dependencies: [
                "CiderCore",
                "CiderHost",
                .target(name: "CiderHostLinux", condition: .when(platforms: [.linux])),
            ],
            path: "host/Sources/CiderHostBootstrap"
        ),

        // MARK: - Runtime

        // Developer-facing inspection of runtime state. Read-only; the runtime
        // works identically with it disabled.
        .target(
            name: "CiderInspector",
            dependencies: ["CiderCore", "CiderUITree"],
            path: "inspector/Sources/CiderInspector"
        ),

        // Lifecycle, event loop, invalidation, render scheduling, logging.
        .target(
            name: "CiderRuntime",
            dependencies: [
                "CiderCore",
                "CiderUITree",
                "CiderHost",
                "CiderDeviceProfiles",
                "CiderInspector",
            ],
            path: "runtime/Sources/CiderRuntime"
        ),

        // MARK: - Compatibility layer

        // The API an application writes against.
        .target(
            name: "CiderUI",
            dependencies: [
                "CiderCore",
                "CiderUITree",
                "CiderRuntime",
                "CiderHostBootstrap",
            ],
            path: "compatibility/Sources/CiderUI"
        ),

        // MARK: - Toolchain front end

        // Project discovery, manifest parsing and validation, build
        // orchestration, launch descriptors. Deliberately independent of the
        // runtime so the CLI can diagnose a host on which the runtime cannot
        // even be built.
        //
        // CiderInspector is a dependency so the console can decode the
        // snapshot it serves rather than trusting the browser's reading of it.
        // This does not breach "the CLI links neither the runtime nor a
        // backend": CiderInspector depends only on CiderCore and CiderUITree.
        .target(
            name: "CiderProject",
            dependencies: ["CiderCore", "CiderDeviceProfiles", "CiderInspector"],
            path: "compiler-support/Sources/CiderProject"
        ),

        .executableTarget(
            name: "cider",
            dependencies: ["CiderCore", "CiderProject", "CiderDeviceProfiles"],
            path: "cli/Sources/cider"
        ),

        // MARK: - Tests

        .testTarget(
            name: "CiderUnitTests",
            dependencies: [
                "CiderCore",
                "CiderUITree",
                "CiderProject",
                "CiderDeviceProfiles",
                "CiderHostTesting",
                "CiderInspector",
                "CiderRuntime",
            ],
            path: "tests/unit",
            exclude: ["Snapshots"]
        ),
        .testTarget(
            name: "CiderConformanceTests",
            dependencies: [
                "CiderCore",
                "CiderUI",
                "CiderUITree",
                "CiderRuntime",
                "CiderHostTesting",
            ],
            path: "tests/conformance"
        ),
        .testTarget(
            name: "CiderIntegrationTests",
            dependencies: [
                "CiderCore",
                "CiderProject",
                "CiderUI",
                "CiderRuntime",
                "CiderHostTesting",
            ],
            path: "tests/integration"
        ),
        .testTarget(
            name: "CiderVisualTests",
            dependencies: [
                "CiderCore",
                "CiderUI",
                "CiderUITree",
                "CiderRuntime",
                "CiderHostTesting",
            ],
            path: "tests/visual",
            // Baselines are read from the source tree by path, not from a
            // resource bundle, because a recording run has to write them back.
            exclude: ["Baselines"]
        ),
    ]
)
