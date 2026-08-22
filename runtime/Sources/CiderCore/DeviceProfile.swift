//  Virtual-device description.

/// The orientations Cider models. Portrait only for the MVP, per
/// docs/04-compatibility-specification.md.
public enum DeviceOrientation: String, Sendable, CaseIterable {
    case portrait
}

/// A deterministic description of the virtual device an application runs in.
///
/// These are Cider development defaults chosen to be a plausible modern phone.
/// They are not a claim to reproduce any specific hardware, and the profile name
/// is deliberately generic (see docs/07-legal-distribution-boundaries.md).
public struct DeviceProfile: Equatable, Sendable {
    /// The identifier used in a manifest and on the command line.
    public var name: String

    /// Logical size in points. Layout works entirely in this space.
    public var logicalWidth: Double
    public var logicalHeight: Double

    /// Device pixels per logical point.
    public var scale: Double

    public var orientation: DeviceOrientation

    /// Insets an application should keep its content clear of.
    public var safeArea: EdgeInsets

    public init(
        name: String,
        logicalWidth: Double,
        logicalHeight: Double,
        scale: Double,
        orientation: DeviceOrientation,
        safeArea: EdgeInsets
    ) {
        self.name = name
        self.logicalWidth = logicalWidth
        self.logicalHeight = logicalHeight
        self.scale = scale
        self.orientation = orientation
        self.safeArea = safeArea
    }

    /// The whole screen, in logical points.
    public var bounds: Rect {
        Rect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
    }

    /// The area inside the safe-area insets.
    public var safeAreaBounds: Rect {
        bounds.inset(by: safeArea)
    }

    /// Framebuffer size in device pixels.
    public var pixelSize: (width: Int, height: Int) {
        (Int((logicalWidth * scale).rounded()), Int((logicalHeight * scale).rounded()))
    }
}
