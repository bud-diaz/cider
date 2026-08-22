//  Unit tests for the geometry primitives layout and hit testing are built on.

import XCTest

@testable import CiderCore

final class GeometryTests: XCTestCase {

    func testSizeClampsNegativeExtents() {
        // A negative extent has no meaning in a layout tree, and letting one
        // through turns into an inverted rectangle several layers later.
        let size = Size(width: -10, height: -1)
        XCTAssertEqual(size.width, 0)
        XCTAssertEqual(size.height, 0)
    }

    func testContainsIsHalfOpen() {
        let rect = Rect(x: 10, y: 10, width: 100, height: 50)

        XCTAssertTrue(rect.contains(Point(x: 10, y: 10)), "the min corner is inside")
        XCTAssertTrue(rect.contains(Point(x: 109.9, y: 59.9)))

        // Half-open containment is what stops two adjacent controls from both
        // claiming a pointer event on their shared edge.
        XCTAssertFalse(rect.contains(Point(x: 110, y: 30)), "the max edge is outside")
        XCTAssertFalse(rect.contains(Point(x: 60, y: 60)))
        XCTAssertFalse(rect.contains(Point(x: 9.9, y: 30)))
    }

    func testAdjacentRectsDoNotBothContainTheirSharedEdge() {
        let left = Rect(x: 0, y: 0, width: 50, height: 20)
        let right = Rect(x: 50, y: 0, width: 50, height: 20)
        let onTheSeam = Point(x: 50, y: 10)

        XCTAssertFalse(left.contains(onTheSeam))
        XCTAssertTrue(right.contains(onTheSeam))
    }

    func testInsetBySafeArea() {
        let bounds = Rect(x: 0, y: 0, width: 390, height: 844)
        let inset = bounds.inset(by: EdgeInsets(top: 47, left: 0, bottom: 34, right: 0))

        XCTAssertEqual(inset.minY, 47)
        XCTAssertEqual(inset.height, 844 - 47 - 34)
        XCTAssertEqual(inset.width, 390)
    }

    func testEdgeInsetSums() {
        let insets = EdgeInsets(horizontal: 24, vertical: 12)
        XCTAssertEqual(insets.horizontal, 48)
        XCTAssertEqual(insets.vertical, 24)
    }
}

final class ColorTests: XCTestCase {

    func testHexInitialisation() {
        let color = Color(hex: 0x1F6FEB)
        XCTAssertEqual(color.red, Double(0x1F) / 255.0, accuracy: 1e-9)
        XCTAssertEqual(color.green, Double(0x6F) / 255.0, accuracy: 1e-9)
        XCTAssertEqual(color.blue, Double(0xEB) / 255.0, accuracy: 1e-9)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testPackedLayoutIsARGB() {
        XCTAssertEqual(Color(hex: 0xFF0000).packed, 0xFFFF0000)
        XCTAssertEqual(Color(hex: 0x00FF00).packed, 0xFF00FF00)
        XCTAssertEqual(Color(hex: 0x0000FF).packed, 0xFF0000FF)
        XCTAssertEqual(Color.clear.packed, 0x00000000)
    }

    func testComponentsAreClamped() {
        let color = Color(red: 2, green: -1, blue: 0.5, alpha: 10)
        XCTAssertEqual(color.red, 1)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.alpha, 1)
    }
}

final class CanvasTests: XCTestCase {

    func testOpaqueBlendReplaces() {
        var canvas = Canvas(width: 2, height: 2, fill: .black)
        canvas.blend(x: 0, y: 0, color: Color(hex: 0xFF0000))
        XCTAssertEqual(canvas.pixel(x: 0, y: 0), 0xFFFF0000)
        XCTAssertEqual(canvas.pixel(x: 1, y: 1), 0xFF000000)
    }

    func testHalfCoverageBlendsHalfway() {
        var canvas = Canvas(width: 1, height: 1, fill: .black)
        canvas.blend(x: 0, y: 0, color: .white, coverage: 0.5)

        let pixel = canvas.pixel(x: 0, y: 0)
        let red = (pixel >> 16) & 0xFF
        XCTAssertEqual(Int(red), 128, accuracy: 1, "half coverage of white over black is mid grey")
    }

    func testOutOfBoundsBlendIsDropped() {
        // A clip that is off by a pixel should show up as a visual bug a
        // baseline catches, not as a crash in a developer's application.
        var canvas = Canvas(width: 2, height: 2, fill: .black)
        canvas.blend(x: -1, y: 0, color: .white)
        canvas.blend(x: 5, y: 5, color: .white)
        XCTAssertEqual(canvas.pixels, [UInt32](repeating: 0xFF000000, count: 4))
    }

    func testZeroCoverageLeavesPixelUntouched() {
        var canvas = Canvas(width: 1, height: 1, fill: .white)
        canvas.blend(x: 0, y: 0, color: .black, coverage: 0)
        XCTAssertEqual(canvas.pixel(x: 0, y: 0), Color.white.packed)
    }
}
