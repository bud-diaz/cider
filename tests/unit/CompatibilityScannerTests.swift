//  Unit tests for the Stage 4 compatibility scanner.
//
//  The scanner is the first developer-experience surface: it should recognize a
//  small, documented set of unsupported APIs and turn them into actionable
//  diagnostics before the developer reaches a confusing compiler/runtime error.

import Foundation
import XCTest

@testable import CiderCore
@testable import CiderProject

final class CompatibilityScannerTests: XCTestCase {

    func testSupportedCiderUIAPIsDoNotProduceDiagnostics() {
        let source = """
            import CiderUI

            struct NotesApp: CiderApp {
                @CiderState private var note = ""

                var body: some CiderView {
                    VStack {
                        Text("Notes")
                        TextField($note, width: 240)
                        Button("Save") {}
                    }
                }
            }
            """

        let diagnostics = CompatibilityScanner.scan(source, file: "NotesApp.swift")

        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testRecognizedUnsupportedAPIsProduceActionableDiagnostics() {
        let source = """
            import SwiftUI
            import StoreKit

            struct Paywall: View {
                var body: some View {
                    List {
                        Text("Upgrade")
                    }
                }

                func purchase() async throws {
                    _ = try await Product.products(for: ["pro"])
                }
            }
            """

        let diagnostics = CompatibilityScanner.scan(source, file: "Paywall.swift")

        XCTAssertEqual(diagnostics.map(\.code), ["CID0605", "CID0605", "CID0605", "CID0605"])
        XCTAssertEqual(diagnostics.map { $0.location?.line }, [1, 2, 4, 12])
        XCTAssertTrue(diagnostics.allSatisfy { $0.severity == .warning })
        XCTAssertTrue(diagnostics[0].summary.contains("SwiftUI"))
        XCTAssertTrue(diagnostics[1].summary.contains("StoreKit"))
        XCTAssertTrue(diagnostics[2].remedy?.contains("Use CiderView") == true)
        XCTAssertTrue(diagnostics[3].reason?.contains("purchases") == true)
    }

    func testScannerIgnoresCommentsAndStringLiterals() {
        let source = #"""
            // TODO: evaluate SwiftUI someday
            let frameworkName = "StoreKit"
            let message = "URLSession is not used here"
            Text("Camera")
            """#

        let diagnostics = CompatibilityScanner.scan(source, file: "Comments.swift")

        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testScanningAProjectReportsSwiftFilesOutsideBuildArtifacts() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("Cider.yaml")
        let appSource = root.appendingPathComponent("Sources/App/Paywall.swift")
        let buildSource = root.appendingPathComponent(".build/checkouts/Ignored.swift")
        try FileManager.default.createDirectory(at: appSource.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildSource.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "import SwiftUI\n".write(to: appSource, atomically: true, encoding: .utf8)
        try "import StoreKit\n".write(to: buildSource, atomically: true, encoding: .utf8)

        let project = Project(
            root: root,
            manifestURL: manifestURL,
            manifest: Manifest(
                appID: "dev.cider.scan",
                appName: "Scan",
                appEntry: "ScanApp",
                minimumCompatibility: "0.1",
                deviceProfileName: "phone-standard",
                permissions: .none
            )
        )

        let diagnostics = try CompatibilityScanner.scan(project: project)

        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].location?.file, appSource.path)
        XCTAssertTrue(diagnostics[0].summary.contains("SwiftUI"))
    }

    func testRegistryPublishesStableStage4Entries() {
        let swiftUI = CompatibilityRegistry.entry(named: "SwiftUI")
        let camera = CompatibilityRegistry.entry(named: "Camera")

        XCTAssertEqual(swiftUI?.level, .recognizedUnsupported)
        XCTAssertEqual(swiftUI?.domain, "Declarative UI")
        XCTAssertEqual(camera?.level, .recognizedUnsupported)
        XCTAssertEqual(camera?.domain, "Device services")
        XCTAssertTrue(CompatibilityRegistry.all.contains { $0.symbol == "CiderHTTP" && $0.level == .compatibleWithDifferences })
    }

    func testCompatibilityDocumentationIsGeneratedFromTheRegistry() {
        let markdown = CompatibilityDocumentation.markdown()

        XCTAssertTrue(markdown.contains("# Cider Compatibility Registry"))
        XCTAssertTrue(markdown.contains("| Symbol | Domain | Level | Summary | Guidance |"))
        XCTAssertTrue(markdown.contains("| `CiderHTTP` | HTTP networking | B | permission-checked blocking HTTP helper |"))
        XCTAssertTrue(markdown.contains("| `SwiftUI` | Declarative UI | D | SwiftUI is not implemented by Cider |"))
        XCTAssertTrue(markdown.contains("Generated from `CompatibilityRegistry`"))
    }

    // MARK: - Helpers

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
