//  The contract between the runtime and whatever is running in it.
//
//  Note what is *not* here: no view types, no property wrappers, no result
//  builders. The runtime drives something that can describe itself as a UI tree
//  and can be told when it launched or stopped. The declarative API developers
//  write against sits above this, in CiderUI, and could be replaced without the
//  runtime noticing.

import CiderCore
import CiderUITree

/// What runs when a button is tapped.
public typealias ActionHandler = () -> Void

/// One frame's description of an application: a tree, and the actions its
/// interactive nodes invoke.
///
/// Actions travel beside the tree rather than inside it so that `UINode` stays
/// comparable, printable and free of captured state.
public struct ApplicationScene {
    public var root: UINode
    public var actions: [NodeID: ActionHandler]

    public init(root: UINode, actions: [NodeID: ActionHandler] = [:]) {
        self.root = root
        self.actions = actions
    }
}

/// The application lifecycle states Cider models. FR-002 in
/// docs/02-product-requirements.md.
///
/// `background` has no transitions into it yet -- backgrounding is Stage 3 work --
/// but the case exists so that code switching over the state is written against
/// the real set from the start.
public enum ApplicationState: String, Sendable, Equatable, CaseIterable {
    case notRunning
    case launching
    case foreground
    case background
    case terminated
}

/// Implemented by the compatibility layer, not by application authors.
public protocol RuntimeApplication: AnyObject {
    /// Called once, after the runtime is initialised and before the first frame.
    /// The context is retained by the application for the rest of its life.
    func didLaunch(context: RuntimeContext)

    /// Produces the current frame. Called whenever the runtime believes the
    /// application's state may have changed; it must be cheap and free of side
    /// effects beyond building the tree.
    func makeScene() -> ApplicationScene

    /// Called once before the process exits.
    func willTerminate()
}

public extension RuntimeApplication {
    func didLaunch(context: RuntimeContext) {}
    func willTerminate() {}
}
