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

/// The MVP node set. Deliberately three cases: docs/05-implementation-roadmap.md
/// puts scrolling, lists, navigation and modals in Stage 2, and adding them now
/// would mean designing layout for constraints no one has exercised yet.
public indirect enum UINode: Equatable, Sendable {
    case text(TextNode)
    case button(ButtonNode)
    case vstack(VStackNode)

    public var id: NodeID {
        switch self {
        case .text(let node): return node.id
        case .button(let node): return node.id
        case .vstack(let node): return node.id
        }
    }

    public var children: [UINode] {
        switch self {
        case .vstack(let node): return node.children
        case .text, .button: return []
        }
    }

    /// The node kind, as the inspector and diagnostics name it.
    public var kindName: String {
        switch self {
        case .text: return "TextNode"
        case .button: return "ButtonNode"
        case .vstack: return "VStackNode"
        }
    }
}
