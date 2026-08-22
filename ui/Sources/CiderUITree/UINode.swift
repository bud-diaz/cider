//  The normalized UI tree.
//
//  Application view descriptions are lowered into this tree before anything is
//  measured or drawn. The indirection is the point: it gives layout, hit testing,
//  the inspector and the conformance tests one shape to work against, and it
//  keeps the application-facing API free to change without dragging the renderer
//  along. See docs/adr/0003-ui-tree-model.md.
//
//  The tree is *pure data*. In particular a button holds no closure -- it holds
//  its own identity, and the runtime keeps the table mapping identities to
//  actions. That is what lets a test compare two trees for equality and lets the
//  inspector print one.

import CiderCore

/// A node's identity, stable across rebuilds.
///
/// Identity is the path from the root: `root/0/1`. Two rebuilds of the same view
/// structure therefore produce the same identities, which is what makes it
/// possible to keep a pressed button pressed across a state change.
public struct NodeID: Hashable, Sendable, CustomStringConvertible {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    public static let root = NodeID(path: "root")

    /// Derives a child identity. Callers must pass the child's index within its
    /// parent so the result is deterministic.
    public func child(_ index: Int) -> NodeID {
        NodeID(path: "\(path)/\(index)")
    }

    public var description: String { path }
}

/// How a stack aligns children on its cross axis.
public enum HorizontalAlignment: String, Sendable, Equatable, CaseIterable {
    case leading
    case center
    case trailing
}

/// A run of text.
public struct TextNode: Equatable, Sendable {
    public var id: NodeID
    public var text: String
    public var font: FontRequest
    public var color: Color

    public init(id: NodeID, text: String, font: FontRequest, color: Color) {
        self.id = id
        self.text = text
        self.font = font
        self.color = color
    }
}

/// A tappable control with a text label.
///
/// `isEnabled` is carried here rather than inferred from the presence of an
/// action, because a disabled button still occupies space and still draws.
public struct ButtonNode: Equatable, Sendable {
    public var id: NodeID
    public var title: String
    public var font: FontRequest
    public var titleColor: Color
    public var backgroundColor: Color
    public var pressedBackgroundColor: Color
    public var cornerRadius: Double
    public var padding: EdgeInsets
    public var isEnabled: Bool

    public init(
        id: NodeID,
        title: String,
        font: FontRequest,
        titleColor: Color,
        backgroundColor: Color,
        pressedBackgroundColor: Color,
        cornerRadius: Double,
        padding: EdgeInsets,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.font = font
        self.titleColor = titleColor
        self.backgroundColor = backgroundColor
        self.pressedBackgroundColor = pressedBackgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isEnabled = isEnabled
    }
}

/// A bitmap, already decoded. See `ImageSource`'s doc comment for why there is
/// no decoder here.
public struct ImageNode: Equatable, Sendable {
    public var id: NodeID
    public var source: ImageSource

    public init(id: NodeID, source: ImageSource) {
        self.id = id
        self.source = source
    }
}

/// A vertical stack of children.
public struct VStackNode: Equatable, Sendable {
    public var id: NodeID
    public var spacing: Double
    public var alignment: HorizontalAlignment
    public var children: [UINode]

    public init(
        id: NodeID,
        spacing: Double,
        alignment: HorizontalAlignment,
        children: [UINode]
    ) {
        self.id = id
        self.spacing = spacing
        self.alignment = alignment
        self.children = children
    }
}

/// A scrollable viewport over a single child that may be larger than it.
///
/// `viewportSize` is explicit rather than inherited from a parent's proposed
/// size: `LayoutEngine.measure`'s `proposedSize` parameter exists but nothing
/// consults it yet (see its doc comment), and the root layout path
/// (`layoutCentered`) doesn't propose one at all. An explicit size is the
/// honest MVP scope -- "fill the space my parent gives me" is real work
/// `layoutCentered`'s own doc comment already flags as a placeholder Stage 2
/// needs to replace, and that replacement is B7's job, not this one's.
public struct ScrollViewNode: Equatable, Sendable {
    public var id: NodeID
    public var viewportSize: Size
    public var content: UINode

    public init(id: NodeID, viewportSize: Size, content: UINode) {
        self.id = id
        self.viewportSize = viewportSize
        self.content = content
    }
}

/// A single line of editable text, bound to application state.
///
/// Carries its *current* text as plain data, the same way `TextNode` does --
/// not a closure, not a binding. Editing flows through the same side-channel
/// as a button's action: `LoweringContext.register(textInputHandler:for:)`
/// gives the runtime a `(String) -> Void` it can call without knowing what
/// `@CiderState` property is on the other end of it.
public struct TextFieldNode: Equatable, Sendable {
    public var id: NodeID
    public var text: String
    public var font: FontRequest
    public var textColor: Color
    public var backgroundColor: Color
    public var cornerRadius: Double
    public var padding: EdgeInsets
    public var width: Double

    public init(
        id: NodeID,
        text: String,
        font: FontRequest,
        textColor: Color,
        backgroundColor: Color,
        cornerRadius: Double,
        padding: EdgeInsets,
        width: Double
    ) {
        self.id = id
        self.text = text
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.width = width
    }
}

/// docs/05-implementation-roadmap.md Stage 2 adds scrolling, lists,
/// navigation and modals on top of the Stage 0/1 set (text, button, stack);
/// `image`, `scrollView` and `textField` are the first three of those to
/// land. Per docs/adr/0003-ui-tree-model.md, adding a node kind means
/// touching this type, `LayoutEngine.measure`, `LayoutEngine.place`,
/// `RenderTreeBuilder` and `Inspector` -- five places, deliberately, each an
/// exhaustive switch with no `default:`.
public indirect enum UINode: Equatable, Sendable {
    case text(TextNode)
    case button(ButtonNode)
    case vstack(VStackNode)
    case image(ImageNode)
    case scrollView(ScrollViewNode)
    case textField(TextFieldNode)

    public var id: NodeID {
        switch self {
        case .text(let node): return node.id
        case .button(let node): return node.id
        case .vstack(let node): return node.id
        case .image(let node): return node.id
        case .scrollView(let node): return node.id
        case .textField(let node): return node.id
        }
    }

    public var children: [UINode] {
        switch self {
        case .vstack(let node): return node.children
        case .scrollView(let node): return [node.content]
        case .text, .button, .image, .textField: return []
        }
    }

    /// The node kind, as the inspector and diagnostics name it.
    public var kindName: String {
        switch self {
        case .text: return "TextNode"
        case .button: return "ButtonNode"
        case .vstack: return "VStackNode"
        case .image: return "ImageNode"
        case .scrollView: return "ScrollViewNode"
        case .textField: return "TextFieldNode"
        }
    }

    /// Depth-first search for a node by identity. The runtime uses this to
    /// read a text field's *current* text when a key arrives -- the tree is
    /// the only place that value lives; nothing keeps a separate copy.
    public func find(_ id: NodeID) -> UINode? {
        if self.id == id { return self }
        for child in children {
            if let found = child.find(id) { return found }
        }
        return nil
    }
}
