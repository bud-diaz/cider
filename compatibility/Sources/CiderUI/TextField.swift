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

    // Where this view and its written values came from. See `SourceOrigin`.
    private var origins: SourceOriginTable

    /// `width` is the field's own width -- see `TextFieldNode`'s doc comment
    /// for why this is explicit rather than sized to the current text or
    /// inherited from a parent.
    public init(
        _ binding: CiderState<String>,
        width: Double,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        self.binding = binding
        self.width = width
        self.font = FontRequest(size: Theme.bodyFontSize, weight: .regular)
        // `text` is deliberately absent: it is the bound state's value, not
        // anything written at this call site.
        self.origins = SourceOriginTable(file: file, line: line, column: column, initializerProperties: ["width"])
    }

    public var body: Never { fatalError("TextField has no body") }

    public func font(
        size: Double,
        weight: FontWeight = .regular,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> TextField {
        var copy = self
        copy.font = FontRequest(family: font.family, size: size, weight: weight)
        copy.origins.record(file: file, line: line, column: column, for: ["fontSize", "fontWeight"])
        return copy
    }

    /// The colour of the field's text.
    public func foregroundColor(
        _ color: Color,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> TextField {
        var copy = self
        copy.textColor = color
        copy.origins.record(file: file, line: line, column: column, for: ["textColor"])
        return copy
    }

    /// The field's fill colour. A text field has no pressed state, so unlike
    /// `Button.background(_:pressed:)` this takes one colour.
    public func background(
        _ color: Color,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> TextField {
        var copy = self
        copy.backgroundColor = color
        copy.origins.record(file: file, line: line, column: column, for: ["backgroundColor"])
        return copy
    }

    public func cornerRadius(
        _ radius: Double,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> TextField {
        var copy = self
        copy.cornerRadius = radius
        copy.origins.record(file: file, line: line, column: column, for: ["cornerRadius"])
        return copy
    }

    /// Insets between the field's text and its edges. See
    /// `Button.padding(horizontal:vertical:)` for why this is two scalars.
    public func padding(
        horizontal: Double,
        vertical: Double,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> TextField {
        var copy = self
        copy.padding = EdgeInsets(horizontal: horizontal, vertical: vertical)
        copy.origins.record(file: file, line: line, column: column, for: ["paddingHorizontal", "paddingVertical"])
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

        context.register(origins: origins.nodeOrigins, for: id)

        // The binding is a class (see CiderState's doc comment), so this
        // closure and the app's own `@CiderState` property both point at the
        // same storage: writing through it here invalidates the frame the
        // same way a state mutation inside a button's action would.
        context.register(textInputHandler: { [binding] newText in binding.wrappedValue = newText }, for: id)
    }
}
