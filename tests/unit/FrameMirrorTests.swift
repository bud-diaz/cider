//  Unit tests for the frame-mirror wire format.
//
//  The reader is JavaScript in the dev dashboard, which nothing here can
//  compile. These tests are therefore the only place the header layout and the
//  channel order are pinned, so they assert bytes rather than round-tripping
//  through a decoder that does not exist.

import XCTest

@testable import CiderCore

final class FrameMirrorTests: XCTestCase {

    private func littleEndian(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        let values = Array(bytes)
        return UInt32(values[0])
            | UInt32(values[1]) << 8
            | UInt32(values[2]) << 16
            | UInt32(values[3]) << 24
    }

    func testHeaderCarriesMagicVersionAndBothSizes() {
        let canvas = Canvas(width: 3, height: 2)
        let bytes = FrameMirror.encode(canvas, logicalWidth: 390, logicalHeight: 844)

        XCTAssertEqual(Array(bytes[0..<4]), Array("CIDR".utf8))
        XCTAssertEqual(littleEndian(bytes[4..<8]), FrameMirror.currentVersion)
        XCTAssertEqual(littleEndian(bytes[8..<12]), 3, "pixel width")
        XCTAssertEqual(littleEndian(bytes[12..<16]), 2, "pixel height")
        XCTAssertEqual(littleEndian(bytes[16..<20]), 390, "logical width")
        XCTAssertEqual(littleEndian(bytes[20..<24]), 844, "logical height")
        XCTAssertEqual(bytes.count, FrameMirror.headerLength + 3 * 2 * 4)
    }

    /// `Canvas` stores 0xAARRGGBB words; the mirror must emit R, G, B, A so the
    /// browser can hand the buffer to `ImageData` untouched. Getting this
    /// backwards swaps red and blue in the dashboard and nothing else fails.
    func testPixelsAreWrittenAsStraightAlphaRGBA() {
        let canvas = Canvas(width: 1, height: 1, fill: Color(hex: 0x8040C0))
        let bytes = FrameMirror.encode(canvas, logicalWidth: 1, logicalHeight: 1)

        let pixel = Array(bytes[FrameMirror.headerLength...])
        XCTAssertEqual(pixel, [0x80, 0x40, 0xC0, 0xFF])
    }

    func testEmptyCanvasStillProducesAReadableHeader() {
        let canvas = Canvas(width: 0, height: 0)
        let bytes = FrameMirror.encode(canvas, logicalWidth: 0, logicalHeight: 0)
        XCTAssertEqual(bytes.count, FrameMirror.headerLength)
    }
}
