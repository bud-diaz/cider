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
    /// result active for every command up to the matching `popClip`. Emitted
    /// around a scroll view's content, and later around a modal's overlay.
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

    /// Scroll viewports, at their on-screen frame (not their content's,
    /// which can be larger). A separate list from `hitRegions` because a
    /// scroll notch and a tap answer different questions: a tap wants the
    /// topmost *interactive* thing under a point, a scroll wants the topmost
    /// *scrollable* thing under a point, and a button is never both.
    public var scrollRegions: [HitRegion]

    public init(
        backgroundColor: Color,
        commands: [RenderCommand] = [],
        hitRegions: [HitRegion] = [],
        scrollRegions: [HitRegion] = []
    ) {
        self.backgroundColor = backgroundColor
        self.commands = commands
        self.hitRegions = hitRegions
        self.scrollRegions = scrollRegions
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

    /// Returns the topmost scroll view containing `point`, the same
    /// reversed-scan reasoning as `hitTest`: a nested scroll view painted
    /// last is the one closest to the pointer.
    public func scrollTarget(at point: Point) -> NodeID? {
        for region in scrollRegions.reversed() where region.isEnabled && region.frame.contains(point) {
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
        scrollOffsets: [NodeID: Point] = [:],
        context: LayoutContext
    ) -> RenderTree {
        var tree = RenderTree(backgroundColor: backgroundColor)
        append(
            node: node,
            layout: layout,
            pressedNode: pressedNode,
            scrollOffsets: scrollOffsets,
            offset: .zero,
            clip: nil,
            context: context,
            into: &tree
        )
        return tree
    }

    /// `offset` accumulates the scroll displacement of every scroll-view
    /// ancestor, so a frame drawn deep inside one (or several nested ones)
    /// still lands where the user actually sees it. Layout never sees this --
    /// it computes each node's *unscrolled* frame once; shifting that frame
    /// by however much its container is currently scrolled happens here,
    /// every frame, the same way a button's pressed color is decided here and
    /// not baked into layout.
    ///
    /// `clip` is the intersection of every scroll-view ancestor's viewport,
    /// or `nil` when nothing has clipped yet. It exists so hit-testing agrees
    /// with what's actually drawn: `Rasterizer` already refuses to paint a
    /// pixel outside the active clip via `pushClip`/`popClip`, and a hit
    /// region that ignored the same clip would make a button scrolled out of
    /// view still tappable at its old, invisible position.
    private static func append(
        node: UINode,
        layout: LayoutBox,
        pressedNode: NodeID?,
        scrollOffsets: [NodeID: Point],
        offset: Point,
        clip: Rect?,
        context: LayoutContext,
        into tree: inout RenderTree
    ) {
        switch node {
        case .text(let text):
            let metrics = context.textEngine.metrics(for: text.font)
            let frame = layout.frame.offsetBy(dx: offset.x, dy: offset.y)
            tree.commands.append(
                .text(
                    content: text.text,
                    baselineOrigin: Point(x: frame.minX, y: frame.minY + metrics.ascent),
                    font: text.font,
                    color: text.color
                )
            )

        case .button(let button):
            let frame = layout.frame.offsetBy(dx: offset.x, dy: offset.y)
            let isPressed = button.isEnabled && pressedNode == button.id
            tree.commands.append(
                .fillRect(
                    rect: frame,
                    color: isPressed ? button.pressedBackgroundColor : button.backgroundColor,
                    cornerRadius: button.cornerRadius
                )
            )

            // Centre the label in the button box rather than relying on the
            // padding being symmetric, so an asymmetric padding still looks
            // deliberate.
            let run = context.textEngine.shape(button.title, font: button.font)
            let metrics = run.metrics
            let textX = frame.minX + (frame.width - run.width) / 2
            let textY = frame.midY - metrics.lineHeight / 2 + metrics.ascent

            tree.commands.append(
                .text(
                    content: button.title,
                    baselineOrigin: Point(x: textX, y: textY),
                    font: button.font,
                    color: button.titleColor
                )
            )

            // Clipped to whatever scroll viewport it's inside, if any, so a
            // button scrolled fully out of view (or half-clipped at the
            // viewport's edge) can't be hit outside what's actually visible.
            let hitFrame: Rect?
            if let clip {
                hitFrame = frame.intersection(clip)
            } else {
                hitFrame = frame
            }
            if let hitFrame {
                tree.hitRegions.append(
                    HitRegion(id: button.id, frame: hitFrame, isEnabled: button.isEnabled)
                )
            }

        case .vstack(let stack):
            for (child, childLayout) in zip(stack.children, layout.children) {
                append(
                    node: child,
                    layout: childLayout,
                    pressedNode: pressedNode,
                    scrollOffsets: scrollOffsets,
                    offset: offset,
                    clip: clip,
                    context: context,
                    into: &tree
                )
            }

        case .image(let image):
            let frame = layout.frame.offsetBy(dx: offset.x, dy: offset.y)
            tree.commands.append(.image(rect: frame, source: image.source))

        case .scrollView(let scroll):
            let viewportFrame = layout.frame.offsetBy(dx: offset.x, dy: offset.y)
            let effectiveViewport: Rect?
            if let clip {
                effectiveViewport = viewportFrame.intersection(clip)
            } else {
                effectiveViewport = viewportFrame
            }

            if let effectiveViewport {
                tree.scrollRegions.append(HitRegion(id: scroll.id, frame: effectiveViewport, isEnabled: true))
            }

            // Pushed unconditionally, even when this scroll view is itself
            // entirely clipped away: pushClip/popClip must stay balanced so a
            // later command in the tree is never left clipped by a push this
            // node never matched with a pop.
            tree.commands.append(.pushClip(rect: viewportFrame))
            if let effectiveViewport, let contentLayout = layout.children.first {
                let scrollOffset = scrollOffsets[scroll.id] ?? .zero
                let contentOffset = Point(x: offset.x - scrollOffset.x, y: offset.y - scrollOffset.y)
                append(
                    node: scroll.content,
                    layout: contentLayout,
                    pressedNode: pressedNode,
                    scrollOffsets: scrollOffsets,
                    offset: contentOffset,
                    clip: effectiveViewport,
                    context: context,
                    into: &tree
                )
            }
            tree.commands.append(.popClip)
        }
    }
}
