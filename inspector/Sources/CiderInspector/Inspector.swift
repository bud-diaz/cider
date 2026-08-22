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

public enum Inspector {

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
