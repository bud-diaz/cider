//  A run of text.

import CiderCore
import CiderUITree

public struct Text: CiderView {
    public typealias Body = Never

    private let content: String
    private var font: FontRequest
    private var color: Color

    public init(_ content: String) {
        self.content = content
        self.font = FontRequest(size: Theme.bodyFontSize, weight: .regular)
        self.color = Theme.textColor
    }

    public var body: Never { fatalError("Text has no body") }

    // MARK: - Modifiers
    //
    // Modifiers return a modified copy rather than wrapping the view in a
    // generic modifier type. Wrapping is more general and it is how this will
    // eventually have to work once modifiers apply to arbitrary views -- but
    // with two properties on one primitive, the general machinery would be more
    // code than the thing it generalises.

    public func font(size: Double, weight: FontWeight = .regular) -> Text {
        var copy = self
        copy.font = FontRequest(family: font.family, size: size, weight: weight)
        return copy
    }

    public func foregroundColor(_ color: Color) -> Text {
        var copy = self
        copy.color = color
        return copy
    }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(
            .text(TextNode(id: id, text: content, font: font, color: color))
        )
    }
}
