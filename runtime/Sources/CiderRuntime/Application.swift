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

/// What runs when a focused text field's content changes, with the field's
/// new text.
public typealias TextInputHandler = (String) -> Void

/// One frame's description of an application: a tree, the actions its
/// interactive nodes invoke, and the handlers its editable nodes invoke on a
/// change.
///
/// Actions and text handlers travel beside the tree rather than inside it so
/// that `UINode` stays comparable, printable and free of captured state.
public struct ApplicationScene {
    public var root: UINode
    public var actions: [NodeID: ActionHandler]
    public var textInputHandlers: [NodeID: TextInputHandler]

    /// Where each node, and each value on it, was written.
    ///
    /// Empty for a scene built by anything that does not record origins, and
    /// missing for nodes nobody wrote -- the synthetic wrappers a `ScrollView`,
    /// `List`, `NavigationView` or `Modal` emits around their content have no
    /// call site of their own, and reporting the parent's would point an edit
    /// at the wrong expression.
    public var origins: [NodeID: NodeOrigins]

    public init(
        root: UINode,
        actions: [NodeID: ActionHandler] = [:],
        textInputHandlers: [NodeID: TextInputHandler] = [:],
        origins: [NodeID: NodeOrigins] = [:]
    ) {
        self.root = root
        self.actions = actions
        self.textInputHandlers = textInputHandlers
        self.origins = origins
    }
}

/// The application lifecycle states Cider models. FR-002 in
/// docs/02-product-requirements.md.
///
/// `background` is reached via `ApplicationRuntime.enterBackground()`, a
/// Stage 3 simulated transition (there is no real OS app-switcher signal on
/// Linux yet).
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

    /// Called when `ApplicationRuntime.enterBackground()` transitions the app
    /// from `.foreground` to `.background`.
    func didEnterBackground()

    /// Called when `ApplicationRuntime.enterForeground()` transitions the app
    /// from `.background` to `.foreground`.
    func didEnterForeground()
}

public extension RuntimeApplication {
    func didLaunch(context: RuntimeContext) {}
    func willTerminate() {}
    func didEnterBackground() {}
    func didEnterForeground() {}
}
