//  A tappable control.

import CiderCore
import CiderUITree

public struct Button: CiderView {
    public typealias Body = Never

    private let title: String
    private let action: () -> Void
    private var font: FontRequest
    private var isEnabled: Bool

    // Optional, and resolved against `Theme` at lowering time rather than at
    // construction. A stored `Theme` value would make "the developer chose this
    // colour" and "nobody chose one" indistinguishable, and the visual editor
    // needs to tell those apart: one is written in the source and editable in
    // place, the other has to be inserted.
    private var titleColor: Color?
    private var backgroundColor: Color?
    private var pressedBackgroundColor: Color?
    private var cornerRadius: Double?
    private var padding: EdgeInsets?

    /// Creates a button that runs `action` when tapped.
    ///
    /// The action runs on the runtime's thread, between event handling and the
    /// next frame. It may change state freely; anything it touches through
    /// `@CiderState` invalidates the frame automatically.
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
        self.font = FontRequest(size: Theme.bodyFontSize, weight: .regular)
        self.isEnabled = true
    }

    public var body: Never { fatalError("Button has no body") }

    public func font(size: Double, weight: FontWeight = .regular) -> Button {
        var copy = self
        copy.font = FontRequest(family: font.family, size: size, weight: weight)
        return copy
    }

    public func disabled(_ isDisabled: Bool = true) -> Button {
        var copy = self
        copy.isEnabled = !isDisabled
        return copy
    }

    /// The colour of the button's label.
    public func foregroundColor(_ color: Color) -> Button {
        var copy = self
        copy.titleColor = color
        return copy
    }

    /// The button's resting and held-down background colours.
    ///
    /// Both are required. Deriving the pressed colour from the resting one
    /// means choosing a colour space and a factor, and a factor that reads
    /// correctly on a mid-tone background reads as a broken button on a dark
    /// or fully saturated one. Naming both is one more argument and no guess.
    public func background(_ color: Color, pressed: Color) -> Button {
        var copy = self
        copy.backgroundColor = color
        copy.pressedBackgroundColor = pressed
        return copy
    }

    public func cornerRadius(_ radius: Double) -> Button {
        var copy = self
        copy.cornerRadius = radius
        return copy
    }

    /// Insets between the button's label and its edges.
    ///
    /// Two scalars rather than an `EdgeInsets` value: the four-sided form is
    /// not expressible in this API yet (`EdgeInsets(horizontal:vertical:)` is
    /// what `Theme` itself uses), and two numbers are two fields in a property
    /// panel instead of a nested literal to rewrite.
    public func padding(horizontal: Double, vertical: Double) -> Button {
        var copy = self
        copy.padding = EdgeInsets(horizontal: horizontal, vertical: vertical)
        return copy
    }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(
            .button(
                ButtonNode(
                    id: id,
                    title: title,
                    font: font,
                    titleColor: titleColor ?? Theme.accentTextColor,
                    backgroundColor: backgroundColor ?? Theme.accentColor,
                    pressedBackgroundColor: pressedBackgroundColor ?? Theme.accentPressedColor,
                    cornerRadius: cornerRadius ?? Theme.buttonCornerRadius,
                    padding: padding ?? Theme.buttonPadding,
                    isEnabled: isEnabled
                )
            )
        )

        // A disabled button registers no action, so a stray hit can never
        // invoke it even if hit testing changes later.
        if isEnabled {
            context.register(action: action, for: id)
        }
    }
}
