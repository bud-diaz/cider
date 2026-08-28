//  Unit tests for Stage 4 developer-experience helpers.

import Foundation
import XCTest

@testable import CiderProject

final class DeveloperExperienceTests: XCTestCase {
    func testProjectInspectorSummarizesManifestPermissionsAndScanWarnings() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root, source: "import SwiftUI\n")
        let project = try ProjectLocator.locate(from: root)

        let report = try ProjectInspector.report(for: project, environment: ["XDG_DATA_HOME": root.appendingPathComponent("xdg").path])

        XCTAssertTrue(report.contains("# Cider Project Inspector"))
        XCTAssertTrue(report.contains("app id: dev.cider.fixture"))
        XCTAssertTrue(report.contains("network: false"))
        XCTAssertTrue(report.contains("localStorage: true"))
        XCTAssertTrue(report.contains("CID0605"))
        XCTAssertTrue(report.contains("sandbox:"))
    }

    func testNetworkViewerFindsPermissionAndCiderHTTPUrls() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(
            at: root,
            permissions: "network: true\n    localStorage: true",
            source: "let response = try CiderHTTP.getBlocking(\"https://example.com/api\")\n"
        )
        let project = try ProjectLocator.locate(from: root)

        let report = try NetworkViewer.report(for: project)

        XCTAssertTrue(report.contains("# Cider Network Viewer"))
        XCTAssertTrue(report.contains("network permission: true"))
        XCTAssertTrue(report.contains("https://example.com/api"))
    }

    func testStorageViewerListsSandboxFiles() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)
        let xdg = root.appendingPathComponent("xdg")
        let sandbox = try SandboxPathResolver.prepare(for: project.manifest.appID, environment: ["XDG_DATA_HOME": xdg.path])
        let note = sandbox.appendingPathComponent("Documents/note.txt")
        try "hello".write(to: note, atomically: true, encoding: .utf8)

        let report = try StorageViewer.report(for: project, environment: ["XDG_DATA_HOME": xdg.path])

        XCTAssertTrue(report.contains("# Cider Storage Viewer"))
        XCTAssertTrue(report.contains("Documents/note.txt"))
        XCTAssertTrue(report.contains("5 bytes"))
    }

    func testTemplateGeneratorCreatesRunnableProjectShape() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("MyApp")

        try TemplateGenerator.createApp(
            named: "MyApp",
            appID: "dev.example.myapp",
            at: destination,
            ciderPackagePath: "/tmp/cider-fixture"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Cider.yaml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Package.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Sources/MyApp/MyApp.swift").path))
        let package = try String(contentsOf: destination.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(package.contains(".package(path: \"/tmp/cider-fixture\")"))
        let project = try ProjectLocator.locate(from: destination)
        XCTAssertEqual(project.manifest.appID, "dev.example.myapp")
    }

    func testDevLoopPlanDocumentsNoBuildRelaunchPath() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)

        let plan = DevLoopPlanner.plan(for: project, configuration: "debug")

        XCTAssertTrue(plan.contains("swift build"))
        XCTAssertTrue(plan.contains("cider run --no-build"))
        XCTAssertTrue(plan.contains(root.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func writeMinimalProject(
        at root: URL,
        permissions: String = "network: false\n    localStorage: true",
        source: String = "import CiderUI\n"
    ) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources/Fixture"), withIntermediateDirectories: true)
        let permissionLines = permissions
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "  " + String($0).trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        try """
        app:
          id: dev.cider.fixture
          name: Fixture
          entry: FixtureApp
        permissions:
        \(permissionLines)
        """.write(to: root.appendingPathComponent("Cider.yaml"), atomically: true, encoding: .utf8)
        try source.write(to: root.appendingPathComponent("Sources/Fixture/FixtureApp.swift"), atomically: true, encoding: .utf8)
    }
}
