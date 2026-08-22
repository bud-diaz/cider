//  Integration tests for pointer-to-touch translation.
//
//  This conversion is one line of arithmetic and exactly the kind of thing that
//  is silently wrong for months: every tap lands slightly off, and nobody
//  measures it because the button is big enough to hit anyway.

import XCTest

import CiderCore
import CiderHost

@testable import CiderRuntime

final class PointerTranslationTests: XCTestCase {

    func testUnscaledUnletterboxedIsIdentity() {
        let translator = PointerTranslator(
            scale: 1,
            surfacePixelWidth: 390, surfacePixelHeight: 844,
            windowPixelWidth: 390, windowPixelHeight: 844
        )
        XCTAssertEqual(translator.convert(Point(x: 100, y: 200)), Point(x: 100, y: 200))
    }

    func testScaleDividesDevicePixelsIntoPoints() {
        let translator = PointerTranslator(
            scale: 2,
            surfacePixelWidth: 780, surfacePixelHeight: 1688,
            windowPixelWidth: 780, windowPixelHeight: 1688
        )
        XCTAssertEqual(translator.convert(Point(x: 200, y: 400)), Point(x: 100, y: 200))
    }

    func testLetterboxOffsetIsRemoved() {
        // The framebuffer is centred in a larger window, so a click at the
        // window's top-left is *outside* the device's screen.
        let translator = PointerTranslator(
            scale: 1,
            surfacePixelWidth: 390, surfacePixelHeight: 844,
            windowPixelWidth: 590, windowPixelHeight: 944
        )

        XCTAssertEqual(translator.convert(Point(x: 100, y: 50)), Point(x: 0, y: 0))
        XCTAssertEqual(translator.convert(Point(x: 0, y: 0)), Point(x: -100, y: -50))
    }

    func testPrimaryButtonBecomesATouch() {
        let translator = PointerTranslator(
            scale: 1,
            surfacePixelWidth: 100, surfacePixelHeight: 100,
            windowPixelWidth: 100, windowPixelHeight: 100
        )

        let down = translator.touch(for: .pointerDown(location: Point(x: 10, y: 20), button: .primary))
        XCTAssertEqual(down?.phase, .began)
        XCTAssertEqual(down?.location, Point(x: 10, y: 20))

        let up = translator.touch(for: .pointerUp(location: Point(x: 10, y: 20), button: .primary))
        XCTAssertEqual(up?.phase, .ended)
    }

    func testSecondaryButtonIsNotATouch() {
        let translator = PointerTranslator(
            scale: 1,
            surfacePixelWidth: 100, surfacePixelHeight: 100,
            windowPixelWidth: 100, windowPixelHeight: 100
        )
        XCTAssertNil(translator.touch(for: .pointerDown(location: .zero, button: .secondary)))
        XCTAssertNil(translator.touch(for: .pointerUp(location: .zero, button: .other(8))))
    }

    func testExitCancels() {
        let translator = PointerTranslator(
            scale: 1,
            surfacePixelWidth: 100, surfacePixelHeight: 100,
            windowPixelWidth: 100, windowPixelHeight: 100
        )
        XCTAssertEqual(translator.touch(for: .pointerExit)?.phase, .cancelled)
    }

    func testNonPointerEventsCarryNoTouch() {
        let translator = PointerTranslator(
            scale: 1,
            surfacePixelWidth: 100, surfacePixelHeight: 100,
            windowPixelWidth: 100, windowPixelHeight: 100
        )
        XCTAssertNil(translator.touch(for: .redrawRequested))
        XCTAssertNil(translator.touch(for: .closeRequested))
        XCTAssertNil(translator.touch(for: .resized(width: 10, height: 10)))
        XCTAssertNil(translator.touch(for: .scroll(deltaX: 0, deltaY: 1)))
        XCTAssertNil(translator.touch(for: .keyDown(keyCode: 65)))
        XCTAssertNil(translator.touch(for: .keyUp(keyCode: 65)))
        XCTAssertNil(translator.touch(for: .textInput("a")))
    }
}
