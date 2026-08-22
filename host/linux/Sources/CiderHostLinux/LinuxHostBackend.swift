//  The Linux backend.
//
//  This is the only Swift module in the package that knows X11 and FreeType
//  exist. Nothing above `CiderHost` imports it; `CiderHostBootstrap` selects it
//  per platform. See docs/adr/0002-linux-windowing-backend.md.

#if canImport(Glibc)
import Glibc
#endif

import CiderCore
import CiderHost
import CX11Shim
import CTextShim

public final class LinuxHostBackend: HostBackend {
    public init() {}

    public var description: HostDescription {
        HostDescription(
            identifier: "linux-x11",
            detail: displayName.map { "X11 display \($0)" } ?? "X11 (DISPLAY unset)"
        )
    }

    private var displayName: String? {
        guard let raw = ProcessInfoLite.environmentValue("DISPLAY"), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    public func makeWindow(_ configuration: WindowConfiguration) throws -> HostWindow {
        try X11Window(configuration)
    }

    public func makeTextEngine(scale: Double) throws -> TextEngine {
        try FreeTypeTextEngine(scale: scale)
    }

    /// Checks that the pieces a window needs are actually present.
    ///
    /// `cider doctor` calls this rather than opening a real window, so that a
    /// diagnostic run leaves nothing on screen.
    public static func probe() -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        var buffer = [CChar](repeating: 0, count: 256)
        let displayOK = buffer.withUnsafeMutableBufferPointer { pointer in
            cider_x11_probe_display(pointer.baseAddress, pointer.count) == 1
        }
        if !displayOK {
            diagnostics.append(
                Diagnostic(
                    code: "CID0100",
                    summary: "no X display is available",
                    reason: """
                        Cider's Linux backend presents its virtual-device window through X11, \
                        and could not connect to a display: \(cString: buffer).
                        """,
                    remedy: """
                        Run Cider from a graphical session, or start a virtual display first:

                            Xvfb :99 -screen 0 1280x1024x24 &
                            export DISPLAY=:99
                        """
                )
            )
        }

        var fontBuffer = [CChar](repeating: 0, count: 256)
        let fontsOK = fontBuffer.withUnsafeMutableBufferPointer { pointer in
            cider_text_probe(pointer.baseAddress, pointer.count) == 1
        }
        if !fontsOK {
            diagnostics.append(
                Diagnostic(
                    code: "CID0110",
                    summary: "no usable font was found",
                    reason: """
                        Cider does not ship font files; it renders text with faces it finds \
                        through fontconfig. The host reported: \(cString: fontBuffer).
                        """,
                    remedy: """
                        Install a scalable font family, for example:

                            sudo apt install fonts-dejavu-core
                        """
                )
            )
        }

        return diagnostics
    }
}

/// A few environment lookups without pulling Foundation into the backend.
enum ProcessInfoLite {
    static func environmentValue(_ name: String) -> String? {
        guard let raw = getenv(name) else { return nil }
        return String(cString: raw)
    }
}

extension String.StringInterpolation {
    /// Interpolates a NUL-terminated C string buffer, for shim error messages.
    mutating func appendInterpolation(cString buffer: [CChar]) {
        let text = buffer.withUnsafeBufferPointer { pointer -> String in
            guard let base = pointer.baseAddress else { return "" }
            return String(cString: base)
        }
        appendLiteral(text.isEmpty ? "no further detail" : text)
    }
}
