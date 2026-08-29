//  Serialising a presented frame for the local developer console.
//
//  The `cider dev` editor shows the running application in a browser, which
//  means the frame has to leave the process. Cider has no image codec and does
//  not want one -- tests/visual/PPM.swift records that decision and the reason:
//  a header and raw bytes are shorter than the argument for adding zlib.
//
//  PPM itself is no use here, because no browser can display it. But a browser
//  does not need an encoded image at all: `putImageData` takes raw RGBA. So the
//  wire format is the same shape as PPM -- a tiny header, then bytes -- chosen
//  for the same reason.
//
//  Byte order is fixed at RGBA here rather than in the reader. `Canvas` stores
//  0xAARRGGBB words, which on a little-endian host is B, G, R, A in memory; the
//  swizzle costs one pass on the writer's side, and doing it here means the
//  browser can hand the buffer straight to `ImageData` with no per-pixel work
//  in JavaScript.

public enum FrameMirror {

    /// `CIDR`, so a stray file is identifiable by `file(1)` and by eye.
    public static let magic: [UInt8] = [0x43, 0x49, 0x44, 0x52]

    /// Bumped whenever the header or the pixel layout changes. A reader that
    /// does not recognise the version draws nothing rather than guessing.
    public static let currentVersion: UInt32 = 1

    /// Bytes before the first pixel: magic, version, pixel width, pixel
    /// height, logical width, logical height.
    ///
    /// Both sizes travel because the reader needs both and can derive neither.
    /// Pixels size the image; the logical points size the coordinate space that
    /// inspector node frames are expressed in, so a reader drawing selection
    /// boxes over the frame needs the ratio between them.
    public static let headerLength = 24

    /// Serialises a canvas as a header followed by straight-alpha RGBA8.
    ///
    /// Returns `[UInt8]` rather than `Data` so that `CiderCore` keeps its
    /// current property of importing no Foundation.
    public static func encode(_ canvas: Canvas, logicalWidth: Int, logicalHeight: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(headerLength + canvas.pixels.count * 4)

        bytes.append(contentsOf: magic)
        appendLittleEndian(currentVersion, to: &bytes)
        appendLittleEndian(UInt32(canvas.width), to: &bytes)
        appendLittleEndian(UInt32(canvas.height), to: &bytes)
        appendLittleEndian(UInt32(max(0, logicalWidth)), to: &bytes)
        appendLittleEndian(UInt32(max(0, logicalHeight)), to: &bytes)

        for pixel in canvas.pixels {
            bytes.append(UInt8((pixel >> 16) & 0xFF))  // R
            bytes.append(UInt8((pixel >> 8) & 0xFF))   // G
            bytes.append(UInt8(pixel & 0xFF))          // B
            bytes.append(UInt8((pixel >> 24) & 0xFF))  // A
        }
        return bytes
    }

    private static func appendLittleEndian(_ value: UInt32, to bytes: inout [UInt8]) {
        bytes.append(UInt8(value & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8((value >> 16) & 0xFF))
        bytes.append(UInt8((value >> 24) & 0xFF))
    }
}
