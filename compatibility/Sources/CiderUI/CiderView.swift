//  The application-facing view protocol.
//
//  This API is written from public descriptions of how declarative UI in Swift
//  behaves -- a value describing what should be on screen, rebuilt when state
//  changes -- and from the shape Swift's type system pushes such an API toward.
//  It is not a reimplementation of anyone's framework and does not aim for
//  source compatibility with one; see docs/07-legal-distribution-boundaries.md
//  section 6, and docs/adr/0001-language-boundaries.md.
//
//  It is small on purpose. docs/05-implementation-roadmap.md scopes the first
//  milestone to text, a button and a stack.

import CiderUITree

/// Something that can describe part of a screen.
///
/// A view is a value. Cider asks for `body` whenever it believes state changed,
/// compares nothing, and rebuilds the whole tree. That is wasteful and entirely
/// adequate at this size; incremental rebuilds need a diffing story, and a
/// diffing story needs more than three node kinds to be designed against.
public protocol CiderView {
    associatedtype Body: CiderView

    @CiderViewBuilder
    var body: Body { get }

    /// Appends this view's nodes to the tree being built.
    ///
    /// Underscored because it is an implementation detail of the compatibility
    /// layer, not something an application overrides. Primitives implement it;
    /// every other view inherits the default, which lowers its `body`.
    func _lower(into context: LoweringContext)
}

public extension CiderView {
    func _lower(into context: LoweringContext) {
        body._lower(into: context)
    }
}

/// Lets a primitive declare that it has no body.
///
/// `Never` can conform because its `body` can never actually be called: there is
/// no value of type `Never` to call it on.
extension Never: CiderView {
    public typealias Body = Never

    public var body: Never {
        fatalError("Never has no body")
    }
}

/// A view that contributes nothing.
public struct EmptyView: CiderView {
    public typealias Body = Never

    public init() {}

    public var body: Never { fatalError("EmptyView has no body") }

    public func _lower(into context: LoweringContext) {}
}

/// The result of a multi-statement view block.
///
/// Children are held as existentials rather than as a generic parameter pack.
/// A pack would avoid the allocation, but it makes every container's type
/// signature depend on its contents, and at this scale the allocation is not
/// worth the complexity it buys.
public struct ViewList: CiderView {
    public typealias Body = Never

    let children: [any CiderView]

    public init(_ children: [any CiderView]) {
        self.children = children
    }

    public var body: Never { fatalError("ViewList has no body") }

    public func _lower(into context: LoweringContext) {
        for child in children {
            child._lower(into: context)
        }
    }
}

/// Assembles the views written inside a container's braces.
@resultBuilder
public enum CiderViewBuilder {

    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    /// A single view passes through unchanged.
    ///
    /// This overload is not just an optimisation. Without it, a body consisting
    /// of one expression would always be wrapped in a `ViewList`, and a
    /// primitive declaring `var body: Never { fatalError(...) }` would fail to
    /// type-check because the builder would try to turn its `Never` into a list.
    public static func buildBlock<Content: CiderView>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock(_ components: any CiderView...) -> ViewList {
        ViewList(components)
    }

    /// `if` without `else`.
    public static func buildOptional(_ component: (any CiderView)?) -> ViewList {
        ViewList(component.map { [$0] } ?? [])
    }

    public static func buildEither(first component: any CiderView) -> ViewList {
        ViewList([component])
    }

    public static func buildEither(second component: any CiderView) -> ViewList {
        ViewList([component])
    }

    /// `for ... in` inside a view block.
    public static func buildArray(_ components: [any CiderView]) -> ViewList {
        ViewList(components)
    }

    public static func buildExpression<Content: CiderView>(_ expression: Content) -> Content {
        expression
    }
}
