//  The text interface layout and rasterization are written against.
//
//  Text is the one part of rendering Cider cannot implement portably in a
//  reasonable amount of code: glyph outlines, hinting and font lookup are
//  genuinely platform work. So text is a *service* with a protocol here and an
//  implementation per backend, while everything downstream of it -- line
//  breaking, alignment, compositing -- stays in shared code.
//
//  The protocol deliberately stops at positioned glyphs. It does not draw. A
//  backend that could draw a whole string faster is not allowed to, because the
//  moment a backend owns compositing, two hosts stop producing the same pixels
//  and visual baselines become per-host.

public enum FontWeight: String, Sendable, Hashable, CaseIterable {
    case regular
    case bold
}

/// A request for a font. `family` is a hint: a backend resolves it however the
/// host does, and substitutes when it is absent. Cider never ships font files
/// (see docs/07-legal-distribution-boundaries.md), so every face is the host's.
public struct FontRequest: Hashable, Sendable {
    /// A generic family name such as `sans-serif`, never a licensed face name.
    public var family: String

    /// Size in logical points.
    public var size: Double

    public var weight: FontWeight

    public init(family: String = "sans-serif", size: Double, weight: FontWeight = .regular) {
        self.family = family
        self.size = size
        self.weight = weight
    }
}

/// Vertical metrics in logical points. `ascent` is positive above the baseline,
/// `descent` positive below it.
public struct FontMetrics: Equatable, Sendable {
    public var ascent: Double
    public var descent: Double
    public var lineHeight: Double

    public init(ascent: Double, descent: Double, lineHeight: Double) {
        self.ascent = ascent
        self.descent = descent
        self.lineHeight = lineHeight
    }
}

/// One glyph placed on a baseline. `xOffset` is in logical points from the
/// start of the run.
public struct PositionedGlyph: Equatable, Sendable {
    public var glyphID: UInt32
    public var xOffset: Double

    public init(glyphID: UInt32, xOffset: Double) {
        self.glyphID = glyphID
        self.xOffset = xOffset
    }
}

/// The result of shaping a string: where each glyph goes and how wide the whole
/// run is.
public struct ShapedRun: Equatable, Sendable {
    public var glyphs: [PositionedGlyph]
    public var width: Double
    public var metrics: FontMetrics

    public init(glyphs: [PositionedGlyph], width: Double, metrics: FontMetrics) {
        self.glyphs = glyphs
        self.width = width
        self.metrics = metrics
    }
}

/// An 8-bit coverage mask for one glyph, in *device pixels*.
///
/// `bearingX` / `bearingY` are offsets from the glyph's pen position to the
/// top-left of the mask, also in device pixels, with `bearingY` measured up from
/// the baseline.
public struct GlyphImage: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var bearingX: Int
    public var bearingY: Int
    public var coverage: [UInt8]

    public init(width: Int, height: Int, bearingX: Int, bearingY: Int, coverage: [UInt8]) {
        self.width = width
        self.height = height
        self.bearingX = bearingX
        self.bearingY = bearingY
        self.coverage = coverage
    }

    public static let empty = GlyphImage(
        width: 0, height: 0, bearingX: 0, bearingY: 0, coverage: []
    )
}

public protocol TextEngine: AnyObject {
    /// Device pixels per logical point. Fixed for the engine's lifetime so that
    /// shaping and rasterization can never disagree about it.
    var scale: Double { get }

    func metrics(for font: FontRequest) -> FontMetrics

    /// Lays out `text` on a single line. Cider does not yet do bidirectional
    /// reordering or complex-script shaping; see docs/adr/0002 for the
    /// consequences and the eventual plan.
    func shape(_ text: String, font: FontRequest) -> ShapedRun

    /// Returns the coverage mask for a glyph, or `nil` when the face has no
    /// outline for it (a space, for instance).
    func image(forGlyph glyphID: UInt32, font: FontRequest) -> GlyphImage?
}
