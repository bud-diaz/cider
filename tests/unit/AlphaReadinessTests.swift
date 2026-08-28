//  Unit tests for Stage 5 alpha-readiness reporting.

import Foundation
import XCTest

@testable import CiderProject

final class AlphaReadinessTests: XCTestCase {
    func testAlphaReadinessReportPublishesVersionedContractAndGateStatuses() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeAlphaFixture(at: root, referenceApps: 3, ci: "runs-on: ubuntu-24.04\n")

        let report = AlphaReadinessReport.markdown(repoRoot: root)

        XCTAssertTrue(report.contains("# Cider Alpha Readiness"))
        XCTAssertTrue(report.contains("alpha version: 0.1.0-alpha.0"))
        XCTAssertTrue(report.contains("compatibility contract: 0.1"))
        XCTAssertTrue(report.contains("| versioned compatibility contract | partial | contract 0.1, CLI 0.1.0-alpha.0"))
        XCTAssertTrue(report.contains("| at least 10 reference applications | partial | 3 example app(s) with Cider.yaml under examples/ | Add 7 more reference apps"))
        XCTAssertTrue(report.contains("| CI on supported Ubuntu versions | partial | CI runners: ubuntu-24.04 | Expand CI"))
    }

    func testAlphaReadinessMarksReferenceAndUbuntuGatesDoneWhenThresholdsAreMet() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeAlphaFixture(at: root, referenceApps: 10, ci: "runs-on: ubuntu-22.04\nruns-on: ubuntu-24.04\n")

        let gates = AlphaReadinessReport.evaluate(repoRoot: root)

        XCTAssertEqual(gates.first { $0.requirement == "at least 10 reference applications" }?.status, .done)
        XCTAssertEqual(gates.first { $0.requirement == "CI on supported Ubuntu versions" }?.status, .done)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func writeAlphaFixture(at root: URL, referenceApps: Int, ci: String) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".github/workflows"), withIntermediateDirectories: true)
        try "security".write(to: root.appendingPathComponent("SECURITY.md"), atomically: true, encoding: .utf8)
        try "contributing".write(to: root.appendingPathComponent("CONTRIBUTING.md"), atomically: true, encoding: .utf8)
        try "install".write(to: root.appendingPathComponent("docs/install.md"), atomically: true, encoding: .utf8)
        try "registry".write(to: root.appendingPathComponent("docs/compatibility-registry.md"), atomically: true, encoding: .utf8)
        try "issues".write(to: root.appendingPathComponent("docs/known-issues.md"), atomically: true, encoding: .utf8)
        try "perf".write(to: root.appendingPathComponent("docs/performance-baseline.md"), atomically: true, encoding: .utf8)
        try ci.write(to: root.appendingPathComponent(".github/workflows/ci.yml"), atomically: true, encoding: .utf8)

        let examples = root.appendingPathComponent("examples", isDirectory: true)
        for index in 0..<referenceApps {
            let app = examples.appendingPathComponent("app-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
            try "app:\n  id: dev.cider.app\(index)\n".write(to: app.appendingPathComponent("Cider.yaml"), atomically: true, encoding: .utf8)
        }
    }
}
