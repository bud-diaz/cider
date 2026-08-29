//  The write route, against a real project on disk.
//
//    EDIT-WRITE-001   applying an edit rewrites the source and leaves the rest
//                     of the file byte-identical
//    EDIT-REFUSE-001  a stale, out-of-project or unauthenticated edit is
//                     refused and the file is left untouched
//
//  `SwiftSourceEditorTests` covers the rewriting itself. What is proved here is
//  the part that touches a developer's disk: which paths the console will
//  write to, what happens when two edits race a rebuild, and that a refusal
//  reaches the browser as something it can display.

import XCTest
import Foundation

@testable import CiderCore
@testable import CiderProject

final class SourceEditIntegrationTests: XCTestCase {

    private var root: URL!
    private var sourceURL: URL!
    private var server: DevDashboardServer!

    private let originalSource = """
        import CiderUI

        @main
        struct FixtureApp: CiderApp {
            var body: some CiderView {
                VStack(spacing: 24) {
                    Text("Cider Demo")
                        .font(size: 28, weight: .bold)
                }
            }
        }

        """

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cider-edit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources/Fixture"),
            withIntermediateDirectories: true
        )
        try """
            app:
              id: dev.cider.fixture
              name: Fixture
              entry: FixtureApp
            """.write(to: root.appendingPathComponent("Cider.yaml"), atomically: true, encoding: .utf8)

        sourceURL = root.appendingPathComponent("Sources/Fixture/FixtureApp.swift")
        try originalSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        let project = try ProjectLocator.locate(from: root)
        let workspace = DevWorkspace(project: project)
        try workspace.prepare()
        server = DevDashboardServer(
            project: project,
            workspace: workspace,
            events: DevEventLog(url: workspace.eventsURL),
            port: 9901
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - EDIT-WRITE-001

    /// EDIT-WRITE-001: an edit changes exactly the value it names.
    func testEDIT_WRITE_001_rewritesTheValueAndNothingElse() throws {
        let response = try apply(
            SourceEditRequest(
                file: sourceURL.path,
                line: 7,
                column: 13,
                head: "Text",
                property: "fontSize",
                value: "36",
                expectedCurrentValue: "28.0",
                siblingValues: nil
            )
        )
        XCTAssertEqual(response.status, 200)

        let written = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertEqual(written, originalSource.replacingOccurrences(of: "size: 28", with: "size: 36"))
    }

    /// EDIT-WRITE-001: a second edit is held until the application has
    /// relaunched, because the first one may already have moved the positions
    /// the panel is still showing.
    func testEDIT_WRITE_001_holdsASecondEditUntilTheRebuildIsSeen() throws {
        _ = try apply(editingFontSize(to: "36", expecting: "28.0"))
        XCTAssertTrue(server.isAwaitingRebuild)

        let held = try apply(editingFontSize(to: "40", expecting: "36"))
        XCTAssertEqual(held.status, 409)
        XCTAssertEqual(try refusalCode(held), "CID0642")

        server.noteRebuildObserved()
        let accepted = try apply(editingFontSize(to: "40", expecting: "36"))
        XCTAssertEqual(accepted.status, 200)
        XCTAssertTrue(try String(contentsOf: sourceURL, encoding: .utf8).contains("size: 40"))
    }

    /// EDIT-WRITE-001: what was replaced is recorded, so an unwanted edit is
    /// recoverable from the event stream rather than from memory.
    func testEDIT_WRITE_001_recordsWhatItReplaced() throws {
        _ = try apply(editingFontSize(to: "36", expecting: "28.0"))
        let events = server.handle(method: "GET", path: "/api/events")
        let text = String(decoding: events.body, as: UTF8.self)
        XCTAssertTrue(text.contains("fontSize"), "the event stream should name the property")
        XCTAssertTrue(text.contains("36"), "and the value it was given")
    }

    // MARK: - EDIT-REFUSE-001

    /// EDIT-REFUSE-001: a stale expectation means the panel is describing a
    /// file that has since changed, so the edit is refused untouched.
    func testEDIT_REFUSE_001_refusesAStaleValueAndLeavesTheFileAlone() throws {
        let response = try apply(editingFontSize(to: "36", expecting: "17.0"))
        XCTAssertEqual(response.status, 409)
        XCTAssertEqual(try refusalCode(response), "CID0634")
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), originalSource)
    }

    /// EDIT-REFUSE-001: the path comes from the snapshot the *application*
    /// wrote and is then relayed by the browser. It is untrusted at both hops.
    func testEDIT_REFUSE_001_refusesAPathOutsideTheProject() throws {
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("cider-outside-\(UUID().uuidString).swift")
        try originalSource.write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }

        var request = editingFontSize(to: "36", expecting: "28.0")
        request.file = outside.path
        let response = try apply(request)
        XCTAssertEqual(response.status, 400)
        XCTAssertEqual(try refusalCode(response), "CID0632")
        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), originalSource)
    }

    func testEDIT_REFUSE_001_refusesAPathTraversalOutOfTheProject() throws {
        var request = editingFontSize(to: "36", expecting: "28.0")
        request.file = root.appendingPathComponent("Sources/../../escaped.swift").path
        XCTAssertEqual(try refusalCode(try apply(request)), "CID0632")
    }

    func testEDIT_REFUSE_001_refusesAFileTheWatcherWouldNotNotice() throws {
        let notes = root.appendingPathComponent("Sources/Fixture/notes.txt")
        try "hello".write(to: notes, atomically: true, encoding: .utf8)

        var request = editingFontSize(to: "36", expecting: "28.0")
        request.file = notes.path
        XCTAssertEqual(try refusalCode(try apply(request)), "CID0632")
    }

    /// EDIT-REFUSE-001: without the session token the route is not reachable at
    /// all -- a loopback port is reachable from any page a browser has open.
    func testEDIT_REFUSE_001_refusesAnUnauthenticatedEdit() throws {
        let body = try JSONEncoder().encode(editingFontSize(to: "36", expecting: "28.0"))
        let response = server.handle(
            method: "POST",
            path: "/api/editor/apply",
            body: body,
            headers: ["host": "127.0.0.1:9901"]
        )
        XCTAssertEqual(response.status, 403)
        XCTAssertEqual(try refusalCode(response), "CID0631")
        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), originalSource)
    }

    // MARK: - Helpers

    private func editingFontSize(to value: String, expecting current: String) -> SourceEditRequest {
        SourceEditRequest(
            file: sourceURL.path,
            line: 7,
            column: 13,
            head: "Text",
            property: "fontSize",
            value: value,
            expectedCurrentValue: current,
            siblingValues: nil
        )
    }

    private func apply(_ request: SourceEditRequest) throws -> DevDashboardResponse {
        server.handle(
            method: "POST",
            path: "/api/editor/apply",
            body: try JSONEncoder().encode(request),
            headers: ["host": "127.0.0.1:9901", DevSessionToken.headerName: server.token]
        )
    }

    private func refusalCode(_ response: DevDashboardResponse) throws -> String {
        try JSONDecoder().decode(DevDiagnosticPayload.self, from: response.body).code
    }
}
