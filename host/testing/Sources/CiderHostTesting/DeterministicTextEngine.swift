//  A text engine with no dependency on the host's fonts.
//
//  Real font rasterization is not reproducible across machines: metrics differ
//  by face and by FreeType version, and the installed face set differs by
//  distribution. Any test that asserts on layout numbers or on pixels therefore
//  has to supply its own text metrics, or it is asserting about the machine.
//
//  This engine invents a monospaced face with round numbers and draws every
//  glyph as a filled block. That makes it useless for judging how text *looks*
//  and ideal for judging whether Cider put it in the right place.

import CiderCore

public final class DeterministicTextEngine: TextEngine {
    public let scale: Double

    /// Advance width as a fraction of the font size. 0.6 is close enough to a
    /// real monospaced face that layouts look sane when dumped.
    public static let advanceRatio = 0.6
    public static let ascentRatio = 0.8
    public static let descentRatio = 0.2
    public static let lineHeightRatio = 1.2

    public init(scale: Double) {
        self.scale = scale
    }

    public func metrics(for font: FontRequest) -> FontMetrics {
        FontMetrics(
            ascent: font.size * Self.ascentRatio,
            descent: font.size * Self.descentRatio,
            lineHeight: font.size * Self.lineHeightRatio
        )
    }

    public func shape(_ text: String, font: FontRequest) -> ShapedRun {
        let advance = font.size * Self.advanceRatio
        var glyphs: [PositionedGlyph] = []
        glyphs.reserveCapacity(text.unicodeScalars.count)

        var pen = 0.0
        for scalar in text.unicodeScalars {
            // Using the scalar value as the glyph id keeps the mapping obvious
            // when a test failure prints a glyph run.
            glyphs.append(PositionedGlyph(glyphID: scalar.value, xOffset: pen))
            pen += advance
        }

        return ShapedRun(glyphs: glyphs, width: pen, metrics: metrics(for: font))
    }

    /// How many distinct block heights the engine cycles through.
    ///
    /// Every glyph must not rasterize identically, or two different strings of
    /// the same length would produce the same pixels -- and a visual test could
    /// not tell "Count: 0" from "Count: 1". Seven is coprime with the alphabet
    /// sizes that matter, so adjacent characters differ.
    static let heightVariants: UInt32 = 7

    public func image(forGlyph glyphID: UInt32, font: FontRequest) -> GlyphImage? {
        // Whitespace has no mark, matching a real engine.
        if let scalar = Unicode.Scalar(glyphID), scalar.properties.isWhitespace {
            return nil
        }

        let pixelSize = font.size * scale
        let width = max(1, Int((pixelSize * Self.advanceRatio * 0.8).rounded()))

        // The height is a deterministic function of the glyph, so the same
        // character always draws the same block and different characters do not.
        let variance = 0.45 + Double(glyphID % Self.heightVariants) * 0.03
        let height = max(1, Int((pixelSize * variance).rounded()))

        return GlyphImage(
            width: width,
            height: height,
            bearingX: 0,
            bearingY: height,
            coverage: [UInt8](repeating: 255, count: width * height)
        )
    }
}
