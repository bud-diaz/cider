import XCTest
import Foundation

@testable import CiderCore
@testable import CiderProject

final class DevExperienceClosureTests: XCTestCase {
    func testDevWorkspacePreparesDashboardAndArtifactDirectories() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)
        let workspace = DevWorkspace(project: project)

        try workspace.prepare()

        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.inspectorSnapshotURL.deletingLastPathComponent().path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.dashboardDirectory.path))
    }

    func testProjectFileWatcherReportsSwiftChangesAndIgnoresCiderDirectory() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)
        let watcher = try ProjectFileWatcher(project: project)

        try "changed".write(to: root.appendingPathComponent("Sources/Fixture/FixtureApp.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".cider"), withIntermediateDirectories: true)
        try "ignored".write(to: root.appendingPathComponent(".cider/ignored.swift"), atomically: true, encoding: .utf8)

        let changes = try watcher.scan()
        XCTAssertTrue(changes.contains { $0.path.hasSuffix("FixtureApp.swift") })
        XCTAssertFalse(changes.contains { $0.path.contains(".cider") })
    }

    func testSandboxBrowserListsPreviewsAndResetsInsideSandbox() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)
        let xdg = root.appendingPathComponent("xdg")
        let sandboxRoot = try SandboxPathResolver.prepare(for: project.manifest.appID, environment: ["XDG_DATA_HOME": xdg.path])
        let note = sandboxRoot.appendingPathComponent("Documents/note.txt")
        try "hello".write(to: note, atomically: true, encoding: .utf8)
        let browser = SandboxBrowser(project: project, environment: ["XDG_DATA_HOME": xdg.path])

        XCTAssertTrue(try browser.tree().contains { $0.path == "Documents/note.txt" })
        XCTAssertEqual(try browser.preview(relativePath: "Documents/note.txt").text, "hello")
        XCTAssertThrowsError(try browser.preview(relativePath: "../outside.txt"))
        try browser.reset()
        XCTAssertFalse(FileManager.default.fileExists(atPath: note.path))
    }

    func testDashboardRoutesExposeStatusInspectorNetworkAndSandbox() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)
        let workspace = DevWorkspace(project: project)
        try workspace.prepare()
        let events = DevEventLog(url: workspace.eventsURL)
        events.append(kind: "test", message: "event")
        let server = DevDashboardServer(project: project, workspace: workspace, events: events, port: 8765)
        try server.writeStaticAssets()

        XCTAssertEqual(server.handle(method: "GET", path: "/").contentType, "text/html; charset=utf-8")
        XCTAssertEqual(server.handle(method: "GET", path: "/api/inspector/latest").status, 204)
        try "{\"frameCount\":1,\"generatedAtMilliseconds\":1,\"nodes\":[],\"renderCommands\":[],\"hitRegions\":[]}".write(to: workspace.inspectorSnapshotURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(server.handle(method: "GET", path: "/api/inspector/latest").status, 200)
        XCTAssertEqual(server.handle(method: "GET", path: "/api/inspector/frame").status, 204)
        try Data(FrameMirror.encode(Canvas(width: 2, height: 2), logicalWidth: 2, logicalHeight: 2))
            .write(to: workspace.inspectorFrameURL)
        let frame = server.handle(method: "GET", path: "/api/inspector/frame")
        XCTAssertEqual(frame.status, 200)
        XCTAssertEqual(frame.contentType, "application/octet-stream")
        XCTAssertEqual(frame.body.count, FrameMirror.headerLength + 2 * 2 * 4)
        XCTAssertEqual(server.handle(method: "GET", path: "/api/status").status, 200)
        XCTAssertEqual(server.handle(method: "GET", path: "/api/events").status, 200)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.dashboardDirectory.appendingPathComponent("index.html").path))
    }

    func testDevHTTPServerServesDashboardRoutesOnLoopback() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMinimalProject(at: root)
        let project = try ProjectLocator.locate(from: root)
        let workspace = DevWorkspace(project: project)
        try workspace.prepare()
        let events = DevEventLog(url: workspace.eventsURL)
        let dashboard = DevDashboardServer(project: project, workspace: workspace, events: events, port: 9876)
        let server = DevHTTPServer(port: 9876) { request in
            dashboard.handle(method: request.method, path: request.path, query: request.query, body: request.body)
        }
        try server.start()
        defer { server.stop() }

        let data = try Data(contentsOf: URL(string: "http://127.0.0.1:9876/api/status")!)
        let status = try JSONDecoder().decode(DevDashboardStatus.self, from: data)
        XCTAssertEqual(status.project, "Fixture")
    }

    func testRequestHeaderRedactionCoversSensitiveNames() {
        let redacted = RequestHeaderRedaction.redact([
            "Authorization": "Bearer abc",
            "x-api-key": "key",
            "content-type": "application/json",
            "custom-token": "secret"
        ])
        XCTAssertEqual(redacted["Authorization"], "[redacted]")
        XCTAssertEqual(redacted["x-api-key"], "[redacted]")
        XCTAssertEqual(redacted["custom-token"], "[redacted]")
        XCTAssertEqual(redacted["content-type"], "application/json")
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func writeMinimalProject(at root: URL) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources/Fixture"), withIntermediateDirectories: true)
        try """
        app:
          id: dev.cider.fixture
          name: Fixture
          entry: FixtureApp
        permissions:
          network: true
          localStorage: true
        """.write(to: root.appendingPathComponent("Cider.yaml"), atomically: true, encoding: .utf8)
        try "import CiderUI\n".write(to: root.appendingPathComponent("Sources/Fixture/FixtureApp.swift"), atomically: true, encoding: .utf8)
    }
}
