//  A run of text.

import CiderCore
import CiderUITree

public struct Text: CiderView {
    public typealias Body = Never

    private let content: String
    private var font: FontRequest
    private var color: Color

    // Where this view, and each value the developer wrote on it, came from.
    // Carried so the developer console can rewrite the right expression; see
    // `SourceOrigin`. Nothing in rendering reads it.
    private var origins: SourceOriginTable

    // The location parameters go last in every signature so that Swift's
    // forward-scan trailing-closure matching is unaffected. They default, so no
    // call site mentions them.
    public init(_ content: String, file: String = #filePath, line: Int = #line, column: Int = #column) {
        self.content = content
        self.font = FontRequest(size: Theme.bodyFontSize, weight: .regular)
        self.color = Theme.textColor
        self.origins = SourceOriginTable(file: file, line: line, column: column, initializerProperties: ["text"])
    }

    public var body: Never { fatalError("Text has no body") }

    // MARK: - Modifiers
    //
    // Modifiers return a modified copy rather than wrapping the view in a
    // generic modifier type. Wrapping is more general and it is how this will
    // eventually have to work once modifiers apply to arbitrary views -- but
    // with two properties on one primitive, the general machinery would be more
    // code than the thing it generalises.

    public func font(
        size: Double,
        weight: FontWeight = .regular,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Text {
        var copy = self
        copy.font = FontRequest(family: font.family, size: size, weight: weight)
        copy.origins.record(file: file, line: line, column: column, for: ["fontSize", "fontWeight"])
        return copy
    }

    public func foregroundColor(
        _ color: Color,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) -> Text {
        var copy = self
        copy.color = color
        copy.origins.record(file: file, line: line, column: column, for: ["color"])
        return copy
    }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(
            .text(TextNode(id: id, text: content, font: font, color: color))
        )
        context.register(origins: origins.nodeOrigins, for: id)
    }
}
