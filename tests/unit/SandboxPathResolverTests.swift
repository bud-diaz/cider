//  Unit tests for the per-app sandbox data root.
//
//  docs/06-testing-strategy.md lists "sandbox path resolution" and "path
//  traversal resistance" under the unit-test layer explicitly.

import Foundation
import XCTest

import CiderCore
@testable import CiderProject

final class SandboxPathResolverTests: XCTestCase {

    func testDataRootIsIsolatedByAppID() {
        let env = ["XDG_DATA_HOME": "/tmp/cider-test-xdg"]

        let a = SandboxPathResolver.dataRoot(for: "dev.cider.appa", environment: env)
        let b = SandboxPathResolver.dataRoot(for: "dev.cider.appb", environment: env)

        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.path.hasPrefix("/tmp/cider-test-xdg/cider/apps/"))
        XCTAssertTrue(a.path.hasSuffix("dev.cider.appa"))
    }

    func testXDGDataHomeIsHonoured() {
        let root = SandboxPathResolver.dataRoot(
            for: "dev.cider.hello",
            environment: ["XDG_DATA_HOME": "/tmp/cider-test-xdg"]
        )
        XCTAssertEqual(root.path, "/tmp/cider-test-xdg/cider/apps/dev.cider.hello")
    }

    func testFallsBackToHomeShareWhenXDGDataHomeIsUnset() {
        let root = SandboxPathResolver.dataRoot(for: "dev.cider.hello", environment: [:])
        XCTAssertTrue(
            root.path.hasSuffix(".local/share/cider/apps/dev.cider.hello"),
            "expected the XDG default fallback, got \(root.path)"
        )
    }

    func testPrepareCreatesTheStandardSubdirectories() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("cider-sandbox-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }

        let root = try SandboxPathResolver.prepare(
            for: "dev.cider.hello",
            environment: ["XDG_DATA_HOME": base.path]
        )

        var isDirectory: ObjCBool = false
        for subdirectory in ["Documents", "Cache", "tmp"] {
            let path = root.appendingPathComponent(subdirectory).path
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                "expected \(path) to exist"
            )
            XCTAssertTrue(isDirectory.boolValue)
        }
    }

    func testPrepareRejectsAnInvalidAppID() {
        XCTAssertThrowsError(
            try SandboxPathResolver.prepare(for: "../../etc", environment: [:])
        ) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0423")
        }
    }

    func testPrepareRejectsAnAppIDContainingAPathSeparator() {
        XCTAssertThrowsError(
            try SandboxPathResolver.prepare(for: "dev.cider/hello", environment: [:])
        ) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0423")
        }
    }
}
