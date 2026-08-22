//  The software rasterizer.
//
//  This is shared code on purpose. If each backend drew its own rectangles and
//  composited its own glyphs, "the same application" would look different on
//  Linux and Windows and the visual baselines in docs/06-testing-strategy.md
//  would have to be captured per host. Backends supply glyph coverage and a
//  place to put pixels; everything between those two points happens here.

import CiderCore

public enum Rasterizer {

    /// Draws `tree` into a canvas sized for `pixelWidth` x `pixelHeight`.
    ///
    /// `scale` converts logical points to device pixels. It is passed
    /// explicitly rather than read from the text engine so that a caller
    /// rendering at a different resolution -- a screenshot at 2x, say -- cannot
    /// get the two out of step silently.
    public static func render(
        _ tree: RenderTree,
        pixelWidth: Int,
        pixelHeight: Int,
        scale: Double,
        textEngine: TextEngine
    ) -> Canvas {
        var canvas = Canvas(width: pixelWidth, height: pixelHeight, fill: tree.backgroundColor)

        // The unclipped canvas bounds are the base of the stack, so `clipStack.last`
        // is always a valid clip rect and every draw call can use it unconditionally
        // rather than special-casing "no clip is active".
        var clipStack: [Rect] = [Rect(x: 0, y: 0, width: Double(pixelWidth), height: Double(pixelHeight))]

        for command in tree.commands {
            switch command {
            case .fillRect(let rect, let color, let cornerRadius):
                fill(
                    rect: rect,
                    color: color,
                    cornerRadius: cornerRadius,
                    scale: scale,
                    clip: clipStack.last,
                    into: &canvas
                )

            case .text(let content, let baselineOrigin, let font, let color):
                draw(
                    text: content,
                    baselineOrigin: baselineOrigin,
                    font: font,
                    color: color,
                    scale: scale,
                    textEngine: textEngine,
                    clip: clipStack.last,
                    into: &canvas
                )

            case .image(let rect, let source):
                draw(image: source, rect: rect, scale: scale, clip: clipStack.last, into: &canvas)

            case .pushClip(let rect):
                let deviceRect = Rect(
                    x: rect.minX * scale,
                    y: rect.minY * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                )
                let current = clipStack.last ?? deviceRect
                // An empty intersection still pushes: the matching popClip must
                // find something to remove, or every push/pop after it shifts by
                // one and clips the wrong commands.
                clipStack.append(current.intersection(deviceRect) ?? .zero)

            case .popClip:
                // More pops than pushes is a builder bug, not a rasterizer
                // concern; dropping the base clip would make every later
                // command in the tree draw unclipped instead of failing loudly,
                // so the base entry is never removed.
                if clipStack.count > 1 {
                    clipStack.removeLast()
                }
            }
        }

        return canvas
    }

    // MARK: - Rectangles

    /// Fills a rounded rectangle with analytic antialiasing.
    ///
    /// Coverage comes from the signed distance to the shape's boundary, mapped
    /// across one pixel. That is cheaper than supersampling, and -- because it is
    /// a closed-form function of the geometry -- it produces identical output on
    /// every host, which supersampling with a jittered pattern would not.
    static func fill(
        rect: Rect,
        color: Color,
        cornerRadius: Double,
        scale: Double,
        clip: Rect? = nil,
        into canvas: inout Canvas
    ) {
        guard rect.width > 0, rect.height > 0, color.alpha > 0 else { return }

        let px = rect.minX * scale
        let py = rect.minY * scale
        let pw = rect.width * scale
        let ph = rect.height * scale
        // A radius larger than half the shorter side would invert the corner arc.
        let radius = min(cornerRadius * scale, min(pw, ph) / 2)

        // One pixel of slop so the antialiased edge is not clipped away.
        var minX = max(0, Int((px - 1).rounded(.down)))
        var minY = max(0, Int((py - 1).rounded(.down)))
        var maxX = min(canvas.width - 1, Int((px + pw + 1).rounded(.up)))
        var maxY = min(canvas.height - 1, Int((py + ph + 1).rounded(.up)))
        if let clip {
            minX = max(minX, Int(clip.minX.rounded(.up)))
            minY = max(minY, Int(clip.minY.rounded(.up)))
            maxX = min(maxX, Int(clip.maxX.rounded(.down)) - 1)
            maxY = min(maxY, Int(clip.maxY.rounded(.down)) - 1)
        }
        guard minX <= maxX, minY <= maxY else { return }

        let centerX = px + pw / 2
        let centerY = py + ph / 2
        let halfWidth = pw / 2
        let halfHeight = ph / 2

        for y in minY...maxY {
            for x in minX...maxX {
                // Sample at the pixel centre.
                let sampleX = Double(x) + 0.5
                let sampleY = Double(y) + 0.5

                let distance = roundedRectDistance(
                    dx: abs(sampleX - centerX),
                    dy: abs(sampleY - centerY),
                    halfWidth: halfWidth,
                    halfHeight: halfHeight,
                    radius: radius
                )

                // distance < 0 is inside. Map [-0.5, 0.5] px to coverage [1, 0].
                let coverage = min(1.0, max(0.0, 0.5 - distance))
                if coverage > 0 {
                    canvas.blend(x: x, y: y, color: color, coverage: coverage)
                }
            }
        }
    }

    /// Signed distance from a point to a rounded rectangle centred at the
    /// origin, given the point's absolute offsets. Negative inside.
    private static func roundedRectDistance(
        dx: Double,
        dy: Double,
        halfWidth: Double,
        halfHeight: Double,
        radius: Double
    ) -> Double {
        // Offset from the corner circle's centre, clamped at zero on each axis:
        // inside the straight edges this collapses to the usual box distance.
        let cornerX = dx - (halfWidth - radius)
        let cornerY = dy - (halfHeight - radius)

        if cornerX > 0 && cornerY > 0 {
            return (cornerX * cornerX + cornerY * cornerY).squareRoot() - radius
        }
        return max(cornerX, cornerY) - radius
    }

    // MARK: - Text

    static func draw(
        text: String,
        baselineOrigin: Point,
        font: FontRequest,
        color: Color,
        scale: Double,
        textEngine: TextEngine,
        clip: Rect? = nil,
        into canvas: inout Canvas
    ) {
        guard !text.isEmpty, color.alpha > 0 else { return }

        let run = textEngine.shape(text, font: font)
        let baselineX = baselineOrigin.x * scale
        let baselineY = baselineOrigin.y * scale

        for glyph in run.glyphs {
            guard let image = textEngine.image(forGlyph: glyph.glyphID, font: font) else {
                continue
            }

            // Round the pen position to whole pixels. Sub-pixel positioning would
            // look marginally better and would make glyph output depend on
            // fractional layout values, which is a poor trade for a renderer whose
            // baselines have to be stable.
            let penX = Int((baselineX + glyph.xOffset * scale).rounded())
            let penY = Int(baselineY.rounded())

            let left = penX + image.bearingX
            let top = penY - image.bearingY

            blit(image: image, atX: left, y: top, color: color, clip: clip, into: &canvas)
        }
    }

    /// Composites an 8-bit coverage mask in a single colour.
    private static func blit(
        image: GlyphImage,
        atX left: Int,
        y top: Int,
        color: Color,
        clip: Rect?,
        into canvas: inout Canvas
    ) {
        guard image.width > 0, image.height > 0 else { return }

        for row in 0..<image.height {
            let y = top + row
            guard y >= 0, y < canvas.height else { continue }
            if let clip, Double(y) + 0.5 < clip.minY || Double(y) + 0.5 >= clip.maxY { continue }

            let rowStart = row * image.width
            for column in 0..<image.width {
                let x = left + column
                guard x >= 0, x < canvas.width else { continue }
                if let clip, Double(x) + 0.5 < clip.minX || Double(x) + 0.5 >= clip.maxX { continue }

                let coverage = image.coverage[rowStart + column]
                guard coverage > 0 else { continue }

                canvas.blend(x: x, y: y, color: color, coverage: Double(coverage) / 255.0)
            }
        }
    }

    // MARK: - Images

    /// Nearest-neighbour samples `source` across `rect`.
    ///
    /// The rest of the renderer scales analytically (rounded rects) or by
    /// re-shaping at the target size (text): there is no resampling filter to
    /// share. Nearest-neighbour is the simplest correct choice for a bitmap,
    /// and -- being a closed-form function of the geometry -- deterministic
    /// across hosts, matching every other command here.
    static func draw(image source: ImageSource, rect: Rect, scale: Double, clip: Rect? = nil, into canvas: inout Canvas) {
        guard source.width > 0, source.height > 0, rect.width > 0, rect.height > 0 else { return }

        let originX = rect.minX * scale
        let originY = rect.minY * scale
        let deviceWidth = rect.width * scale
        let deviceHeight = rect.height * scale

        var minX = max(0, Int(originX.rounded(.down)))
        var minY = max(0, Int(originY.rounded(.down)))
        var maxX = min(canvas.width - 1, Int((originX + deviceWidth).rounded(.up)) - 1)
        var maxY = min(canvas.height - 1, Int((originY + deviceHeight).rounded(.up)) - 1)
        if let clip {
            minX = max(minX, Int(clip.minX.rounded(.up)))
            minY = max(minY, Int(clip.minY.rounded(.up)))
            maxX = min(maxX, Int(clip.maxX.rounded(.down)) - 1)
            maxY = min(maxY, Int(clip.maxY.rounded(.down)) - 1)
        }
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            let v = (Double(y) + 0.5 - originY) / deviceHeight
            guard v >= 0, v < 1 else { continue }
            let sourceY = min(source.height - 1, Int(v * Double(source.height)))

            for x in minX...maxX {
                let u = (Double(x) + 0.5 - originX) / deviceWidth
                guard u >= 0, u < 1 else { continue }
                let sourceX = min(source.width - 1, Int(u * Double(source.width)))

                let pixelIndex = (sourceY * source.width + sourceX) * 4
                let alpha = Double(source.pixels[pixelIndex + 3]) / 255.0
                guard alpha > 0 else { continue }

                canvas.blend(
                    x: x,
                    y: y,
                    color: Color(
                        red: Double(source.pixels[pixelIndex]) / 255.0,
                        green: Double(source.pixels[pixelIndex + 1]) / 255.0,
                        blue: Double(source.pixels[pixelIndex + 2]) / 255.0,
                        alpha: alpha
                    )
                )
            }
        }
    }
}
