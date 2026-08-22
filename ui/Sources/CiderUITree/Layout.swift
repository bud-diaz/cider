//  The layout engine.
//
//  This is intentionally the smallest engine that lays out the MVP node set
//  correctly: measure bottom-up, then place top-down. There are no constraints,
//  no priorities and no second-guessing pass.
//
//  docs/05-implementation-roadmap.md warns against rebuilding a general
//  constraint solver before the node set that needs one exists. Three node kinds
//  do not need one, and a solver written now would be designed against guesses
//  rather than against scrolling, lists and navigation when those arrive.

import CiderCore

/// Everything layout needs from the outside world.
public struct LayoutContext {
    /// Used for measuring text. Layout never rasterizes.
    public let textEngine: TextEngine

    public init(textEngine: TextEngine) {
        self.textEngine = textEngine
    }
}

/// A placed node: absolute frame in logical points, plus placed children.
public struct LayoutBox: Equatable, Sendable {
    public var id: NodeID
    public var frame: Rect
    public var children: [LayoutBox]

    public init(id: NodeID, frame: Rect, children: [LayoutBox] = []) {
        self.id = id
        self.frame = frame
        self.children = children
    }
}

public enum LayoutEngine {

    /// Returns the size `node` wants, optionally within `proposedSize`.
    ///
    /// `proposedSize` is accepted but not yet consulted by any case: nothing in
    /// the current node set shrinks or wraps, so an unbounded measurement is
    /// still the whole story. The parameter exists so that scrolling, lists and
    /// text wrapping -- which do need to propose a size to a child -- are a
    /// change confined to the cases that care, not a signature change threaded
    /// through every call site again. The two-pass shape does not change.
    public static func measure(_ node: UINode, proposedSize: Size? = nil, context: LayoutContext) -> Size {
        switch node {
        case .text(let text):
            let run = context.textEngine.shape(text.text, font: text.font)
            return Size(width: run.width, height: run.metrics.lineHeight)

        case .button(let button):
            let run = context.textEngine.shape(button.title, font: button.font)
            return Size(
                width: run.width + button.padding.horizontal,
                height: run.metrics.lineHeight + button.padding.vertical
            )

        case .vstack(let stack):
            var width = 0.0
            var height = 0.0
            for (index, child) in stack.children.enumerated() {
                let size = measure(child, context: context)
                width = max(width, size.width)
                height += size.height
                if index < stack.children.count - 1 {
                    height += stack.spacing
                }
            }
            return Size(width: width, height: height)

        case .image(let image):
            return Size(width: Double(image.source.width), height: Double(image.source.height))

        case .scrollView(let scroll):
            // The viewport is explicit, not derived from content: a scroll
            // view's whole point is that its content can be larger than it.
            return scroll.viewportSize
        }
    }

    /// Places `node` at its measured size inside `bounds`, centred on both axes.
    ///
    /// The runtime uses this for the root: an application's content sits in the
    /// middle of the safe area. It is a placeholder for real root behaviour --
    /// filling, alignment modifiers and scrolling all belong to Stage 2 -- and it
    /// is documented as such so nobody mistakes it for a considered default.
    public static func layoutCentered(
        _ node: UINode,
        in bounds: Rect,
        context: LayoutContext
    ) -> LayoutBox {
        let size = measure(node, context: context)
        let origin = Point(
            x: bounds.minX + (bounds.width - size.width) / 2,
            y: bounds.minY + (bounds.height - size.height) / 2
        )
        return place(node, at: origin, size: size, context: context)
    }

    /// Places `node` with its top-left at `origin` and the given size.
    public static func place(
        _ node: UINode,
        at origin: Point,
        size: Size,
        context: LayoutContext
    ) -> LayoutBox {
        let frame = Rect(origin: origin, size: size)

        switch node {
        case .text, .button, .image:
            return LayoutBox(id: node.id, frame: frame)

        case .vstack(let stack):
            var children: [LayoutBox] = []
            children.reserveCapacity(stack.children.count)

            var y = origin.y
            for (index, child) in stack.children.enumerated() {
                let childSize = measure(child, context: context)
                let x: Double
                switch stack.alignment {
                case .leading:
                    x = origin.x
                case .center:
                    x = origin.x + (size.width - childSize.width) / 2
                case .trailing:
                    x = origin.x + size.width - childSize.width
                }

                children.append(
                    place(child, at: Point(x: x, y: y), size: childSize, context: context)
                )

                y += childSize.height
                if index < stack.children.count - 1 {
                    y += stack.spacing
                }
            }

            return LayoutBox(id: stack.id, frame: frame, children: children)

        case .scrollView(let scroll):
            // The content is placed at its own natural size, at the same
            // origin as the viewport -- this is the *unscrolled* reference
            // frame. Applying the current scroll offset is a render-tree
            // concern (RenderTreeBuilder), not a layout concern, the same way
            // a button's pressed appearance is: layout describes where things
            // are absent interaction, and offsetting every descendant frame
            // on every scroll tick would mean relaying out on every tick too.
            let contentSize = measure(scroll.content, context: context)
            let contentBox = place(scroll.content, at: origin, size: contentSize, context: context)
            return LayoutBox(id: scroll.id, frame: frame, children: [contentBox])
        }
    }
}

extension LayoutBox {
    /// Depth-first search for a placed node by identity.
    public func box(for id: NodeID) -> LayoutBox? {
        if self.id == id { return self }
        for child in children {
            if let found = child.box(for: id) { return found }
        }
        return nil
    }
}
