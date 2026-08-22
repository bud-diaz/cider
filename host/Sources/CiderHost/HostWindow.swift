//  The window interface a platform backend provides.

import CiderCore

/// How a window should map its logical content onto its physical surface.
public struct WindowConfiguration: Sendable {
    /// Title shown in the host's window decoration.
    public var title: String

    /// Content size in device pixels.
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(title: String, pixelWidth: Int, pixelHeight: Int) {
        self.title = title
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// A surface Cider can present a `Canvas` to, and which reports input.
///
/// Everything a backend must do is here: hold a window, take a framebuffer,
/// hand back events. There is no drawing API, because Cider rasterizes in shared
/// code. A backend that grew a `drawText` would silently make output
/// host-specific, which is exactly what this seam exists to prevent.
public protocol HostWindow: AnyObject {
    /// Current surface size in device pixels. May differ from the requested size
    /// if the host window manager overrode it.
    var pixelWidth: Int { get }
    var pixelHeight: Int { get }

    /// Copies `canvas` to the surface and makes it visible.
    ///
    /// The canvas is sized for the device profile, which need not match the
    /// surface: a backend is expected to letterbox or scale, and to say which it
    /// did in its documentation.
    func present(_ canvas: Canvas) throws

    /// Returns every event that has arrived since the last call, in order.
    ///
    /// This never blocks. The runtime owns the event loop and its timing, so a
    /// backend that blocked here would take that control away.
    func pollEvents() -> [HostEvent]

    /// Releases the window. Calling it twice is not an error.
    func close()
}
