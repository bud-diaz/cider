//  A scrollable, vertically-stacked collection of rows.
//
//  There is no dedicated ListNode: a list is exactly a ScrollView whose
//  content is always a VStack of rows, and reusing that machinery -- rather
//  than a parallel node kind with its own layout/render-tree/clip/scroll
//  logic to keep in sync with ScrollView's -- is the whole content of this
//  file. Row identity is the same structural index scheme every other
//  container already uses (see docs/adr/0003-ui-tree-model.md); there is no
//  virtualization, so a very long list measures and places every row on
//  every rebuild, same as a VStack today.

import CiderCore
import CiderUITree

public struct List<Content: CiderView>: CiderView {
    public typealias Body = Never

    private let content: Content
    private var width: Double
    private var height: Double
    private var spacing: Double

    /// `width`/`height` are the viewport's own size, the same reasoning as
    /// `ScrollView`'s.
    public init(
        width: Double,
        height: Double,
        spacing: Double = 0,
        @CiderViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.width = width
        self.height = height
        self.spacing = spacing
    }

    public var body: Never { fatalError("List has no body") }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        let rows = context.withChildren(of: id) {
            content._lower(into: context)
        }

        // Always wrapped, even for a single row: a list is rows, and "rows"
        // is what VStackNode.children already is. The "rows" suffix can
        // never collide with a real row's identity -- those are always
        // numeric ("id/0", "id/1", ...) -- the same technique ScrollView
        // uses for its own synthetic wrapper.
        let rowsNode = UINode.vstack(
            VStackNode(id: NodeID(path: "\(id.path)/rows"), spacing: spacing, alignment: .center, children: rows)
        )

        context.emit(
            .scrollView(
                ScrollViewNode(id: id, viewportSize: Size(width: width, height: height), content: rowsNode)
            )
        )
    }
}
