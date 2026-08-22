//  Unit tests for log redaction.
//
//  docs/03-technical-architecture.md section 8 asks for sanitized logs. These
//  tests pin down what gets redacted and, just as important, what does not:
//  a filter that mangles ordinary log lines is one a developer disables.

import XCTest

@testable import CiderCore

final class LogRedactionTests: XCTestCase {

    func testRedactsAnEqualsSeparatedPassword() {
        XCTAssertEqual(
            LogRedaction.redact("login attempt password=hunter2 for user=alice"),
            "login attempt password=[redacted] for user=alice"
        )
    }

    func testRedactsAColonSeparatedToken() {
        XCTAssertEqual(
            LogRedaction.redact("request headers: token: abc123def"),
            "request headers: token: [redacted]"
        )
    }

    func testRedactsCaseInsensitively() {
        XCTAssertEqual(
            LogRedaction.redact("Authorization=Bearer-xyz"),
            "Authorization=[redacted]"
        )
    }

    func testRedactsTheTokenAfterBearer() {
        XCTAssertEqual(
            LogRedaction.redact("sending request with header Bearer abc.def.ghi"),
            "sending request with header Bearer [redacted]"
        )
    }

    func testOrdinaryMessagesAreUnaffected() {
        let message = "launching dev.cider.hello device: phone-standard"
        XCTAssertEqual(LogRedaction.redact(message), message)
    }

    func testAKeyWithNoValueIsLeftAlone() {
        let message = "password="
        XCTAssertEqual(LogRedaction.redact(message), message)
    }

    func testRedactingLogSinkRedactsBeforeForwarding() {
        let sink = MemoryLogSink()
        let redacting = RedactingLogSink(wrapping: sink)

        redacting.write(LogRecord(level: .info, channel: .application, message: "password=hunter2"))

        XCTAssertEqual(sink.messages(), ["password=[redacted]"])
    }
}
