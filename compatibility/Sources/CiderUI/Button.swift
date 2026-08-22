//  A tappable control.

import CiderCore
import CiderUITree

public struct Button: CiderView {
    public typealias Body = Never

    private let title: String
    private let action: () -> Void
    private var font: FontRequest
    private var isEnabled: Bool

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

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(
            .button(
                ButtonNode(
                    id: id,
                    title: title,
                    font: font,
                    titleColor: Theme.accentTextColor,
                    backgroundColor: Theme.accentColor,
                    pressedBackgroundColor: Theme.accentPressedColor,
                    cornerRadius: Theme.buttonCornerRadius,
                    padding: Theme.buttonPadding,
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
