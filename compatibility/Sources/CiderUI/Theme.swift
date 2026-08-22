//  Default appearance.
//
//  Hard-coded values, gathered in one place so they are easy to find and easy to
//  delete. A real theming system belongs with environment values in Stage 3 of
//  docs/05-implementation-roadmap.md; scattering these constants through the
//  view types now would make that change touch every file.
//
//  The colours are ordinary interface colours picked to be legible. They are not
//  taken from, and do not attempt to match, any vendor's design system.

import CiderCore

public enum Theme {
    public static let bodyFontSize = 17.0
    public static let titleFontSize = 24.0

    public static let textColor = Color(hex: 0x1C1C1E)
    public static let backgroundColor = Color(hex: 0xF2F2F7)

    public static let accentColor = Color(hex: 0x1F6FEB)
    public static let accentPressedColor = Color(hex: 0x1A5CC0)
    public static let accentTextColor = Color(hex: 0xFFFFFF)

    public static let buttonCornerRadius = 12.0
    public static let buttonPadding = EdgeInsets(horizontal: 24, vertical: 12)

    public static let textFieldBackgroundColor = Color(hex: 0xFFFFFF)
    public static let textFieldCornerRadius = 8.0
    public static let textFieldPadding = EdgeInsets(horizontal: 12, vertical: 8)

    public static let stackSpacing = 16.0

    /// The dimming behind a presented modal. Partial alpha so the base
    /// content stays visible underneath (dimmed, not hidden) -- straight
    /// alpha, like every other colour here, composited by `Canvas.blend`.
    public static let modalOverlayColor = Color(hex: 0x000000, alpha: 0.4)
}
