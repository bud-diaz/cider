//  What a platform must supply for Cider to run on it.

import CiderCore

/// Facts about the host that `cider doctor` and the runtime both report.
public struct HostDescription: Sendable {
    /// A human name for the backend, such as `linux-x11`.
    public var identifier: String

    /// A one-line description of what the backend is talking to, such as
    /// `X11 display :99`. Shown in diagnostics.
    public var detail: String

    public init(identifier: String, detail: String) {
        self.identifier = identifier
        self.detail = detail
    }
}

/// A platform's entry point.
///
/// A backend is a factory, not a singleton: tests create several, and a future
/// multi-window inspector will want more than one surface at a time.
public protocol HostBackend: AnyObject {
    var description: HostDescription { get }

    /// Opens a window, or throws a `Diagnostic` explaining what the host is
    /// missing. Backends must not exit the process on failure -- the runtime
    /// turns the diagnostic into a message a developer can act on.
    func makeWindow(_ configuration: WindowConfiguration) throws -> HostWindow

    /// Creates the text engine used for measurement and glyph rasterization at
    /// the given device scale.
    func makeTextEngine(scale: Double) throws -> TextEngine
}
