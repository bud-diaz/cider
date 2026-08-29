//  Lowering: application views to normalized UI tree.
//
//  This is the seam docs/03-technical-architecture.md section D asks for. Above
//  it, an API designed for people to write. Below it, a tree designed for
//  machines to lay out, draw, hit-test and compare. Neither has to compromise
//  for the other.

import CiderCore
import CiderRuntime
import CiderUITree

/// Accumulates nodes and actions while a view tree is walked.
///
/// A class rather than an `inout` struct because lowering recurses through
/// existential views, and passing `inout` through an existential call is
/// awkward enough to distort the API for no benefit.
public final class LoweringContext {

    /// Handlers for interactive nodes, keyed by the node's identity.
    public private(set) var actions: [NodeID: ActionHandler] = [:]

    /// Handlers for editable nodes, keyed by the node's identity.
    public private(set) var textInputHandlers: [NodeID: TextInputHandler] = [:]

    /// Where each node was written, keyed by the node's identity.
    ///
    /// Only nodes a developer actually wrote appear here. The synthetic
    /// wrappers below (`/wrap`, `/rows`, `/screen`, and the root stack this
    /// file's `scene` builds) are deliberately absent: they have no call site,
    /// and attributing the parent's to them would aim an edit at an expression
    /// that does not contain the value.
    public private(set) var origins: [NodeID: NodeOrigins] = [:]

    /// The container chain from the root down to where nodes are being emitted.
    private var parents: [NodeID] = [.root]

    /// Nodes collected at each open level.
    private var levels: [[UINode]] = [[]]

    init() {}

    /// The identity the next node emitted at this level will get.
    ///
    /// Identity is the child's index within its parent, so rebuilding an
    /// unchanged structure reproduces exactly the same identities -- which is
    /// what lets a pressed button survive a state change.
    public func reserveIdentity() -> NodeID {
        parents[parents.count - 1].child(levels[levels.count - 1].count)
    }

    public func emit(_ node: UINode) {
        levels[levels.count - 1].append(node)
    }

    /// Opens a container, runs `body`, and returns the children it emitted.
    public func withChildren(of id: NodeID, _ body: () -> Void) -> [UINode] {
        parents.append(id)
        levels.append([])
        body()
        let children = levels.removeLast()
        parents.removeLast()
        return children
    }

    public func register(action: @escaping ActionHandler, for id: NodeID) {
        actions[id] = action
    }

    public func register(textInputHandler: @escaping TextInputHandler, for id: NodeID) {
        textInputHandlers[id] = textInputHandler
    }

    public func register(origins nodeOrigins: NodeOrigins, for id: NodeID) {
        origins[id] = nodeOrigins
    }

    /// Nodes emitted at the top level.
    fileprivate var topLevelNodes: [UINode] {
        levels[0]
    }
}

public enum Lowering {

    /// Lowers a view into the scene the runtime consumes.
    ///
    /// A view that produces several top-level nodes is wrapped in a stack. That
    /// is a decision, not an accident: the runtime's root takes one node, and
    /// silently dropping the extras -- or refusing to run -- would both be worse
    /// than the obvious interpretation.
    public static func scene(from view: some CiderView) -> ApplicationScene {
        let context = LoweringContext()
        view._lower(into: context)

        let nodes = context.topLevelNodes
        let root: UINode
        switch nodes.count {
        case 0:
            // Nothing to draw. An empty stack renders as a blank screen, which is
            // the honest result of an empty body.
            root = .vstack(
                VStackNode(id: .root, spacing: 0, alignment: .center, children: [])
            )
        case 1:
            root = nodes[0]
        default:
            root = .vstack(
                VStackNode(
                    id: .root,
                    spacing: Theme.stackSpacing,
                    alignment: .center,
                    children: nodes
                )
            )
        }

        return ApplicationScene(
            root: root,
            actions: context.actions,
            textInputHandlers: context.textInputHandlers,
            origins: context.origins
        )
    }
}
