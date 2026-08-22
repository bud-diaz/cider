//  A scrollable viewport over content that may be larger than it.

import CiderCore
import CiderUITree

public struct ScrollView<Content: CiderView>: CiderView {
    public typealias Body = Never

    private let content: Content
    private var width: Double
    private var height: Double

    /// `width`/`height` are the viewport's own size -- see `ScrollViewNode`'s
    /// doc comment for why this is explicit rather than inherited from a
    /// parent's proposed size.
    public init(width: Double, height: Double, @CiderViewBuilder content: () -> Content) {
        self.content = content()
        self.width = width
        self.height = height
    }

    public var body: Never { fatalError("ScrollView has no body") }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        let children = context.withChildren(of: id) {
            content._lower(into: context)
        }

        let contentNode: UINode
        switch children.count {
        case 1:
            contentNode = children[0]
        default:
            // Zero or several loose top-level views need a container, the
            // same situation Lowering.scene handles for an app's body. The
            // "wrap" suffix can never collide with a real child's identity --
            // those are always numeric ("id/0", "id/1", ...) -- and wrapping
            // costs no side effects: `children` are already-lowered UINode
            // values, not views, so nothing here re-registers an action.
            contentNode = .vstack(
                VStackNode(
                    id: NodeID(path: "\(id.path)/wrap"),
                    spacing: Theme.stackSpacing,
                    alignment: .center,
                    children: children
                )
            )
        }

        context.emit(
            .scrollView(
                ScrollViewNode(id: id, viewportSize: Size(width: width, height: height), content: contentNode)
            )
        )
    }
}
