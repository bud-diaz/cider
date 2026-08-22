//  Reading and writing the baseline image format.
//
//  Binary PPM (P6) rather than PNG. Cider has no image codec and does not want a
//  dependency for one; PPM is a header and raw bytes, so the reader and writer
//  together are shorter than the argument for adding zlib. Baselines are small
//  because the scenes are deliberately small.

import Foundation

import CiderCore

enum PPM {

    /// Serialises a canvas as binary PPM. The alpha channel is dropped: a
    /// presented frame is opaque, and carrying alpha into a baseline would
    /// record a value no one can see.
    static func encode(_ canvas: Canvas) -> Data {
        var data = Data("P6\n\(canvas.width) \(canvas.height)\n255\n".utf8)
        data.reserveCapacity(data.count + canvas.width * canvas.height * 3)

        for pixel in canvas.pixels {
            data.append(UInt8((pixel >> 16) & 0xFF))
            data.append(UInt8((pixel >> 8) & 0xFF))
            data.append(UInt8(pixel & 0xFF))
        }
        return data
    }

    struct Image: Equatable {
        var width: Int
        var height: Int
        /// Three bytes per pixel, row-major.
        var rgb: [UInt8]
    }

    static func decode(_ data: Data) throws -> Image {
        let bytes = [UInt8](data)
        var index = 0

        func token() throws -> String {
            while index < bytes.count, bytes[index] == 0x20 || bytes[index] == 0x0A
                || bytes[index] == 0x0D || bytes[index] == 0x09 {
                index += 1
            }
            let start = index
            while index < bytes.count, !(bytes[index] == 0x20 || bytes[index] == 0x0A
                || bytes[index] == 0x0D || bytes[index] == 0x09) {
                index += 1
            }
            guard start < index else { throw PPMError.truncatedHeader }
            return String(decoding: bytes[start..<index], as: UTF8.self)
        }

        guard try token() == "P6" else { throw PPMError.notBinaryPPM }
        guard let width = Int(try token()), let height = Int(try token()),
              let maximum = Int(try token()), maximum == 255 else {
            throw PPMError.unsupportedHeader
        }
        // Exactly one whitespace byte separates the header from the pixel data.
        index += 1

        let expected = width * height * 3
        guard bytes.count - index == expected else {
            throw PPMError.wrongPixelCount(expected: expected, found: bytes.count - index)
        }
        return Image(width: width, height: height, rgb: Array(bytes[index...]))
    }

    static func image(from canvas: Canvas) -> Image {
        var rgb = [UInt8]()
        rgb.reserveCapacity(canvas.width * canvas.height * 3)
        for pixel in canvas.pixels {
            rgb.append(UInt8((pixel >> 16) & 0xFF))
            rgb.append(UInt8((pixel >> 8) & 0xFF))
            rgb.append(UInt8(pixel & 0xFF))
        }
        return Image(width: canvas.width, height: canvas.height, rgb: rgb)
    }

    enum PPMError: Error, CustomStringConvertible {
        case truncatedHeader
        case notBinaryPPM
        case unsupportedHeader
        case wrongPixelCount(expected: Int, found: Int)

        var description: String {
            switch self {
            case .truncatedHeader: return "the PPM header ended early"
            case .notBinaryPPM: return "the file is not a binary (P6) PPM"
            case .unsupportedHeader: return "unsupported PPM header; Cider writes 8-bit P6"
            case .wrongPixelCount(let expected, let found):
                return "expected \(expected) bytes of pixel data, found \(found)"
            }
        }
    }
}

/// The result of comparing a render against a baseline.
struct ImageComparison {
    var differingPixels: Int
    var maximumChannelDelta: Int
    var totalPixels: Int

    var matches: Bool { differingPixels == 0 }

    var summary: String {
        "\(differingPixels)/\(totalPixels) pixels differ, largest channel delta \(maximumChannelDelta)"
    }

    static func compare(_ rendered: PPM.Image, _ baseline: PPM.Image) -> ImageComparison? {
        guard rendered.width == baseline.width, rendered.height == baseline.height else {
            return nil
        }

        var differing = 0
        var maximum = 0
        for pixel in 0..<(rendered.width * rendered.height) {
            var different = false
            for channel in 0..<3 {
                let index = pixel * 3 + channel
                let delta = abs(Int(rendered.rgb[index]) - Int(baseline.rgb[index]))
                if delta > 0 {
                    different = true
                    maximum = max(maximum, delta)
                }
            }
            if different { differing += 1 }
        }

        return ImageComparison(
            differingPixels: differing,
            maximumChannelDelta: maximum,
            totalPixels: rendered.width * rendered.height
        )
    }
}
