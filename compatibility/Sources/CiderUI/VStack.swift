//  A vertical stack.

import CiderUITree

public struct VStack<Content: CiderView>: CiderView {
    public typealias Body = Never

    private let content: Content
    private var spacing: Double
    private var alignment: HorizontalAlignment

    public init(
        spacing: Double = Theme.stackSpacing,
        alignment: HorizontalAlignment = .center,
        @CiderViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.spacing = spacing
        self.alignment = alignment
    }

    public var body: Never { fatalError("VStack has no body") }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        let children = context.withChildren(of: id) {
            content._lower(into: context)
        }
        context.emit(
            .vstack(
                VStackNode(id: id, spacing: spacing, alignment: alignment, children: children)
            )
        )
    }
}
