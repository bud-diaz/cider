//  Unit tests for the CLI-to-runtime wire format.

import XCTest

@testable import CiderCore

final class LaunchDescriptorTests: XCTestCase {

    private var sample: LaunchDescriptor {
        LaunchDescriptor(
            appID: "dev.cider.hello",
            appName: "Hello Cider",
            appEntry: "HelloCiderApp",
            minimumCompatibility: "0.1",
            deviceProfileName: "phone-standard",
            permissions: AppPermissions(network: false, localStorage: true),
            logLevel: .debug,
            inspectorEnabled: true
        )
    }

    func testRoundTrip() throws {
        let decoded = try LaunchDescriptor.decode(sample.encoded())
        XCTAssertEqual(decoded, sample)
    }

    func testCommentsAndBlankLinesAreIgnored() throws {
        let text = """
            # written by cider

            descriptor-version = 1
            app.id = dev.cider.hello
            app.name = Hello Cider
            app.entry = HelloCiderApp
            runtime.minimum-compatibility = 0.1
            device.name = phone-standard
            """
        let decoded = try LaunchDescriptor.decode(text)
        XCTAssertEqual(decoded.appID, "dev.cider.hello")
        XCTAssertEqual(decoded.permissions, .none, "absent permissions are denied")
        XCTAssertEqual(decoded.logLevel, .info, "absent log level defaults to info")
    }

    func testAppNameMayContainSpacesAndEquals() throws {
        // Only the first `=` separates key from value, so a value may contain one.
        let decoded = try LaunchDescriptor.decode(
            """
            descriptor-version = 1
            app.id = dev.cider.hello
            app.name = Hello = Cider
            app.entry = HelloCiderApp
            runtime.minimum-compatibility = 0.1
            device.name = phone-standard
            """
        )
        XCTAssertEqual(decoded.appName, "Hello = Cider")
    }

    func testFutureVersionIsRefused() {
        // Guessing at a descriptor written by a newer toolchain would mean
        // launching with settings that mean something else.
        let text = sample.encoded().replacingOccurrences(
            of: "descriptor-version = 1",
            with: "descriptor-version = 99"
        )
        XCTAssertThrowsError(try LaunchDescriptor.decode(text)) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0303")
        }
    }

    func testMissingFieldNamesTheField() {
        let text = """
            descriptor-version = 1
            app.id = dev.cider.hello
            """
        XCTAssertThrowsError(try LaunchDescriptor.decode(text)) { error in
            let diagnostic = error as? Diagnostic
            XCTAssertEqual(diagnostic?.code, "CID0302")
            XCTAssertTrue(diagnostic?.summary.contains("app.name") ?? false)
        }
    }

    func testMalformedLineReportsItsNumber() {
        let text = """
            descriptor-version = 1
            this line has no separator
            """
        XCTAssertThrowsError(try LaunchDescriptor.decode(text)) { error in
            let diagnostic = error as? Diagnostic
            XCTAssertEqual(diagnostic?.code, "CID0301")
            XCTAssertEqual(diagnostic?.location?.line, 2)
        }
    }
}

final class LogLevelTests: XCTestCase {

    func testParsing() {
        XCTAssertEqual(LogLevel(name: "trace"), .trace)
        XCTAssertEqual(LogLevel(name: "WARNING"), .warning)
        XCTAssertEqual(LogLevel(name: "warn"), .warning)
        XCTAssertNil(LogLevel(name: "verbose"))
    }

    func testOrdering() {
        XCTAssertTrue(LogLevel.trace < LogLevel.error)
        XCTAssertTrue(LogLevel.warning > LogLevel.info)
    }

    func testChannelsAreDistinguishable() {
        // docs/02-product-requirements.md: developer output must stay separable
        // from Cider's own.
        let runtime = LogRecord(level: .info, channel: .runtime, message: "application started")
        let application = LogRecord(level: .info, channel: .application, message: "hello")

        XCTAssertEqual(runtime.formatted(), "[cider] application started")
        XCTAssertEqual(application.formatted(), "[app] hello")
    }

    func testNonInfoLevelsAreTagged() {
        let record = LogRecord(level: .warning, channel: .runtime, message: "slow frame")
        XCTAssertEqual(record.formatted(), "[cider] warning: slow frame")
    }

    func testLoggerRespectsMinimumLevel() {
        let sink = MemoryLogSink()
        let logger = Logger(sink: sink, channel: .runtime, minimumLevel: .warning)

        logger.debug("invisible")
        logger.warning("visible")
        logger.error("also visible")

        XCTAssertEqual(sink.messages(), ["visible", "also visible"])
    }

    func testScopedLoggerKeepsTheSink() {
        let sink = MemoryLogSink()
        let runtime = Logger(sink: sink, channel: .runtime, minimumLevel: .info)
        runtime.info("from cider")
        runtime.scoped(to: .application).info("from the app")

        XCTAssertEqual(sink.records.map(\.channel), [.runtime, .application])
    }
}

final class DiagnosticFormattingTests: XCTestCase {

    func testFormattedDiagnosticAnswersAllFourQuestions() {
        let diagnostic = Diagnostic(
            code: "CID0501",
            summary: "Swift compiler not found",
            location: DiagnosticLocation(file: "Cider.yaml", line: 3),
            reason: "Cider requires Swift 6.0 or later.",
            remedy: "Install Swift and verify:\n\n    swift --version"
        )

        let text = diagnostic.formatted()
        XCTAssertTrue(text.contains("Swift compiler not found"), "what failed")
        XCTAssertTrue(text.contains("Cider.yaml:3"), "where it failed")
        XCTAssertTrue(text.contains("requires Swift 6.0"), "why it failed")
        XCTAssertTrue(text.contains("swift --version"), "how to fix it")
        XCTAssertTrue(text.contains("CID0501"), "a stable code to search for")
    }
}
