//  Raw pixel data for an `Image` view.
//
//  There is no image decoder in Cider yet -- PNG/JPEG decoding is out of
//  Stage 2's scope. An `ImageSource` is already-decoded pixels, which is
//  enough to carry the `Image` node kind through the whole pipeline (view ->
//  tree -> layout -> render tree -> rasterizer) and to give deterministic,
//  host-independent visual-regression baselines, the same reasoning
//  `DeterministicTextEngine` applies to text.

public struct ImageSource: Equatable, Sendable {
    public var width: Int
    public var height: Int

    /// Straight-alpha RGBA8, row-major, four bytes per pixel, no padding.
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(
            pixels.count == width * height * 4,
            "ImageSource pixel count must be width * height * 4"
        )
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// A single solid colour, `width` by `height`. Useful for placeholders,
    /// tests and deterministic baselines before a real decoder exists.
    public static func solid(_ color: Color, width: Int, height: Int) -> ImageSource {
        let r = UInt8((color.red * 255).rounded())
        let g = UInt8((color.green * 255).rounded())
        let b = UInt8((color.blue * 255).rounded())
        let a = UInt8((color.alpha * 255).rounded())

        var pixels = [UInt8](repeating: 0, count: max(0, width) * max(0, height) * 4)
        var index = pixels.startIndex
        while index < pixels.endIndex {
            pixels[index] = r
            pixels[index + 1] = g
            pixels[index + 2] = b
            pixels[index + 3] = a
            index += 4
        }
        return ImageSource(width: width, height: height, pixels: pixels)
    }
}
