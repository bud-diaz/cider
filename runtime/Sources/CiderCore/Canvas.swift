//  The software framebuffer every backend presents.

/// A 32-bit ARGB framebuffer in *physical pixels*.
///
/// Cider rasterizes in shared code and asks the platform only to put the
/// resulting pixels on screen. That choice is what keeps the renderer
/// deterministic across hosts, which the visual-regression strategy in
/// docs/06-testing-strategy.md depends on.
///
/// Word layout is `0xAARRGGBB`. On the little-endian platforms Cider supports
/// this is byte-order B, G, R, A in memory, which matches an X11 24/32-bit
/// TrueColor visual and a Win32 top-down `BITMAPINFO` without a conversion pass.
public struct Canvas: Sendable {
    public let width: Int
    public let height: Int

    /// Row-major, `width * height` words, no padding between rows.
    public private(set) var pixels: [UInt32]

    public init(width: Int, height: Int, fill: Color = .black) {
        self.width = max(0, width)
        self.height = max(0, height)
        self.pixels = [UInt32](repeating: fill.packed, count: self.width * self.height)
    }

    public mutating func clear(to color: Color) {
        let packed = color.packed
        for index in pixels.indices { pixels[index] = packed }
    }

    public func pixel(x: Int, y: Int) -> UInt32 {
        precondition(x >= 0 && x < width && y >= 0 && y < height, "pixel out of bounds")
        return pixels[y * width + x]
    }

    /// Composites a straight-alpha colour over the pixel at (x, y).
    ///
    /// Out-of-bounds writes are dropped rather than trapped: the rasterizer
    /// clips before calling, but a clip that is off by a pixel should produce a
    /// visual bug that a baseline test catches, not a crash in a user's app.
    public mutating func blend(x: Int, y: Int, color: Color, coverage: Double = 1.0) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let alpha = color.alpha * min(1, max(0, coverage))
        guard alpha > 0 else { return }

        let index = y * width + x
        if alpha >= 1.0 {
            pixels[index] = color.packed
            return
        }

        let destination = pixels[index]
        let dr = Double((destination >> 16) & 0xFF) / 255.0
        let dg = Double((destination >> 8) & 0xFF) / 255.0
        let db = Double(destination & 0xFF) / 255.0
        let da = Double((destination >> 24) & 0xFF) / 255.0

        // Standard "source over" in straight alpha.
        let outA = alpha + da * (1 - alpha)
        guard outA > 0 else {
            pixels[index] = 0
            return
        }
        let outR = (color.red * alpha + dr * da * (1 - alpha)) / outA
        let outG = (color.green * alpha + dg * da * (1 - alpha)) / outA
        let outB = (color.blue * alpha + db * da * (1 - alpha)) / outA

        pixels[index] = Color(red: outR, green: outG, blue: outB, alpha: outA).packed
    }

    /// Gives a backend direct read access to the pixel words for presentation.
    public func withUnsafePixels<Result>(
        _ body: (UnsafeBufferPointer<UInt32>) throws -> Result
    ) rethrows -> Result {
        try pixels.withUnsafeBufferPointer(body)
    }
}
