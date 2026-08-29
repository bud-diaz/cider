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

    // Where this view and its written values came from. See `SourceOrigin`.
    private var origins: SourceOriginTable

    /// `width`/`height` are the viewport's own size, the same reasoning as
    /// `ScrollView`'s.
    ///
    /// `spacing` is optional rather than defaulted to `0` so that "the caller
    /// wrote a spacing" stays distinguishable from "the caller did not", which
    /// is what decides whether an edit rewrites an argument or inserts one.
    public init(
        width: Double,
        height: Double,
        spacing: Double? = nil,
        @CiderViewBuilder content: () -> Content,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        self.content = content()
        self.width = width
        self.height = height
        self.spacing = spacing ?? 0
        self.origins = SourceOriginTable(
            view: "List",
            file: file,
            line: line,
            column: column,
            initializerProperties: ["viewportWidth", "viewportHeight"]
        )
        self.origins.recordIfWritten("spacing", spacing != nil)
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
        // The synthetic "/rows" stack carries the spacing but has no call site,
        // so it gets no origin. Only the list itself is addressable.
        context.register(origins: origins.nodeOrigins, for: id)
    }
}
