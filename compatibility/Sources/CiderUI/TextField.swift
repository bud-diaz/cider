//  A single-line editable text field, bound to application state.

import CiderCore
import CiderUITree

public struct TextField: CiderView {
    public typealias Body = Never

    private let binding: CiderState<String>
    private var width: Double
    private var font: FontRequest

    // Optional and resolved against `Theme` at lowering time, for the same
    // reason as `Button`: the visual editor has to tell "the developer wrote
    // this colour" apart from "nobody wrote one".
    private var textColor: Color?
    private var backgroundColor: Color?
    private var cornerRadius: Double?
    private var padding: EdgeInsets?

    /// `width` is the field's own width -- see `TextFieldNode`'s doc comment
    /// for why this is explicit rather than sized to the current text or
    /// inherited from a parent.
    public init(_ binding: CiderState<String>, width: Double) {
        self.binding = binding
        self.width = width
        self.font = FontRequest(size: Theme.bodyFontSize, weight: .regular)
    }

    public var body: Never { fatalError("TextField has no body") }

    public func font(size: Double, weight: FontWeight = .regular) -> TextField {
        var copy = self
        copy.font = FontRequest(family: font.family, size: size, weight: weight)
        return copy
    }

    /// The colour of the field's text.
    public func foregroundColor(_ color: Color) -> TextField {
        var copy = self
        copy.textColor = color
        return copy
    }

    /// The field's fill colour. A text field has no pressed state, so unlike
    /// `Button.background(_:pressed:)` this takes one colour.
    public func background(_ color: Color) -> TextField {
        var copy = self
        copy.backgroundColor = color
        return copy
    }

    public func cornerRadius(_ radius: Double) -> TextField {
        var copy = self
        copy.cornerRadius = radius
        return copy
    }

    /// Insets between the field's text and its edges. See
    /// `Button.padding(horizontal:vertical:)` for why this is two scalars.
    public func padding(horizontal: Double, vertical: Double) -> TextField {
        var copy = self
        copy.padding = EdgeInsets(horizontal: horizontal, vertical: vertical)
        return copy
    }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(
            .textField(
                TextFieldNode(
                    id: id,
                    text: binding.wrappedValue,
                    font: font,
                    textColor: textColor ?? Theme.textColor,
                    backgroundColor: backgroundColor ?? Theme.textFieldBackgroundColor,
                    cornerRadius: cornerRadius ?? Theme.textFieldCornerRadius,
                    padding: padding ?? Theme.textFieldPadding,
                    width: width
                )
            )
        )

        // The binding is a class (see CiderState's doc comment), so this
        // closure and the app's own `@CiderState` property both point at the
        // same storage: writing through it here invalidates the frame the
        // same way a state mutation inside a button's action would.
        context.register(textInputHandler: { [binding] newText in binding.wrappedValue = newText }, for: id)
    }
}
