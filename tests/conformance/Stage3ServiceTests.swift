//  Stage 3 application-service conformance tests.

import XCTest
import Foundation
#if canImport(Glibc)
import Glibc
#endif

import CiderCore
import CiderRuntime

@testable import CiderUI

final class Stage3ServiceTests: XCTestCase {

    // MARK: - ENV-VALUES-001

    /// ENV-VALUES-001: applications can read stable runtime environment values.
    func testENV_VALUES_001_runtimeEnvironmentValuesAreExposed() throws {
        let sandbox = try temporarySandbox()
        let harness = try ConformanceHarness(
            ServiceProbeApp(),
            permissions: AppPermissions(network: false, localStorage: true),
            sandboxDataRoot: sandbox.path
        )
        try harness.launch()

        XCTAssertEqual(CiderEnvironment.appID, "dev.cider.conformance")
        XCTAssertEqual(CiderEnvironment.appName, "Conformance")
        XCTAssertEqual(CiderEnvironment.deviceName, "phone-standard")
        XCTAssertEqual(CiderEnvironment.sandboxRoot, sandbox.path)
    }

    // MARK: - STORE-PREF-001

    /// STORE-PREF-001: preferences persist string values inside the app sandbox.
    func testSTORE_PREF_001_preferencesPersistInsideSandbox() throws {
        let sandbox = try temporarySandbox()
        let harness = try ConformanceHarness(
            ServiceProbeApp(),
            permissions: AppPermissions(network: false, localStorage: true),
            sandboxDataRoot: sandbox.path
        )
        try harness.launch()

        try CiderPreferences.standard.set("amber", forKey: "accent")
        XCTAssertEqual(try CiderPreferences.standard.string(forKey: "accent"), "amber")

        let prefsFile = sandbox.appendingPathComponent("Preferences/preferences.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: prefsFile.path))
    }

    /// STORE-PREF-001: preferences fail with a diagnostic when local storage is not granted.
    func testSTORE_PREF_001_preferencesRequireLocalStoragePermission() throws {
        let harness = try ConformanceHarness(ServiceProbeApp())
        try harness.launch()

        XCTAssertThrowsError(try CiderPreferences.standard.set("denied", forKey: "accent")) { error in
            let diagnostic = error as? Diagnostic
            XCTAssertEqual(diagnostic?.code, "CID0601")
            XCTAssertTrue(diagnostic?.summary.contains("local storage permission") ?? false)
        }
    }

    // MARK: - STORE-FILE-001

    /// STORE-FILE-001: documents/cache/temp text files are scoped to the sandbox.
    func testSTORE_FILE_001_storageAreasReadAndWriteText() throws {
        let sandbox = try temporarySandbox()
        let harness = try ConformanceHarness(
            ServiceProbeApp(),
            permissions: AppPermissions(network: false, localStorage: true),
            sandboxDataRoot: sandbox.path
        )
        try harness.launch()

        try CiderStorage.documents.writeText("note", named: "note.txt")
        try CiderStorage.cache.writeText("cached", named: "response.txt")
        try CiderStorage.temporary.writeText("tmp", named: "scratch.txt")

        XCTAssertEqual(try CiderStorage.documents.readText(named: "note.txt"), "note")
        XCTAssertEqual(try CiderStorage.cache.readText(named: "response.txt"), "cached")
        XCTAssertEqual(try CiderStorage.temporary.readText(named: "scratch.txt"), "tmp")
    }

    /// STORE-FILE-001: storage refuses absolute or parent-traversing names.
    func testSTORE_FILE_001_storageRejectsUnsafeNames() throws {
        let sandbox = try temporarySandbox()
        let harness = try ConformanceHarness(
            ServiceProbeApp(),
            permissions: AppPermissions(network: false, localStorage: true),
            sandboxDataRoot: sandbox.path
        )
        try harness.launch()

        XCTAssertThrowsError(try CiderStorage.documents.writeText("escape", named: "../escape.txt")) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0603")
        }
    }

    // MARK: - CLIPBOARD-001

    /// CLIPBOARD-001: the development clipboard stores and returns text for the running app.
    func testCLIPBOARD_001_clipboardStoresText() throws {
        let harness = try ConformanceHarness(ServiceProbeApp())
        try harness.launch()

        CiderClipboard.copy("copied")
        XCTAssertEqual(CiderClipboard.text, "copied")
    }

    // MARK: - TIMER-001

    /// TIMER-001: a one-shot timer runs application code after its interval.
    func testTIMER_001_timerRunsAfterDelay() throws {
        let expectation = expectation(description: "timer fired")
        let harness = try ConformanceHarness(ServiceProbeApp())
        try harness.launch()

        CiderTimer.after(milliseconds: 10) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - LIFE-BG-001

    /// LIFE-BG-001: tests can simulate foreground/background lifecycle transitions.
    func testLIFE_BG_001_runtimeCanSimulateBackgroundAndForeground() throws {
        let harness = try ConformanceHarness(ServiceProbeApp())
        try harness.launch()

        harness.runtime.enterBackground()
        XCTAssertEqual(harness.runtime.state, .background)

        harness.runtime.enterForeground()
        XCTAssertEqual(harness.runtime.state, .foreground)
    }

    // MARK: - NET-HTTP-001

    /// NET-HTTP-001: HTTP requests enforce the manifest network permission before touching the network.
    func testNET_HTTP_001_httpRequiresNetworkPermission() async throws {
        let harness = try ConformanceHarness(ServiceProbeApp())
        try harness.launch()

        do {
            _ = try await CiderHTTP.get("https://example.invalid")
            XCTFail("request should have been denied before network access")
        } catch let diagnostic as Diagnostic {
            XCTAssertEqual(diagnostic.code, "CID0604")
        }
    }

    /// NET-HTTP-001: HTTP requests can complete against a deterministic loopback server.
    func testNET_HTTP_001_httpReturnsLoopbackResponseWhenNetworkIsGranted() async throws {
        let server = try DeterministicHTTPServer(
            statusCode: 203,
            body: "{\"message\":\"hello from cider\"}"
        )
        try server.start()
        defer { server.stop() }

        let harness = try ConformanceHarness(
            ServiceProbeApp(),
            permissions: AppPermissions(network: true, localStorage: false)
        )
        try harness.launch()

        let response = try await CiderHTTP.get(server.url)

        XCTAssertEqual(response.statusCode, 203)
        XCTAssertEqual(response.body, "{\"message\":\"hello from cider\"}")
        XCTAssertEqual(server.requestPath, "/stage3-http")
    }

    /// NET-HTTP-001: blocking HTTP preserves the response status for button-action demos.
    func testNET_HTTP_001_getBlockingReturnsLoopbackStatusCode() throws {
        let server = try DeterministicHTTPServer(statusCode: 204, body: "")
        try server.start()
        defer { server.stop() }

        let harness = try ConformanceHarness(
            ServiceProbeApp(),
            permissions: AppPermissions(network: true, localStorage: false)
        )
        try harness.launch()

        let response = try CiderHTTP.getBlocking(server.url)

        XCTAssertEqual(response.statusCode, 204)
        XCTAssertEqual(response.body, "")
        XCTAssertEqual(server.requestPath, "/stage3-http")
    }

    private func temporarySandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cider-stage3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Cache"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("tmp"), withIntermediateDirectories: true)
        return url
    }
}

struct ServiceProbeApp: CiderApp {
    var body: some CiderView {
        Text("Services")
    }
}

#if canImport(Glibc)
/// Single-request HTTP/1.1 loopback fixture for deterministic CiderHTTP tests.
///
/// The fixture deliberately binds to port 0 so the OS chooses an available local
/// port, accepts one request, records its path, and returns a fixed UTF-8 body.
/// It keeps NET-HTTP-001 honest without depending on the public internet.
final class DeterministicHTTPServer: @unchecked Sendable {
    private let statusCode: Int
    private let body: String
    private var socketFD: Int32 = -1
    private let queue = DispatchQueue(label: "cider-deterministic-http-server")
    private let lock = NSLock()
    private var capturedPath: String?

    init(statusCode: Int, body: String) throws {
        self.statusCode = statusCode
        self.body = body
    }

    var url: String {
        "http://127.0.0.1:\(port)/stage3-http"
    }

    var requestPath: String? {
        lock.lock()
        defer { lock.unlock() }
        return capturedPath
    }

    private var port: UInt16 {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                _ = Glibc.getsockname(socketFD, sockaddrPointer, &length)
            }
        }
        return UInt16(bigEndian: address.sin_port)
    }

    func start() throws {
        socketFD = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        guard socketFD >= 0 else { throw NSError(domain: "DeterministicHTTPServer", code: 1) }

        var yes: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Glibc.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { stop(); throw NSError(domain: "DeterministicHTTPServer", code: 2) }
        guard Glibc.listen(socketFD, 1) == 0 else { stop(); throw NSError(domain: "DeterministicHTTPServer", code: 3) }

        queue.async { [self] in handleOneRequest() }
    }

    func stop() {
        if socketFD >= 0 {
            Glibc.close(socketFD)
            socketFD = -1
        }
    }

    private func handleOneRequest() {
        let client = Glibc.accept(socketFD, nil, nil)
        guard client >= 0 else { return }
        defer { Glibc.close(client) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = Glibc.read(client, &buffer, buffer.count)
        if count > 0,
           let request = String(bytes: buffer.prefix(Int(count)), encoding: .utf8),
           let requestLine = request.split(separator: "\r\n").first {
            let parts = requestLine.split(separator: " ")
            if parts.count >= 2 {
                lock.lock()
                capturedPath = String(parts[1])
                lock.unlock()
            }
        }

        let responseBody = Array(body.utf8)
        let header = "HTTP/1.1 \(statusCode) Test\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.count)\r\nConnection: close\r\n\r\n"
        var bytes = Array(header.utf8) + responseBody
        let byteCount = bytes.count
        bytes.withUnsafeMutableBytes { raw in
            _ = Glibc.write(client, raw.baseAddress, byteCount)
        }
    }
}
#endif
