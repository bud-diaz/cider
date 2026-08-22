//  TextEngine over the FreeType/fontconfig shim.
//
//  The shim works in device pixels; `TextEngine` is specified in logical points.
//  This type is the only place that conversion happens, which is why `scale` is
//  immutable: a mid-flight scale change would silently invalidate every cached
//  measurement.

import CiderCore
import CiderHost
import CTextShim

final class FreeTypeTextEngine: TextEngine {
    let scale: Double

    private var handle: OpaquePointer?

    /// Faces already selected on the shim, so a repeated request skips the
    /// fontconfig round trip. Layout asks for the same two or three fonts on
    /// every frame.
    private var metricsCache: [FontRequest: FontMetrics] = [:]
    private var currentFace: FontRequest?

    init(scale: Double) throws {
        // A non-positive scale would produce a zero-pixel font and a blank
        // screen, which is far harder to diagnose than a refusal here.
        guard scale > 0 else {
            throw Diagnostic(
                code: "CID0112",
                summary: "invalid device scale \(scale)",
                reason: "A device profile's scale must be greater than zero.",
                remedy: "Correct `scale` in the device profile and try again."
            )
        }
        self.scale = scale

        var error = [CChar](repeating: 0, count: 256)
        let created = error.withUnsafeMutableBufferPointer { buffer in
            cider_text_engine_create(buffer.baseAddress, buffer.count)
        }
        guard let created else {
            throw Diagnostic(
                code: "CID0111",
                summary: "could not start the text engine",
                reason: "FreeType or fontconfig could not be initialised: \(cString: error).",
                remedy: """
                    Install the font stack Cider's Linux backend needs:

                        sudo apt install libfreetype-dev libfontconfig-dev fonts-dejavu-core
                    """
            )
        }
        self.handle = created
    }

    deinit {
        if let handle {
            cider_text_engine_destroy(handle)
        }
    }

    func metrics(for font: FontRequest) -> FontMetrics {
        if let cached = metricsCache[font] { return cached }
        guard selectFace(font), let handle else { return Self.fallbackMetrics(for: font) }

        var raw = cider_text_metrics()
        guard cider_text_face_metrics(handle, &raw) == 0 else {
            return Self.fallbackMetrics(for: font)
        }

        let result = FontMetrics(
            ascent: raw.ascent / scale,
            descent: raw.descent / scale,
            lineHeight: raw.line_height / scale
        )
        metricsCache[font] = result
        return result
    }

    func shape(_ text: String, font: FontRequest) -> ShapedRun {
        let metrics = metrics(for: font)
        guard !text.isEmpty, selectFace(font), let handle else {
            return ShapedRun(glyphs: [], width: 0, metrics: metrics)
        }

        let codePoints = text.unicodeScalars.map(\.value)
        var glyphs = [cider_text_glyph](repeating: cider_text_glyph(), count: codePoints.count)
        var width: Double = 0

        let written = codePoints.withUnsafeBufferPointer { source in
            glyphs.withUnsafeMutableBufferPointer { destination in
                cider_text_shape(
                    handle,
                    source.baseAddress,
                    Int32(source.count),
                    destination.baseAddress,
                    Int32(destination.count),
                    &width
                )
            }
        }
        guard written >= 0 else {
            return ShapedRun(glyphs: [], width: 0, metrics: metrics)
        }

        let positioned = glyphs.prefix(Int(written)).map {
            PositionedGlyph(glyphID: $0.glyph_id, xOffset: $0.x_offset / scale)
        }
        return ShapedRun(glyphs: Array(positioned), width: width / scale, metrics: metrics)
    }

    func image(forGlyph glyphID: UInt32, font: FontRequest) -> GlyphImage? {
        guard selectFace(font), let handle else { return nil }

        var raw = cider_text_bitmap()
        let status = cider_text_render_glyph(handle, glyphID, &raw)
        // 1 means "no outline", which is normal for a space.
        guard status == 0, let source = raw.coverage, raw.width > 0, raw.height > 0 else {
            return nil
        }

        let count = Int(raw.width) * Int(raw.height)
        let coverage = Array(UnsafeBufferPointer(start: source, count: count))
        return GlyphImage(
            width: Int(raw.width),
            height: Int(raw.height),
            bearingX: Int(raw.bearing_x),
            bearingY: Int(raw.bearing_y),
            coverage: coverage
        )
    }

    /// Points the shim at the face for `font`, skipping the call when it is
    /// already selected.
    private func selectFace(_ font: FontRequest) -> Bool {
        guard let handle else { return false }
        if currentFace == font { return true }

        var error = [CChar](repeating: 0, count: 256)
        let weight: Int32 = font.weight == .bold
            ? Int32(CIDER_TEXT_WEIGHT_BOLD.rawValue)
            : Int32(CIDER_TEXT_WEIGHT_REGULAR.rawValue)

        let status = font.family.withCString { family in
            error.withUnsafeMutableBufferPointer { buffer in
                cider_text_select_face(
                    handle,
                    family,
                    font.size * scale,
                    weight,
                    buffer.baseAddress,
                    buffer.count
                )
            }
        }
        guard status == 0 else {
            currentFace = nil
            return false
        }
        currentFace = font
        return true
    }

    /// Used when the host font stack fails mid-frame.
    ///
    /// Returning plausible metrics keeps layout finite so the developer sees a
    /// window with missing text -- and the accompanying diagnostic -- rather than
    /// a collapsed or crashed one.
    private static func fallbackMetrics(for font: FontRequest) -> FontMetrics {
        FontMetrics(
            ascent: font.size * 0.8,
            descent: font.size * 0.2,
            lineHeight: font.size * 1.2
        )
    }
}
