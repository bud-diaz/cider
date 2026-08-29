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

    // Where this view and its written values came from. See `SourceOrigin`.
    private var origins: SourceOriginTable

    /// Creates a button that runs `action` when tapped.
    ///
    /// The action runs on the runtime's thread, between event handling and the
    /// next frame. It may change state freely; anything it touches through
    /// `@CiderState` invalidates the frame automatically.
    // The location parameters go last so Swift's forward-scan trailing-closure
    // matching still binds `Button("x") { ... }`'s closure to `action`.
    public init(
        _ title: String,
        action: @escaping () -> Void,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        self.title = title
        self.action = action
        self.font = FontRequest(size: Theme.bodyFontSize, weight: .regular)
        self.isEnabled = true
        self.origins = SourceOriginTable(file: file, line: line, column: column, initializerProperties: ["title"])
    }

    public var body: Never { fatalError("Button has no body") }

    public func font(
        size: Double,
        weight: FontWeight = .regular,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Button {
        var copy = self
        copy.font = FontRequest(family: font.family, size: size, weight: weight)
        copy.origins.record(file: file, line: line, column: column, for: ["fontSize", "fontWeight"])
        return copy
    }

    public func disabled(
        _ isDisabled: Bool = true,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Button {
        var copy = self
        copy.isEnabled = !isDisabled
        copy.origins.record(file: file, line: line, column: column, for: ["isEnabled"])
        return copy
    }

    /// The colour of the button's label.
    public func foregroundColor(
        _ color: Color,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Button {
        var copy = self
        copy.titleColor = color
        copy.origins.record(file: file, line: line, column: column, for: ["titleColor"])
        return copy
    }

    /// The button's resting and held-down background colours.
    ///
    /// Both are required. Deriving the pressed colour from the resting one
    /// means choosing a colour space and a factor, and a factor that reads
    /// correctly on a mid-tone background reads as a broken button on a dark
    /// or fully saturated one. Naming both is one more argument and no guess.
    public func background(
        _ color: Color,
        pressed: Color,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Button {
        var copy = self
        copy.backgroundColor = color
        copy.pressedBackgroundColor = pressed
        copy.origins.record(file: file, line: line, column: column, for: ["backgroundColor", "pressedBackgroundColor"])
        return copy
    }

    public func cornerRadius(
        _ radius: Double,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Button {
        var copy = self
        copy.cornerRadius = radius
        copy.origins.record(file: file, line: line, column: column, for: ["cornerRadius"])
        return copy
    }

    /// Insets between the button's label and its edges.
    ///
    /// Two scalars rather than an `EdgeInsets` value: the four-sided form is
    /// not expressible in this API yet (`EdgeInsets(horizontal:vertical:)` is
    /// what `Theme` itself uses), and two numbers are two fields in a property
    /// panel instead of a nested literal to rewrite.
    public func padding(
        horizontal: Double,
        vertical: Double,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Button {
        var copy = self
        copy.padding = EdgeInsets(horizontal: horizontal, vertical: vertical)
        copy.origins.record(file: file, line: line, column: column, for: ["paddingHorizontal", "paddingVertical"])
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

        context.register(origins: origins.nodeOrigins, for: id)

        // A disabled button registers no action, so a stray hit can never
        // invoke it even if hit testing changes later.
        if isEnabled {
            context.register(action: action, for: id)
        }
    }
}
