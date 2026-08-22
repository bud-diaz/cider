//  Integration tests.
//
//  These exercise the path a real `cider run` takes -- locate the project on
//  disk, parse its manifest, resolve a device profile, produce a launch
//  descriptor, start a runtime with it, and drive input -- rather than any one
//  layer in isolation.
//
//  The project they read is the checked-in `examples/hello-cider`. That is
//  deliberate: it means the reference application cannot drift away from what
//  the toolchain accepts without a test going red.

import XCTest

import CiderCore
import CiderDeviceProfiles
import CiderHost
import CiderHostTesting
import CiderProject
import CiderRuntime
import CiderUITree

@testable import CiderUI

final class ProjectIntegrationTests: XCTestCase {

    /// Walks up from this source file to the repository root.
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)      // tests/integration/ProjectIntegrationTests.swift
            .deletingLastPathComponent()     // tests/integration
            .deletingLastPathComponent()     // tests
            .deletingLastPathComponent()     // repository root
    }

    private var exampleRoot: URL {
        repositoryRoot
            .appendingPathComponent("examples")
            .appendingPathComponent("hello-cider")
    }

    // MARK: - Discovery

    func testLocatesTheExampleProject() throws {
        let project = try ProjectLocator.locate(from: exampleRoot)

        XCTAssertEqual(project.root.standardizedFileURL.path, exampleRoot.standardizedFileURL.path)
        XCTAssertEqual(project.manifest.appID, "dev.cider.hello")
        XCTAssertEqual(project.manifest.appName, "Hello Cider")
        XCTAssertEqual(project.manifest.appEntry, "HelloCiderApp")
        XCTAssertEqual(project.manifest.deviceProfileName, "phone-standard")
        XCTAssertTrue(project.manifest.permissions.localStorage)
        XCTAssertFalse(project.manifest.permissions.network)
    }

    func testSearchesUpwardFromASubdirectory() throws {
        // `cider run` should work from anywhere inside a project, the way git
        // and other build tools do.
        let nested = exampleRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("HelloCider")

        let project = try ProjectLocator.locate(from: nested)
        XCTAssertEqual(project.root.standardizedFileURL.path, exampleRoot.standardizedFileURL.path)
    }

    func testMissingProjectExplainsWhereItLooked() {
        XCTAssertThrowsError(try ProjectLocator.locate(from: URL(fileURLWithPath: "/"))) { error in
            let diagnostic = error as? Diagnostic
            XCTAssertEqual(diagnostic?.code, "CID0420")
            XCTAssertTrue(diagnostic?.remedy?.contains("Cider.yaml") ?? false)
        }
    }

    func testTheExampleDeclaresExactlyOneEntryType() throws {
        // `entry` names the @main type. If the two drift apart, `cider run`
        // launches something the manifest does not describe.
        let project = try ProjectLocator.locate(from: exampleRoot)
        let source = try String(
            contentsOf: exampleRoot
                .appendingPathComponent("Sources/HelloCider/HelloCiderApp.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            source.contains("struct \(project.manifest.appEntry): CiderApp"),
            "Cider.yaml says entry is `\(project.manifest.appEntry)`, which the sources do not define"
        )
        XCTAssertTrue(source.contains("@main"))
    }

    // MARK: - Manifest to launch descriptor

    func testManifestProducesADescriptorTheRuntimeAccepts() throws {
        let project = try ProjectLocator.locate(from: exampleRoot)
        let descriptor = project.manifest.launchDescriptor()

        // Round-trip through the on-the-wire form, as `cider run` does.
        let decoded = try LaunchDescriptor.decode(descriptor.encoded())
        XCTAssertEqual(decoded, descriptor)

        let profile = try DeviceProfileRegistry.resolve(decoded.deviceProfileName)
        XCTAssertEqual(profile.name, "phone-standard")
    }

    func testCommandLineOverridesReachTheDescriptor() throws {
        let project = try ProjectLocator.locate(from: exampleRoot)
        let descriptor = project.manifest.launchDescriptor(
            deviceOverride: "phone-standard",
            logLevel: .trace,
            inspectorEnabled: true
        )

        XCTAssertEqual(descriptor.logLevel, .trace)
        XCTAssertTrue(descriptor.inspectorEnabled)
        XCTAssertEqual(descriptor.permissions, project.manifest.permissions,
                       "overrides must not silently widen permissions")
    }

    // MARK: - End to end, headless

    /// The whole chain: the real manifest configures a runtime, the reference
    /// application runs in it, and a tap changes what is on screen.
    func testExampleManifestDrivesARunnableApplication() throws {
        let project = try ProjectLocator.locate(from: exampleRoot)
        let descriptor = try LaunchDescriptor.decode(
            project.manifest.launchDescriptor(logLevel: .debug).encoded()
        )

        let backend = TestingHostBackend()
        let logSink = MemoryLogSink()
        let runtime = try ApplicationRuntime(
            descriptor: descriptor,
            application: CiderAppAdapter(app: ReferenceCounterApp()),
            backend: backend,
            logSink: logSink
        )

        try runtime.launch()
        XCTAssertEqual(runtime.deviceProfile.name, project.manifest.deviceProfileName)
        XCTAssertTrue(logSink.messages().contains("launching \(project.manifest.appID)"))

        let tree = try XCTUnwrap(runtime.currentRenderTree)
        let button = try XCTUnwrap(tree.hitRegions.first)
        let center = Point(x: button.frame.midX, y: button.frame.midY)

        backend.send([
            .pointerDown(location: center, button: .primary),
            .pointerUp(location: center, button: .primary),
        ])
        try runtime.pump()

        let strings = (runtime.currentRenderTree?.commands ?? []).compactMap { command -> String? in
            if case .text(let content, _, _, _) = command { return content }
            return nil
        }
        XCTAssertTrue(strings.contains("Count: 1"))

        try runtime.pump()
        runtime.terminate()
        XCTAssertEqual(runtime.state, .terminated)
    }

    /// The inspector's dump reflects what was actually laid out.
    func testInspectorDumpDescribesTheRealTree() throws {
        let backend = TestingHostBackend()
        let runtime = try ApplicationRuntime(
            descriptor: LaunchDescriptor(
                appID: "dev.cider.integration",
                appName: "Integration",
                appEntry: "ReferenceCounterApp",
                minimumCompatibility: "0.1",
                deviceProfileName: "phone-standard",
                permissions: .none,
                logLevel: .debug,
                inspectorEnabled: true
            ),
            application: CiderAppAdapter(app: ReferenceCounterApp()),
            backend: backend,
            logSink: MemoryLogSink()
        )
        try runtime.launch()

        let node = try XCTUnwrap(runtime.currentRenderTree)
        XCTAssertEqual(node.hitRegions.count, 1)
        XCTAssertNotNil(runtime.currentLayout)
    }
}

/// A copy of the reference application's view code.
///
/// The example lives in its own SwiftPM package, so it cannot be imported here.
/// `testTheExampleDeclaresExactlyOneEntryType` guards the part that matters --
/// that the manifest and the sources agree -- and this stands in for the body.
struct ReferenceCounterApp: CiderApp {
    @CiderState private var count = 0

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Cider Demo")
                .font(size: 28, weight: .bold)

            Button("Press Me") {
                count += 1
            }

            Text("Count: \(count)")
        }
    }
}
