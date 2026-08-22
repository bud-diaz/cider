//  A full-screen modal presentation over some base content.
//
//  MVP scope, deliberately: the presented screen fills the same frame the
//  base content does -- a partial-height sheet is a real feature, not a
//  gap this file pretends doesn't exist, but it needs layout this pipeline
//  doesn't have yet (a proposed size smaller than the container, the way a
//  sheet's height is usually intrinsic to its content). Full-screen is the
//  smallest presentation that proves the pattern: overlay dimming, z-order,
//  tap-through blocking.

import CiderCore
import CiderUITree

public struct Modal<Base: CiderView, Presented: CiderView>: CiderView {
    public typealias Body = Never

    private let isPresented: CiderState<Bool>
    private let base: Base
    private let presented: Presented

    /// `isPresented` is a binding, the same convention `NavigationView`'s
    /// path and `TextField`'s text use: presentation state lives on the
    /// app (or wherever the binding's owner is) and is handed down, since
    /// `CiderAppAdapter.attachState` only wires invalidation for the app's
    /// own stored properties. There is no dismiss action baked in here --
    /// the presented content sets `isPresented.wrappedValue = false`
    /// itself, from an ordinary `Button`, the same way `NavigationView`'s
    /// pushed screens pop themselves.
    public init(
        _ isPresented: CiderState<Bool>,
        @CiderViewBuilder content: () -> Base,
        @CiderViewBuilder presenting: () -> Presented
    ) {
        self.isPresented = isPresented
        self.base = content()
        self.presented = presenting()
    }

    public var body: Never { fatalError("Modal has no body") }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()

        // Base and presented content each need their own numbering root --
        // reusing `id` for both `withChildren` calls would hand out the
        // same child paths ("id/0", "id/1", ...) to two different views.
        // `id.child(0)`/`id.child(1)` treat them as the modal's own two
        // structural slots, the same scheme any other container's children
        // already get, just split across the pair explicitly instead of a
        // single pass.
        let baseParent = id.child(0)
        let baseNodes = context.withChildren(of: baseParent) { base._lower(into: context) }
        let baseContent = Self.wrap(baseNodes, id: baseParent)

        var presentedContent: UINode?
        if isPresented.wrappedValue {
            let presentedParent = id.child(1)
            let presentedNodes = context.withChildren(of: presentedParent) { presented._lower(into: context) }
            presentedContent = Self.wrap(presentedNodes, id: presentedParent)
        }

        context.emit(
            .modal(
                ModalPresenterNode(
                    id: id,
                    content: baseContent,
                    presented: presentedContent,
                    overlayColor: Theme.modalOverlayColor
                )
            )
        )
    }

    /// Wraps a multi-node body the same way `Lowering.scene` wraps the
    /// app's own top level: `ModalPresenterNode.content`/`.presented` are
    /// each declared to hold exactly one node.
    private static func wrap(_ nodes: [UINode], id: NodeID) -> UINode {
        switch nodes.count {
        case 1:
            return nodes[0]
        default:
            return .vstack(
                VStackNode(id: id, spacing: Theme.stackSpacing, alignment: .center, children: nodes)
            )
        }
    }
}
