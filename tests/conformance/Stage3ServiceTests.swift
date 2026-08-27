//  Stage 3 application-service conformance tests.

import XCTest

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
