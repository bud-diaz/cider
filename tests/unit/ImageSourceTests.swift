//  Unit tests for `ImageSource`.

import XCTest

@testable import CiderCore

final class ImageSourceTests: XCTestCase {

    func testSolidFillsEveryPixelWithTheGivenColor() {
        let source = ImageSource.solid(Color(hex: 0x336699, alpha: 0.5), width: 2, height: 2)

        XCTAssertEqual(source.width, 2)
        XCTAssertEqual(source.height, 2)
        XCTAssertEqual(source.pixels.count, 2 * 2 * 4)

        for pixel in stride(from: 0, to: source.pixels.count, by: 4) {
            XCTAssertEqual(source.pixels[pixel], 0x33)
            XCTAssertEqual(source.pixels[pixel + 1], 0x66)
            XCTAssertEqual(source.pixels[pixel + 2], 0x99)
            XCTAssertEqual(source.pixels[pixel + 3], 128)
        }
    }

    func testEquatableComparesPixelContent() {
        let a = ImageSource.solid(.black, width: 1, height: 1)
        let b = ImageSource.solid(.black, width: 1, height: 1)
        let c = ImageSource.solid(.white, width: 1, height: 1)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
