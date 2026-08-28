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

    func testAlphaReadinessGatesReachDoneWhenEvidenceIsRecordedButPackagingStaysPartial() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeAlphaFixture(
            at: root,
            referenceApps: 10,
            ci: "runs-on: ubuntu-22.04\nruns-on: ubuntu-24.04\n",
            licensed: true,
            releaseNotesTagged: true,
            securityChannelPublished: true,
            performanceRecorded: true
        )

        let gates = AlphaReadinessReport.evaluate(repoRoot: root)
        func status(_ requirement: String) -> AlphaGateStatus? {
            gates.first { $0.requirement == requirement }?.status
        }

        XCTAssertEqual(status("versioned compatibility contract"), .done)
        XCTAssertEqual(status("security reporting"), .done)
        XCTAssertEqual(status("contribution policy"), .done)
        XCTAssertEqual(status("known-issues database"), .done)
        XCTAssertEqual(status("performance baseline"), .done)
        // Packaging has no code-checkable "done" condition by design: signed
        // archives / package-manager distribution are an accepted alpha
        // caveat (see RELEASE_NOTES.md), never a file the report can trust.
        XCTAssertEqual(status("installation packaging"), .partial)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func writeAlphaFixture(
        at root: URL,
        referenceApps: Int,
        ci: String,
        licensed: Bool = false,
        releaseNotesTagged: Bool = false,
        securityChannelPublished: Bool = false,
        performanceRecorded: Bool = false
    ) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".github/workflows"), withIntermediateDirectories: true)
        let securityContent = securityChannelPublished
            ? "security: report via GitHub private vulnerability reporting"
            : "security: has not been published yet"
        try securityContent.write(to: root.appendingPathComponent("SECURITY.md"), atomically: true, encoding: .utf8)
        try "contributing".write(to: root.appendingPathComponent("CONTRIBUTING.md"), atomically: true, encoding: .utf8)
        try "install".write(to: root.appendingPathComponent("docs/install.md"), atomically: true, encoding: .utf8)
        try "registry".write(to: root.appendingPathComponent("docs/compatibility-registry.md"), atomically: true, encoding: .utf8)
        try "issues\n| CIDER-KI-0001 | Open | example |\n".write(to: root.appendingPathComponent("docs/known-issues.md"), atomically: true, encoding: .utf8)
        let perfContent = performanceRecorded ? "perf: measured 1.2s build" : "perf: No public alpha numbers are published yet."
        try perfContent.write(to: root.appendingPathComponent("docs/performance-baseline.md"), atomically: true, encoding: .utf8)
        try ci.write(to: root.appendingPathComponent(".github/workflows/ci.yml"), atomically: true, encoding: .utf8)

        if licensed {
            try "Apache-2.0".write(to: root.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8)
        }
        if releaseNotesTagged {
            try "tagged 0.1.0-alpha.0".write(to: root.appendingPathComponent("RELEASE_NOTES.md"), atomically: true, encoding: .utf8)
        }

        let examples = root.appendingPathComponent("examples", isDirectory: true)
        for index in 0..<referenceApps {
            let app = examples.appendingPathComponent("app-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
            try "app:\n  id: dev.cider.app\(index)\n".write(to: app.appendingPathComponent("Cider.yaml"), atomically: true, encoding: .utf8)
        }
    }
}
