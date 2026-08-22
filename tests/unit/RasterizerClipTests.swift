//  Unit tests for the rasterizer's clip stack (`RenderCommand.pushClip`/`.popClip`).
//
//  These assert on individual pixels rather than a recorded baseline, so they
//  don't need CIDER_UPDATE_BASELINES=1 or a checked-in .ppm to be meaningful --
//  a clip rect's effect is exact and small enough to state directly.

import XCTest

@testable import CiderCore
@testable import CiderUITree

final class RasterizerClipTests: XCTestCase {

    private func render(_ commands: [RenderCommand], size: Int = 10) -> Canvas {
        Rasterizer.render(
            RenderTree(backgroundColor: .white, commands: commands),
            pixelWidth: size,
            pixelHeight: size,
            scale: 1,
            textEngine: FailingTextEngine()
        )
    }

    func testFillIsConfinedToThePushedClipRect() {
        let canvas = render([
            .pushClip(rect: Rect(x: 2, y: 2, width: 4, height: 4)),
            .fillRect(rect: Rect(x: 0, y: 0, width: 10, height: 10), color: .black, cornerRadius: 0),
            .popClip,
        ])

        // Inside the clip: black.
        XCTAssertEqual(canvas.pixel(x: 3, y: 3), Color.black.packed)
        XCTAssertEqual(canvas.pixel(x: 5, y: 5), Color.black.packed)

        // Outside the clip, including its half-open far edge: untouched white.
        XCTAssertEqual(canvas.pixel(x: 0, y: 0), Color.white.packed)
        XCTAssertEqual(canvas.pixel(x: 9, y: 9), Color.white.packed)
        XCTAssertEqual(canvas.pixel(x: 6, y: 3), Color.white.packed, "the far edge of the clip is exclusive")
        XCTAssertEqual(canvas.pixel(x: 1, y: 3), Color.white.packed)
    }

    func testPopClipRestoresWhatWasActiveBefore() {
        let canvas = render([
            .pushClip(rect: Rect(x: 2, y: 2, width: 4, height: 4)),
            .popClip,
            .fillRect(rect: Rect(x: 8, y: 8, width: 1, height: 1), color: .black, cornerRadius: 0),
        ])

        // Drawn well outside the popped clip: proves the pop actually restored
        // the full canvas rather than leaving the old clip stuck.
        XCTAssertEqual(canvas.pixel(x: 8, y: 8), Color.black.packed)
    }

    func testNestedClipsIntersect() {
        let canvas = render([
            .pushClip(rect: Rect(x: 0, y: 0, width: 6, height: 10)),
            .pushClip(rect: Rect(x: 4, y: 0, width: 6, height: 10)),
            .fillRect(rect: Rect(x: 0, y: 0, width: 10, height: 10), color: .black, cornerRadius: 0),
            .popClip,
            .popClip,
        ])

        // Only the 4..<6 overlap of the two pushed rects should be filled.
        XCTAssertEqual(canvas.pixel(x: 5, y: 5), Color.black.packed)
        XCTAssertEqual(canvas.pixel(x: 3, y: 5), Color.white.packed, "inside the first clip, outside the second")
        XCTAssertEqual(canvas.pixel(x: 7, y: 5), Color.white.packed, "outside the first clip, inside the second")
    }

    func testAnUnbalancedPopClipDoesNotRemoveTheBaseClip() {
        // More pops than pushes is a builder bug. The rasterizer must not
        // crash or clip away the whole canvas in response to it.
        let canvas = render([
            .popClip,
            .popClip,
            .fillRect(rect: Rect(x: 0, y: 0, width: 10, height: 10), color: .black, cornerRadius: 0),
        ])
        XCTAssertEqual(canvas.pixel(x: 0, y: 0), Color.black.packed)
        XCTAssertEqual(canvas.pixel(x: 9, y: 9), Color.black.packed)
    }

    func testNonOverlappingNestedClipFillsNothing() {
        let canvas = render([
            .pushClip(rect: Rect(x: 0, y: 0, width: 2, height: 2)),
            .pushClip(rect: Rect(x: 8, y: 8, width: 2, height: 2)),
            .fillRect(rect: Rect(x: 0, y: 0, width: 10, height: 10), color: .black, cornerRadius: 0),
            .popClip,
            .popClip,
        ])

        for x in 0..<10 {
            for y in 0..<10 {
                XCTAssertEqual(canvas.pixel(x: x, y: y), Color.white.packed, "(\(x), \(y)) should be untouched")
            }
        }
    }
}

/// A text engine that fails any test relying on it, so a clip test that
/// accidentally exercises text shaping fails loudly instead of silently
/// depending on font metrics it never asked for.
private final class FailingTextEngine: TextEngine {
    let scale: Double = 1

    func metrics(for font: FontRequest) -> FontMetrics {
        XCTFail("this test should not shape text")
        return FontMetrics(ascent: 0, descent: 0, lineHeight: 0)
    }

    func shape(_ text: String, font: FontRequest) -> ShapedRun {
        XCTFail("this test should not shape text")
        return ShapedRun(glyphs: [], width: 0, metrics: FontMetrics(ascent: 0, descent: 0, lineHeight: 0))
    }

    func image(forGlyph glyphID: UInt32, font: FontRequest) -> GlyphImage? {
        XCTFail("this test should not rasterize glyphs")
        return nil
    }
}
