//  A push/pop stack of screens.
//
//  There is no `NavigationLink`: pushing and popping are just mutations of
//  the bound path through an ordinary `Button` action -- `path.wrappedValue
//  .append(...)`/`.removeLast()` -- the same way any other state change is
//  expressed. A dedicated push view would only wrap that one line.

import CiderCore
import CiderUITree

public struct NavigationView<Root: CiderView>: CiderView {
    public typealias Body = Never

    private let path: CiderState<[any CiderView]>
    private let root: Root

    // Where this view came from. See `SourceOrigin`. Which screen is showing
    // is bound state, so nothing on this node has a source form.
    private var origins: SourceOriginTable

    /// `path` holds the screens pushed on top of `root`, in push order --
    /// empty means `root` is showing. It lives on the app, the same reason
    /// `TextField`'s bound text does: `CiderAppAdapter.attachState` only
    /// wires invalidation for an app's own `@CiderState` properties, not for
    /// state nested inside a view, so the stack has to be owned there and
    /// handed down as a binding.
    public init(
        _ path: CiderState<[any CiderView]>,
        @CiderViewBuilder root: () -> Root,
        file: String = #filePath,
        line: Int = #line,
        column: Int = #column
    ) {
        self.path = path
        self.root = root()
        self.origins = SourceOriginTable(file: file, line: line, column: column)
    }

    public var body: Never { fatalError("NavigationView has no body") }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        let activeScreen: any CiderView = path.wrappedValue.last ?? root
        let screenNodes = context.withChildren(of: id) {
            activeScreen._lower(into: context)
        }

        // Wrapped the same way `Lowering.scene` wraps the app's own top
        // level: `NavigationStackNode.content` is declared to hold exactly
        // one node, but a screen built from a multi-statement
        // `@CiderViewBuilder` body can emit more than one.
        let content: UINode
        switch screenNodes.count {
        case 1:
            content = screenNodes[0]
        default:
            content = .vstack(
                VStackNode(
                    id: NodeID(path: "\(id.path)/screen"),
                    spacing: Theme.stackSpacing,
                    alignment: .center,
                    children: screenNodes
                )
            )
        }

        context.emit(.navigationStack(NavigationStackNode(id: id, content: content)))
        // The synthetic "/screen" wrapper above has no call site, so only the
        // navigation view itself gets an origin.
        context.register(origins: origins.nodeOrigins, for: id)
    }
}
