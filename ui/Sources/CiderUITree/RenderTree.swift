//  The render tree: a flat, ordered list of draw commands plus hit regions.
//
//  Flattening the placed tree here, rather than walking the node tree while
//  drawing, buys three things: painter's order becomes explicit, hit testing is
//  a reverse scan over a list instead of a tree walk, and a frame can be
//  compared or printed without a text engine in hand.

import CiderCore

/// One drawing operation, in logical points. The rasterizer converts to pixels.
public enum RenderCommand: Equatable, Sendable {
    /// A filled rectangle. `cornerRadius` of 0 means square corners.
    case fillRect(rect: Rect, color: Color, cornerRadius: Double)

    /// A run of text. `baselineOrigin` is the left end of the baseline.
    case text(
        content: String,
        baselineOrigin: Point,
        font: FontRequest,
        color: Color
    )

    /// A bitmap, placed at `rect`.
    case image(rect: Rect, source: ImageSource)

    /// Intersects `rect` with whatever is currently clipped and makes the
    /// result active for every command up to the matching `popClip`. Nothing
    /// emits this yet -- it exists for the scroll viewport and modal overlay
    /// work later in Stage 2 -- but the rasterizer honours it now, so those
    /// node kinds are a `RenderTreeBuilder` change, not a rasterizer change.
    case pushClip(rect: Rect)

    /// Restores the clip that was active before the matching `pushClip`.
    case popClip
}

/// An area that can receive a touch, and the node it belongs to.
public struct HitRegion: Equatable, Sendable {
    public var id: NodeID
    public var frame: Rect
    public var isEnabled: Bool

    public init(id: NodeID, frame: Rect, isEnabled: Bool) {
        self.id = id
        self.frame = frame
        self.isEnabled = isEnabled
    }
}

/// One frame's worth of work.
public struct RenderTree: Equatable, Sendable {
    public var backgroundColor: Color
    public var commands: [RenderCommand]
    public var hitRegions: [HitRegion]

    public init(
        backgroundColor: Color,
        commands: [RenderCommand] = [],
        hitRegions: [HitRegion] = []
    ) {
        self.backgroundColor = backgroundColor
        self.commands = commands
        self.hitRegions = hitRegions
    }

    /// Returns the topmost enabled region containing `point`.
    ///
    /// Later commands paint over earlier ones, so the scan runs backwards: what
    /// the user sees on top is what they hit.
    public func hitTest(_ point: Point) -> NodeID? {
        for region in hitRegions.reversed() where region.isEnabled && region.frame.contains(point) {
            return region.id
        }
        return nil
    }
}

/// Turns a node tree plus its layout into a render tree.
public enum RenderTreeBuilder {

    public static func build(
        node: UINode,
        layout: LayoutBox,
        backgroundColor: Color,
        pressedNode: NodeID? = nil,
        context: LayoutContext
    ) -> RenderTree {
        var tree = RenderTree(backgroundColor: backgroundColor)
        append(node: node, layout: layout, pressedNode: pressedNode, context: context, into: &tree)
        return tree
    }

    private static func append(
        node: UINode,
        layout: LayoutBox,
        pressedNode: NodeID?,
        context: LayoutContext,
        into tree: inout RenderTree
    ) {
        switch node {
        case .text(let text):
            let metrics = context.textEngine.metrics(for: text.font)
            tree.commands.append(
                .text(
                    content: text.text,
                    baselineOrigin: Point(x: layout.frame.minX, y: layout.frame.minY + metrics.ascent),
                    font: text.font,
                    color: text.color
                )
            )

        case .button(let button):
            let isPressed = button.isEnabled && pressedNode == button.id
            tree.commands.append(
                .fillRect(
                    rect: layout.frame,
                    color: isPressed ? button.pressedBackgroundColor : button.backgroundColor,
                    cornerRadius: button.cornerRadius
                )
            )

            // Centre the label in the button box rather than relying on the
            // padding being symmetric, so an asymmetric padding still looks
            // deliberate.
            let run = context.textEngine.shape(button.title, font: button.font)
            let metrics = run.metrics
            let textX = layout.frame.minX + (layout.frame.width - run.width) / 2
            let textY = layout.frame.midY - metrics.lineHeight / 2 + metrics.ascent

            tree.commands.append(
                .text(
                    content: button.title,
                    baselineOrigin: Point(x: textX, y: textY),
                    font: button.font,
                    color: button.titleColor
                )
            )

            tree.hitRegions.append(
                HitRegion(id: button.id, frame: layout.frame, isEnabled: button.isEnabled)
            )

        case .vstack(let stack):
            for (child, childLayout) in zip(stack.children, layout.children) {
                append(
                    node: child,
                    layout: childLayout,
                    pressedNode: pressedNode,
                    context: context,
                    into: &tree
                )
            }

        case .image(let image):
            tree.commands.append(.image(rect: layout.frame, source: image.source))
        }
    }
}
