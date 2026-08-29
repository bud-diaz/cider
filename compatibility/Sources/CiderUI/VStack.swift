//  A vertical stack.

import CiderCore
import CiderUITree

public struct VStack<Content: CiderView>: CiderView {
    public typealias Body = Never

    private let content: Content
    private var spacing: Double
    private var alignment: HorizontalAlignment

    // Where this view and its written values came from. See `SourceOrigin`.
    private var origins: SourceOriginTable

    /// `spacing` and `alignment` are optional rather than defaulted to their
    /// `Theme` values so that the two cases stay distinguishable: a caller who
    /// passed a value wrote one in the source, and a caller who did not has
    /// nothing there to rewrite. A defaulted `Double` cannot tell those apart
    /// once the call has returned. Both still behave exactly as before when
    /// omitted, and `VStack(spacing: 24)` is unchanged.
    ///
    /// The location parameters come after `content` so Swift's forward-scan
    /// trailing-closure matching still binds `VStack { ... }` to `content`.
    public init(
        spacing: Double? = nil,
        alignment: HorizontalAlignment? = nil,
        @CiderViewBuilder content: () -> Content,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        self.content = content()
        self.spacing = spacing ?? Theme.stackSpacing
        self.alignment = alignment ?? .center
        self.origins = SourceOriginTable(file: file, line: line, column: column)
        self.origins.recordIfWritten("spacing", spacing != nil)
        self.origins.recordIfWritten("alignment", alignment != nil)
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
        context.register(origins: origins.nodeOrigins, for: id)
    }
}
