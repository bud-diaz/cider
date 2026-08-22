//  Default appearance.
//
//  Hard-coded values, gathered in one place so they are easy to find and easy to
//  delete. A real theming system belongs with environment values in Stage 3 of
//  docs/05-implementation-roadmap.md; scattering these constants through the
//  view types now would make that change touch every file.
//
//  The colours below implement the locked Cider brand direction in
//  docs/Cider_DESIGN.md: dark, technical, low-noise surfaces with Cider Amber as
//  an accent. They intentionally avoid vendor UI palettes so the runtime feels
//  like its own developer platform, not an imitation of somebody else's.

import CiderCore

public enum Theme {
    public static let bodyFontSize = 17.0
    public static let titleFontSize = 24.0

    // MARK: - Locked brand tokens

    public static let ciderBlack = Color(hex: 0x10100F)
    public static let ciderGraphite = Color(hex: 0x1C1C1A)
    public static let ciderSurface = Color(hex: 0x242421)
    public static let ciderBorder = Color(hex: 0x34342F)
    public static let ciderMuted = Color(hex: 0x8F8D86)
    public static let ciderText = Color(hex: 0xF5F1E8)
    public static let ciderAmber = Color(hex: 0xE89A2F)
    public static let ciderAmberBright = Color(hex: 0xFFB547)

    public static let textColor = ciderText
    public static let backgroundColor = ciderBlack

    public static let accentColor = ciderAmber
    public static let accentPressedColor = ciderAmberBright
    public static let accentTextColor = ciderBlack

    public static let buttonCornerRadius = 8.0
    public static let buttonPadding = EdgeInsets(horizontal: 24, vertical: 12)

    public static let textFieldBackgroundColor = ciderSurface
    public static let textFieldCornerRadius = 8.0
    public static let textFieldPadding = EdgeInsets(horizontal: 12, vertical: 8)

    public static let stackSpacing = 16.0

    /// The dimming behind a presented modal. Partial alpha so the base
    /// content stays visible underneath (dimmed, not hidden) -- straight
    /// alpha, like every other colour here, composited by `Canvas.blend`.
    public static let modalOverlayColor = Color(hex: 0x000000, alpha: 0.55)
}
