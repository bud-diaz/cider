//  Developer-facing inspection of runtime state.
//
//  Stage 4 of docs/05-implementation-roadmap.md describes a real inspector with
//  a network viewer and a storage browser. This is not that. It is the smallest
//  thing that makes the vertical slice debuggable: a textual dump of what the
//  runtime believes it is showing, which turns "the button is in the wrong
//  place" from a screenshot argument into a diff.
//
//  The runtime works identically with inspection disabled; nothing here may
//  affect layout, rendering or input.

import Foundation

import CiderCore
import CiderUITree


public struct InspectorRectSnapshot: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(_ rect: Rect) {
        self.x = rect.minX
        self.y = rect.minY
        self.width = rect.width
        self.height = rect.height
    }
}

/// One editable-or-not property of a node, as the developer console shows it.
///
/// `label` collapses a node into a single display string, which is enough to
/// read a tree and not enough to edit one. This carries the same information
/// taken apart: a name the editor can address, a type that decides which
/// control to draw, and whether the value is something an application could
/// have written in the first place.
public struct InspectorPropertySnapshot: Codable, Equatable, Sendable {
    /// Addressable name, matching the node field: "fontSize", "cornerRadius".
    public var name: String

    /// One of "string", "double", "color", "bool", "enum". Decides the control.
    public var type: String

    /// Formatted the same way the textual dump formats it -- one decimal for a
    /// double, `#RRGGBBAA` for a colour -- so both views of a node agree.
    public var value: String

    /// The cases, when `type` is "enum". Nil otherwise.
    public var options: [String]?

    /// Whether this value has a form an application could have written. False
    /// for values the runtime derives or the application binds.
    public var editable: Bool

    /// Why an uneditable property is uneditable. An editor that hides what it
    /// cannot change is harder to trust than one that says why.
    public var note: String?

    /// Where this value was written, when it was written at all.
    ///
    /// Nil means nobody wrote it: it came from `Theme` or from an
    /// initializer's default. That is the difference between an edit that
    /// rewrites an argument and one that has to insert a call.
    public var origin: SourceOrigin?

    public init(
        name: String,
        type: String,
        value: String,
        options: [String]? = nil,
        editable: Bool,
        note: String? = nil,
        origin: SourceOrigin? = nil
    ) {
        self.name = name
        self.type = type
        self.value = value
        self.options = options
        self.editable = editable
        self.note = note
        self.origin = origin
    }
}

public struct InspectorNodeSnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var label: String
    public var frame: InspectorRectSnapshot?
    public var depth: Int

    /// Optional so that a snapshot written before this field existed still
    /// decodes, and so a reader can tell "no properties" from "an older
    /// producer".
    public var properties: [InspectorPropertySnapshot]?

    /// Where the view that produced this node was constructed.
    ///
    /// Nil for the synthetic wrappers `ScrollView`, `List`, `NavigationView`
    /// and `Modal` put around their content, and for the root stack lowering
    /// builds for a multi-node body. Nobody wrote those, so there is nothing to
    /// point an edit at.
    public var origin: SourceOrigin?

    /// The name of the view type that produced this node, when one is known.
    ///
    /// Not the same as `kind`: a `List` lowers to a `ScrollViewNode`, so an
    /// editor working from the kind alone would look for the wrong expression
    /// in the source.
    public var view: String?

    public init(
        id: String,
        kind: String,
        label: String,
        frame: InspectorRectSnapshot?,
        depth: Int,
        properties: [InspectorPropertySnapshot]? = nil,
        origin: SourceOrigin? = nil,
        view: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.frame = frame
        self.depth = depth
        self.properties = properties
        self.origin = origin
        self.view = view
    }
}

public struct InspectorRenderCommandSnapshot: Codable, Equatable, Sendable {
    public var index: Int
    public var kind: String
    public var summary: String
    public var frame: InspectorRectSnapshot?

    public init(index: Int, kind: String, summary: String, frame: InspectorRectSnapshot?) {
        self.index = index
        self.kind = kind
        self.summary = summary
        self.frame = frame
    }
}

public struct InspectorHitRegionSnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var frame: InspectorRectSnapshot
    public var isEnabled: Bool

    public init(id: String, frame: InspectorRectSnapshot, isEnabled: Bool) {
        self.id = id
        self.frame = frame
        self.isEnabled = isEnabled
    }
}

public struct InspectorSnapshot: Codable, Equatable, Sendable {
    public var frameCount: Int
    public var generatedAtMilliseconds: Int64
    public var nodes: [InspectorNodeSnapshot]
    public var renderCommands: [InspectorRenderCommandSnapshot]
    public var hitRegions: [InspectorHitRegionSnapshot]

    public init(
        frameCount: Int,
        generatedAtMilliseconds: Int64,
        nodes: [InspectorNodeSnapshot],
        renderCommands: [InspectorRenderCommandSnapshot],
        hitRegions: [InspectorHitRegionSnapshot]
    ) {
        self.frameCount = frameCount
        self.generatedAtMilliseconds = generatedAtMilliseconds
        self.nodes = nodes
        self.renderCommands = renderCommands
        self.hitRegions = hitRegions
    }
}

public enum Inspector {


    public static func snapshot(
        node: UINode,
        layout: LayoutBox?,
        renderTree: RenderTree?,
        frameCount: Int,
        origins: [NodeID: NodeOrigins] = [:],
        generatedAtMilliseconds: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> InspectorSnapshot {
        var nodes: [InspectorNodeSnapshot] = []
        collect(node: node, layout: layout, depth: 0, origins: origins, into: &nodes)
        let commands = renderTree?.commands.enumerated().map { index, command in
            renderCommandSnapshot(index: index, command: command)
        } ?? []
        let hits = renderTree?.hitRegions.map {
            InspectorHitRegionSnapshot(id: $0.id.description, frame: InspectorRectSnapshot($0.frame), isEnabled: $0.isEnabled)
        } ?? []
        return InspectorSnapshot(
            frameCount: frameCount,
            generatedAtMilliseconds: generatedAtMilliseconds,
            nodes: nodes,
            renderCommands: commands,
            hitRegions: hits
        )
    }

    public static func json(_ snapshot: InspectorSnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        return String(decoding: data, as: UTF8.self)
    }


    /// Renders the node tree with each node's placed frame beside it.
    ///
    /// Example:
    ///
    ///     VStackNode  root  (120.0, 380.0, 150.0x84.0)
    ///       TextNode  root/0  (145.5, 380.0, 99.0x20.4)  "Cider Demo"
    public static func describe(node: UINode, layout: LayoutBox?, indent: Int = 0) -> String {
        let padding = String(repeating: "  ", count: indent)
        let frame = layout.map { format($0.frame) } ?? "(unplaced)"

        var line = "\(padding)\(node.kindName)  \(node.id)  \(frame)"
        switch node {
        case .text(let text):
            line += "  \(quoted(text.text))"
        case .button(let button):
            line += "  \(quoted(button.title))\(button.isEnabled ? "" : "  disabled")"
        case .vstack(let stack):
            line += "  spacing=\(format(stack.spacing)) alignment=\(stack.alignment.rawValue)"
        case .image(let image):
            line += "  \(image.source.width)x\(image.source.height)"
        case .scrollView(let scroll):
            line += "  viewport=\(format(scroll.viewportSize.width))x\(format(scroll.viewportSize.height))"
        case .textField(let field):
            line += "  \(quoted(field.text))"
        case .navigationStack:
            break
        case .modal(let modal):
            line += "  presenting=\(modal.presented != nil)"
        }

        var lines = [line]
        let childLayouts = layout?.children ?? []
        for (index, child) in node.children.enumerated() {
            let childLayout = index < childLayouts.count ? childLayouts[index] : nil
            lines.append(describe(node: child, layout: childLayout, indent: indent + 1))
        }
        return lines.joined(separator: "\n")
    }

    /// Summarises a render tree: what will be drawn, in painter's order.
    public static func describe(renderTree: RenderTree) -> String {
        var lines = ["background \(format(renderTree.backgroundColor))"]

        for (index, command) in renderTree.commands.enumerated() {
            switch command {
            case .fillRect(let rect, let color, let cornerRadius):
                lines.append(
                    "\(index)  fillRect \(format(rect)) \(format(color)) radius=\(format(cornerRadius))"
                )
            case .text(let content, let origin, let font, let color):
                lines.append(
                    "\(index)  text \(quoted(content)) baseline=\(format(origin)) "
                        + "size=\(format(font.size)) weight=\(font.weight.rawValue) \(format(color))"
                )
            case .image(let rect, let source):
                lines.append("\(index)  image \(format(rect)) \(source.width)x\(source.height)")
            case .pushClip(let rect):
                lines.append("\(index)  pushClip \(format(rect))")
            case .popClip:
                lines.append("\(index)  popClip")
            }
        }

        for region in renderTree.hitRegions {
            lines.append("hit  \(region.id)  \(format(region.frame))\(region.isEnabled ? "" : "  disabled")")
        }

        return lines.joined(separator: "\n")
    }


    private static func collect(
        node: UINode,
        layout: LayoutBox?,
        depth: Int,
        origins: [NodeID: NodeOrigins],
        into nodes: inout [InspectorNodeSnapshot]
    ) {
        let nodeOrigins = origins[node.id]
        nodes.append(
            InspectorNodeSnapshot(
                id: node.id.description,
                kind: node.kindName,
                label: label(for: node),
                frame: layout.map { InspectorRectSnapshot($0.frame) },
                depth: depth,
                properties: properties(for: node).map { property in
                    var attributed = property
                    attributed.origin = nodeOrigins?.properties[property.name]
                    return attributed
                },
                origin: nodeOrigins?.construction,
                view: nodeOrigins?.view
            )
        )
        let childLayouts = layout?.children ?? []
        for (index, child) in node.children.enumerated() {
            let childLayout = index < childLayouts.count ? childLayouts[index] : nil
            collect(node: child, layout: childLayout, depth: depth + 1, origins: origins, into: &nodes)
        }
    }

    private static func label(for node: UINode) -> String {
        switch node {
        case .text(let text): return text.text
        case .button(let button): return button.title
        case .vstack(let stack): return "spacing=\(format(stack.spacing)) alignment=\(stack.alignment.rawValue)"
        case .image(let image): return "\(image.source.width)x\(image.source.height)"
        case .scrollView(let scroll): return "viewport=\(format(scroll.viewportSize.width))x\(format(scroll.viewportSize.height))"
        case .textField(let field): return field.text
        case .navigationStack: return ""
        case .modal(let modal): return "presenting=\(modal.presented != nil)"
        }
    }

    /// The node's properties, taken apart so an editor can address them.
    ///
    /// Exhaustive over `UINode` with no `default:`, for the reason
    /// `UINode`'s own doc comment gives: a new node kind should have to decide
    /// what it exposes, rather than silently exposing nothing.
    private static func properties(for node: UINode) -> [InspectorPropertySnapshot] {
        switch node {
        case .text(let text):
            return [
                InspectorPropertySnapshot(name: "text", type: "string", value: text.text, editable: true)
            ] + font(text.font) + [
                InspectorPropertySnapshot(name: "color", type: "color", value: format(text.color), editable: true)
            ]

        case .button(let button):
            return [
                InspectorPropertySnapshot(name: "title", type: "string", value: button.title, editable: true)
            ] + font(button.font) + [
                InspectorPropertySnapshot(name: "isEnabled", type: "bool", value: String(button.isEnabled), editable: true),
                InspectorPropertySnapshot(name: "titleColor", type: "color", value: format(button.titleColor), editable: true),
                InspectorPropertySnapshot(name: "backgroundColor", type: "color", value: format(button.backgroundColor), editable: true),
                InspectorPropertySnapshot(name: "pressedBackgroundColor", type: "color", value: format(button.pressedBackgroundColor), editable: true),
                InspectorPropertySnapshot(name: "cornerRadius", type: "double", value: format(button.cornerRadius), editable: true),
            ] + padding(button.padding)

        case .vstack(let stack):
            return [
                InspectorPropertySnapshot(name: "spacing", type: "double", value: format(stack.spacing), editable: true),
                InspectorPropertySnapshot(
                    name: "alignment",
                    type: "enum",
                    value: stack.alignment.rawValue,
                    options: HorizontalAlignment.allCases.map(\.rawValue),
                    editable: true
                ),
            ]

        case .image(let image):
            // An ImageSource is already-decoded pixels by design -- there is no
            // asset path in the source to point an edit at.
            return [
                InspectorPropertySnapshot(name: "width", type: "double", value: format(Double(image.source.width)), editable: false, note: "image pixels"),
                InspectorPropertySnapshot(name: "height", type: "double", value: format(Double(image.source.height)), editable: false, note: "image pixels"),
            ]

        case .scrollView(let scroll):
            return [
                InspectorPropertySnapshot(name: "viewportWidth", type: "double", value: format(scroll.viewportSize.width), editable: true),
                InspectorPropertySnapshot(name: "viewportHeight", type: "double", value: format(scroll.viewportSize.height), editable: true),
            ]

        case .textField(let field):
            return [
                // The text is the bound @CiderState value, not a literal. An
                // edit here would have to write application state, which is the
                // one thing source write-back deliberately cannot do.
                InspectorPropertySnapshot(name: "text", type: "string", value: field.text, editable: false, note: "bound to app state"),
                InspectorPropertySnapshot(name: "width", type: "double", value: format(field.width), editable: true),
            ] + font(field.font) + [
                InspectorPropertySnapshot(name: "textColor", type: "color", value: format(field.textColor), editable: true),
                InspectorPropertySnapshot(name: "backgroundColor", type: "color", value: format(field.backgroundColor), editable: true),
                InspectorPropertySnapshot(name: "cornerRadius", type: "double", value: format(field.cornerRadius), editable: true),
            ] + padding(field.padding)

        case .navigationStack:
            // The stack shows whichever screen the bound path selects; there is
            // nothing on the node itself a developer wrote.
            return []

        case .modal(let modal):
            return [
                InspectorPropertySnapshot(name: "presenting", type: "bool", value: String(modal.presented != nil), editable: false, note: "bound to app state"),
                InspectorPropertySnapshot(name: "overlayColor", type: "color", value: format(modal.overlayColor), editable: false, note: "theme default"),
            ]
        }
    }

    private static func font(_ request: FontRequest) -> [InspectorPropertySnapshot] {
        [
            InspectorPropertySnapshot(name: "fontSize", type: "double", value: format(request.size), editable: true),
            InspectorPropertySnapshot(
                name: "fontWeight",
                type: "enum",
                value: request.weight.rawValue,
                options: FontWeight.allCases.map(\.rawValue),
                editable: true
            ),
            InspectorPropertySnapshot(name: "fontFamily", type: "string", value: request.family, editable: false, note: "no source form yet"),
        ]
    }

    /// Padding travels as two scalars because that is the only shape the API
    /// can express -- `padding(horizontal:vertical:)`. A four-sided inset could
    /// only have come from inside Cider, so it is reported and not offered.
    private static func padding(_ insets: EdgeInsets) -> [InspectorPropertySnapshot] {
        let symmetric = insets.left == insets.right && insets.top == insets.bottom
        let note = symmetric ? nil : "asymmetric insets have no source form"
        return [
            InspectorPropertySnapshot(name: "paddingHorizontal", type: "double", value: format(insets.left), editable: symmetric, note: note),
            InspectorPropertySnapshot(name: "paddingVertical", type: "double", value: format(insets.top), editable: symmetric, note: note),
        ]
    }

    private static func renderCommandSnapshot(index: Int, command: RenderCommand) -> InspectorRenderCommandSnapshot {
        switch command {
        case .fillRect(let rect, let color, let cornerRadius):
            return InspectorRenderCommandSnapshot(index: index, kind: "fillRect", summary: "\(format(color)) radius=\(format(cornerRadius))", frame: InspectorRectSnapshot(rect))
        case .text(let content, let origin, let font, let color):
            return InspectorRenderCommandSnapshot(index: index, kind: "text", summary: "\(quoted(content)) baseline=\(format(origin)) size=\(format(font.size)) \(format(color))", frame: nil)
        case .image(let rect, let source):
            return InspectorRenderCommandSnapshot(index: index, kind: "image", summary: "\(source.width)x\(source.height)", frame: InspectorRectSnapshot(rect))
        case .pushClip(let rect):
            return InspectorRenderCommandSnapshot(index: index, kind: "pushClip", summary: format(rect), frame: InspectorRectSnapshot(rect))
        case .popClip:
            return InspectorRenderCommandSnapshot(index: index, kind: "popClip", summary: "", frame: nil)
        }
    }

    // MARK: - Formatting
    //
    // Fixed to one decimal so a dump can be diffed between runs without
    // floating-point noise swamping the real change.

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func format(_ point: Point) -> String {
        "(\(format(point.x)), \(format(point.y)))"
    }

    private static func format(_ rect: Rect) -> String {
        "(\(format(rect.minX)), \(format(rect.minY)), \(format(rect.width))x\(format(rect.height)))"
    }

    private static func format(_ color: Color) -> String {
        String(
            format: "#%02X%02X%02X%02X",
            Int((color.red * 255).rounded()),
            Int((color.green * 255).rounded()),
            Int((color.blue * 255).rounded()),
            Int((color.alpha * 255).rounded())
        )
    }

    private static func quoted(_ text: String) -> String {
        "\"\(text)\""
    }
}
