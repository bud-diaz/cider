//  Transport-level tests for the `cider dev` HTTP server.
//
//  These cover the two things the routing tests cannot: how bytes arrive off a
//  real socket, and what the console does with a request that did not come from
//  its own dashboard.

import XCTest
import Foundation
#if canImport(Glibc)
import Glibc
#endif

@testable import CiderCore
@testable import CiderProject

final class DevHTTPServerTests: XCTestCase {

    /// A browser routinely writes a request's head and body in separate
    /// segments. The server used to do a single `read()`, so a POST could
    /// arrive with an empty body and nothing anywhere reported a problem.
    func testPostBodySplitAcrossWritesIsReassembled() throws {
        #if canImport(Glibc)
        let port = 9881
        let received = ReceivedBody()
        let server = DevHTTPServer(port: port) { request in
            received.value = String(decoding: request.body, as: UTF8.self)
            return .text("ok")
        }
        try server.start()
        defer { server.stop() }

        let body = #"{"property":"fontSize","value":"32"}"#
        let head = "POST /api/editor/apply HTTP/1.1\r\n"
            + "Host: 127.0.0.1:\(port)\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(body.utf8.count)\r\n"
            + "\r\n"

        let client = try connectToLoopback(port: port)
        defer { Glibc.close(client) }

        // Head first, then the body as a separate segment -- what a browser does.
        try write(head, to: client)
        Thread.sleep(forTimeInterval: 0.05)
        try write(body, to: client)

        _ = readAll(from: client)
        XCTAssertEqual(received.value, body, "the body must be waited for, not assumed to have arrived")
        #endif
    }

    /// The complement of the refusals below: with the token and its own origin,
    /// a mutating request goes through as it always did.
    func testAuthorizedMutatingRequestIsAccepted() throws {
        let server = try makeDashboard(port: 9882)
        let response = server.handle(
            method: "POST",
            path: "/api/sandbox/reset",
            headers: ["host": "127.0.0.1:9882", DevSessionToken.headerName: server.token]
        )
        XCTAssertEqual(response.status, 200)
    }

    /// The transport enforces this before a handler ever runs, so one
    /// connection cannot hold the single-threaded accept loop with an endless
    /// body.
    func testBodyCapIsPublished() {
        XCTAssertEqual(DevHTTPServer.maximumBodyBytes, 1 << 20)
    }

    /// Loopback is not a security boundary: any page the developer visits can
    /// POST to 127.0.0.1 and the browser will deliver it. Before this, that
    /// reached the sandbox reset; with a write route it would reach their
    /// source files.
    func testMutatingRequestWithoutTheSessionTokenIsRefused() throws {
        let server = try makeDashboard(port: 9883)
        let response = server.handle(
            method: "POST",
            path: "/api/sandbox/reset",
            headers: ["host": "127.0.0.1:9883"]
        )
        XCTAssertEqual(response.status, 403)
        let payload = try JSONDecoder().decode(DevDiagnosticPayload.self, from: response.body)
        XCTAssertEqual(payload.code, "CID0631")
    }

    func testMutatingRequestFromAnotherOriginIsRefusedEvenWithAToken() throws {
        let server = try makeDashboard(port: 9884)
        let response = server.handle(
            method: "POST",
            path: "/api/sandbox/reset",
            headers: [
                "host": "127.0.0.1:9884",
                "origin": "https://example.invalid",
                DevSessionToken.headerName: server.token,
            ]
        )
        XCTAssertEqual(response.status, 403)
        let payload = try JSONDecoder().decode(DevDiagnosticPayload.self, from: response.body)
        XCTAssertEqual(payload.code, "CID0631")
    }

    func testSessionTokenIsNotHandedToAnotherOrigin() throws {
        let server = try makeDashboard(port: 9885)
        let refused = server.handle(
            method: "GET",
            path: "/api/dev/session",
            headers: ["host": "127.0.0.1:9885", "origin": "https://example.invalid"]
        )
        XCTAssertEqual(refused.status, 403)

        let allowed = server.handle(
            method: "GET",
            path: "/api/dev/session",
            headers: ["host": "127.0.0.1:9885", "origin": "http://127.0.0.1:9885"]
        )
        XCTAssertEqual(allowed.status, 200)
        XCTAssertFalse(server.token.isEmpty)
    }

    /// A custom request header is what forces the preflight; refusing to answer
    /// one would make the token unsendable.
    func testPreflightAdvertisesTheTokenHeader() throws {
        let server = try makeDashboard(port: 9886)
        let response = server.handle(method: "OPTIONS", path: "/api/editor/apply")
        XCTAssertEqual(response.status, 204)
        XCTAssertEqual(
            response.headers["Access-Control-Allow-Headers"],
            "Content-Type, \(DevSessionToken.headerName)"
        )
    }

    func testEveryGeneratedTokenIsDistinct() {
        XCTAssertNotEqual(DevSessionToken.generate().token, DevSessionToken.generate().token)
        XCTAssertEqual(DevSessionToken.generate().token.count, 64, "32 bytes, hex encoded")
    }

    // MARK: - Helpers

    private final class ReceivedBody: @unchecked Sendable {
        var value: String = ""
    }

    private func makeDashboard(port: Int) throws -> DevDashboardServer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cider-dev-http-\(UUID().uuidString)")
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
        let project = try ProjectLocator.locate(from: root)
        let workspace = DevWorkspace(project: project)
        try workspace.prepare()
        return DevDashboardServer(
            project: project,
            workspace: workspace,
            events: DevEventLog(url: workspace.eventsURL),
            port: port
        )
    }

    #if canImport(Glibc)
    private func connectToLoopback(port: Int) throws -> Int32 {
        let handle = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Glibc.connect(handle, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            Glibc.close(handle)
            throw XCTSkip("could not reach the test server on 127.0.0.1:\(port)")
        }
        return handle
    }

    private func write(_ text: String, to handle: Int32) throws {
        var bytes = Array(text.utf8)
        let count = bytes.count
        let written = bytes.withUnsafeMutableBytes { Glibc.write(handle, $0.baseAddress, count) }
        XCTAssertEqual(written, count)
    }

    private func readAll(from handle: Int32) -> String {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = Glibc.read(handle, &buffer, buffer.count)
        guard count > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
    }
    #endif
}
