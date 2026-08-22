//  Unit tests for manifest parsing and validation.
//
//  The behaviour under test is as much about the *rejections* as the successes:
//  docs/02-product-requirements.md asks for actionable diagnostics, and a
//  manifest parser that quietly accepts a typo produces a bug report about
//  something else entirely.

import XCTest

@testable import CiderCore
@testable import CiderProject

final class ManifestParsingTests: XCTestCase {

    private let file = "Cider.yaml"

    func testParsesTheReferenceManifest() throws {
        let manifest = try ManifestParser.parse(
            """
            app:
              id: dev.cider.hello
              name: Hello Cider
              entry: HelloCiderApp

            runtime:
              minimumCompatibility: "0.1"
              device: phone-standard

            permissions:
              network: false
              localStorage: true
            """,
            file: file
        )

        XCTAssertEqual(manifest.appID, "dev.cider.hello")
        XCTAssertEqual(manifest.appName, "Hello Cider")
        XCTAssertEqual(manifest.appEntry, "HelloCiderApp")
        XCTAssertEqual(manifest.minimumCompatibility, "0.1")
        XCTAssertEqual(manifest.deviceProfileName, "phone-standard")
        XCTAssertFalse(manifest.permissions.network)
        XCTAssertTrue(manifest.permissions.localStorage)
    }

    func testPermissionsDefaultToDenied() throws {
        let manifest = try ManifestParser.parse(
            """
            app:
              id: dev.cider.minimal
              name: Minimal
              entry: MinimalApp
            """,
            file: file
        )
        XCTAssertEqual(manifest.permissions, .none)
    }

    func testCommentsAndBlankLinesAreIgnored() throws {
        let manifest = try ManifestParser.parse(
            """
            # leading comment
            app:
              id: dev.cider.hello   # trailing comment

              name: Hello Cider
              entry: HelloCiderApp
            """,
            file: file
        )
        XCTAssertEqual(manifest.appID, "dev.cider.hello")
        XCTAssertEqual(manifest.appName, "Hello Cider")
    }

    func testHashInsideQuotesIsNotAComment() throws {
        let manifest = try ManifestParser.parse(
            """
            app:
              id: dev.cider.hello
              name: "Hello # Cider"
              entry: HelloCiderApp
            """,
            file: file
        )
        XCTAssertEqual(manifest.appName, "Hello # Cider")
    }

    func testUnknownKeyIsRejectedWithItsLine() {
        let text = """
            app:
              id: dev.cider.hello
              name: Hello Cider
              entry: HelloCiderApp
              icon: icon.png
            """

        assertDiagnostics(parsing: text) { diagnostics in
            XCTAssertEqual(diagnostics.count, 1)
            XCTAssertEqual(diagnostics[0].code, "CID0419")
            XCTAssertEqual(diagnostics[0].location?.line, 5)
            XCTAssertTrue(diagnostics[0].summary.contains("icon"))
        }
    }

    func testEveryProblemIsReportedAtOnce() {
        // A developer fixing a manifest should not have to run the command once
        // per mistake.
        let text = """
            app:
              id: NotAnAppID
              name: Hello Cider
              entry: 9Invalid
            runtime:
              minimumCompatibility: nonsense
              device: phone-enormous
            permissions:
              network: yes
            """

        assertDiagnostics(parsing: text) { diagnostics in
            let codes = Set(diagnostics.map(\.code))
            XCTAssertTrue(codes.contains("CID0412"), "invalid app id")
            XCTAssertTrue(codes.contains("CID0413"), "invalid entry type name")
            XCTAssertTrue(codes.contains("CID0414"), "invalid compatibility version")
            XCTAssertTrue(codes.contains("CID0415"), "unknown device profile")
            XCTAssertTrue(codes.contains("CID0418"), "`yes` is not a boolean")
        }
    }

    func testMissingAppSectionIsExplained() {
        assertDiagnostics(parsing: "runtime:\n  device: phone-standard") { diagnostics in
            XCTAssertEqual(diagnostics.first?.code, "CID0411")
            XCTAssertNotNil(diagnostics.first?.remedy, "the diagnostic must show what to add")
        }
    }

    func testMissingRequiredFieldNamesTheField() {
        assertDiagnostics(parsing: "app:\n  id: dev.cider.hello") { diagnostics in
            let summaries = diagnostics.map(\.summary)
            XCTAssertTrue(summaries.contains { $0.contains("app.name") })
            XCTAssertTrue(summaries.contains { $0.contains("app.entry") })
        }
    }

    // MARK: - Diagnostics from the YAML subset itself

    func testTabIndentationIsRejected() {
        assertThrowsDiagnostic(parsing: "app:\n\tid: dev.cider.hello", code: "CID0401", line: 2)
    }

    func testOddIndentationIsRejected() {
        assertThrowsDiagnostic(parsing: "app:\n   id: dev.cider.hello", code: "CID0402", line: 2)
    }

    func testSequencesAreRejected() {
        assertThrowsDiagnostic(parsing: "app:\n  - id: dev.cider.hello", code: "CID0403", line: 2)
    }

    func testLineWithoutColonIsRejected() {
        assertThrowsDiagnostic(parsing: "app\n", code: "CID0404", line: 1)
    }

    func testValueAndBlockTogetherIsRejected() {
        assertThrowsDiagnostic(
            parsing: "app: something\n  id: dev.cider.hello",
            code: "CID0407",
            line: 1
        )
    }

    // MARK: - Validation predicates

    func testAppIDValidation() {
        XCTAssertTrue(ManifestParser.isValidAppID("dev.cider.hello"))
        XCTAssertTrue(ManifestParser.isValidAppID("com.example.my-app"))
        XCTAssertFalse(ManifestParser.isValidAppID("hello"), "needs at least two segments")
        XCTAssertFalse(ManifestParser.isValidAppID("dev..hello"), "no empty segment")
        XCTAssertFalse(ManifestParser.isValidAppID("9dev.hello"), "segments start with a letter")
        XCTAssertFalse(ManifestParser.isValidAppID("dev.hello-"), "no trailing hyphen")
    }

    func testSwiftTypeNameValidation() {
        XCTAssertTrue(ManifestParser.isValidSwiftTypeName("HelloCiderApp"))
        XCTAssertTrue(ManifestParser.isValidSwiftTypeName("_Private"))
        XCTAssertFalse(ManifestParser.isValidSwiftTypeName("9Lives"))
        XCTAssertFalse(ManifestParser.isValidSwiftTypeName("Has Space"))
    }

    func testCompatibilityVersionValidation() {
        XCTAssertTrue(ManifestParser.isValidCompatibilityVersion("0.1"))
        XCTAssertTrue(ManifestParser.isValidCompatibilityVersion("12.34"))
        XCTAssertFalse(ManifestParser.isValidCompatibilityVersion("0"))
        XCTAssertFalse(ManifestParser.isValidCompatibilityVersion("0.1.2"))
        XCTAssertFalse(ManifestParser.isValidCompatibilityVersion("v0.1"))
    }

    // MARK: - Helpers

    private func assertDiagnostics(
        parsing text: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ check: ([Diagnostic]) -> Void
    ) {
        do {
            _ = try ManifestParser.parse(text, file: "Cider.yaml")
            XCTFail("expected the manifest to be rejected", file: file, line: line)
        } catch let bundle as DiagnosticBundle {
            check(bundle.diagnostics)
        } catch let diagnostic as Diagnostic {
            check([diagnostic])
        } catch {
            XCTFail("unexpected error: \(error)", file: file, line: line)
        }
    }

    private func assertThrowsDiagnostic(
        parsing text: String,
        code: String,
        line expectedLine: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertDiagnostics(parsing: text, file: file, line: line) { diagnostics in
            XCTAssertEqual(diagnostics.first?.code, code, file: file, line: line)
            XCTAssertEqual(diagnostics.first?.location?.line, expectedLine, file: file, line: line)
        }
    }
}
