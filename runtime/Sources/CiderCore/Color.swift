//  A minimal straight-alpha RGBA colour.

/// A colour with components in the range 0...1.
///
/// Cider stores colours in straight (non-premultiplied) alpha and premultiplies
/// only at the moment of compositing. Straight alpha is easier to reason about
/// in tests and avoids rounding drift when a colour is carried through several
/// layout passes without being drawn.
public struct Color: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = Color.clamp(red)
        self.green = Color.clamp(green)
        self.blue = Color.clamp(blue)
        self.alpha = Color.clamp(alpha)
    }

    /// Builds a colour from a 24-bit `0xRRGGBB` literal.
    public init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    private static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1, max(0, value))
    }

    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = Color(hex: 0x000000)
    public static let white = Color(hex: 0xFFFFFF)

    /// Packs into the `0xAARRGGBB` word layout used by `Canvas`.
    public var packed: UInt32 {
        let a = UInt32((alpha * 255).rounded())
        let r = UInt32((red * 255).rounded())
        let g = UInt32((green * 255).rounded())
        let b = UInt32((blue * 255).rounded())
        return (a << 24) | (r << 16) | (g << 8) | b
    }
}
