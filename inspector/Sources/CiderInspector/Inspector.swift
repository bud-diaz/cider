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

public struct InspectorNodeSnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var label: String
    public var frame: InspectorRectSnapshot?
    public var depth: Int

    public init(id: String, kind: String, label: String, frame: InspectorRectSnapshot?, depth: Int) {
        self.id = id
        self.kind = kind
        self.label = label
        self.frame = frame
        self.depth = depth
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
        generatedAtMilliseconds: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> InspectorSnapshot {
        var nodes: [InspectorNodeSnapshot] = []
        collect(node: node, layout: layout, depth: 0, into: &nodes)
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


    private static func collect(node: UINode, layout: LayoutBox?, depth: Int, into nodes: inout [InspectorNodeSnapshot]) {
        nodes.append(
            InspectorNodeSnapshot(
                id: node.id.description,
                kind: node.kindName,
                label: label(for: node),
                frame: layout.map { InspectorRectSnapshot($0.frame) },
                depth: depth
            )
        )
        let childLayouts = layout?.children ?? []
        for (index, child) in node.children.enumerated() {
            let childLayout = index < childLayouts.count ? childLayouts[index] : nil
            collect(node: child, layout: childLayout, depth: depth + 1, into: &nodes)
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
