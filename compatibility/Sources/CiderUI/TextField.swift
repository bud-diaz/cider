//  A single-line editable text field, bound to application state.

import CiderCore
import CiderUITree

public struct TextField: CiderView {
    public typealias Body = Never

    private let binding: CiderState<String>
    private var width: Double
    private var font: FontRequest

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

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(
            .textField(
                TextFieldNode(
                    id: id,
                    text: binding.wrappedValue,
                    font: font,
                    textColor: Theme.textColor,
                    backgroundColor: Theme.textFieldBackgroundColor,
                    cornerRadius: Theme.textFieldCornerRadius,
                    padding: Theme.textFieldPadding,
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
