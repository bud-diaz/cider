import XCTest
import Foundation

@testable import CiderCore
@testable import CiderInspector
@testable import CiderUITree
@testable import CiderHostTesting

final class InspectorSnapshotTests: XCTestCase {
    func testSnapshotCapturesNodeRenderAndHitDataAsJSON() throws {
        let text = UINode.text(TextNode(id: .root.child(0), text: "Hello", font: FontRequest(size: 16), color: .white))
        let button = UINode.button(ButtonNode(
            id: .root.child(1),
            title: "Tap",
            font: FontRequest(size: 16),
            titleColor: .white,
            backgroundColor: .black,
            pressedBackgroundColor: .white,
            cornerRadius: 6,
            padding: EdgeInsets(horizontal: 8, vertical: 4)
        ))
        let root = UINode.vstack(VStackNode(id: .root, spacing: 8, alignment: .center, children: [text, button]))
        let context = LayoutContext(textEngine: DeterministicTextEngine(scale: 1))
        let layout = LayoutEngine.layoutCentered(root, in: Rect(x: 0, y: 0, width: 240, height: 320), context: context)
        let renderTree = RenderTreeBuilder.build(node: root, layout: layout, backgroundColor: .black, context: context)

        let snapshot = Inspector.snapshot(node: root, layout: layout, renderTree: renderTree, frameCount: 3, generatedAtMilliseconds: 42)

        XCTAssertEqual(snapshot.frameCount, 3)
        XCTAssertTrue(snapshot.nodes.contains { $0.kind == "TextNode" && $0.label == "Hello" && $0.frame != nil })
        XCTAssertTrue(snapshot.nodes.contains { $0.kind == "ButtonNode" && $0.label == "Tap" })
        XCTAssertTrue(snapshot.renderCommands.contains { $0.kind == "text" })
        XCTAssertTrue(snapshot.hitRegions.contains { $0.id == "root/1" })
        let json = try Inspector.json(snapshot)
        let decoded = try JSONDecoder().decode(InspectorSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, snapshot)
    }

    /// The editor addresses a value by name, so `label`'s single display string
    /// is not enough. Each kind has to take itself apart.
    func testSnapshotCarriesTypedPropertiesPerNodeKind() throws {
        let field = UINode.textField(TextFieldNode(
            id: .root.child(0),
            text: "typed",
            font: FontRequest(size: 14, weight: .bold),
            textColor: .white,
            backgroundColor: .black,
            cornerRadius: 5,
            padding: EdgeInsets(horizontal: 12, vertical: 6),
            width: 180
        ))
        let root = UINode.vstack(VStackNode(id: .root, spacing: 9, alignment: .leading, children: [field]))
        let snapshot = Inspector.snapshot(node: root, layout: nil, renderTree: nil, frameCount: 1, generatedAtMilliseconds: 0)

        let stack = try XCTUnwrap(snapshot.nodes.first { $0.kind == "VStackNode" })
        let stackProperties = try XCTUnwrap(stack.properties)
        XCTAssertEqual(stackProperties.first { $0.name == "spacing" }?.value, "9.0")
        let alignment = try XCTUnwrap(stackProperties.first { $0.name == "alignment" })
        XCTAssertEqual(alignment.value, "leading")
        XCTAssertEqual(alignment.options, ["leading", "center", "trailing"])
        XCTAssertTrue(alignment.editable)

        let node = try XCTUnwrap(snapshot.nodes.first { $0.kind == "TextFieldNode" })
        let properties = try XCTUnwrap(node.properties)
        XCTAssertEqual(properties.first { $0.name == "fontSize" }?.value, "14.0")
        XCTAssertEqual(properties.first { $0.name == "fontWeight" }?.value, "bold")
        XCTAssertEqual(properties.first { $0.name == "cornerRadius" }?.value, "5.0")
        XCTAssertEqual(properties.first { $0.name == "paddingHorizontal" }?.value, "12.0")
        XCTAssertEqual(properties.first { $0.name == "paddingVertical" }?.value, "6.0")
        XCTAssertEqual(properties.first { $0.name == "width" }?.value, "180.0")
        XCTAssertEqual(properties.first { $0.name == "textColor" }?.value, "#FFFFFFFF")

        // Bound state is reported, and reported as not editable: writing it
        // would mean writing application state, which source write-back cannot.
        let text = try XCTUnwrap(properties.first { $0.name == "text" })
        XCTAssertEqual(text.value, "typed")
        XCTAssertFalse(text.editable)
        XCTAssertEqual(text.note, "bound to app state")
    }

    /// A snapshot written before typed properties existed still decodes, so a
    /// dashboard and a runtime can be one version apart without the console
    /// failing to read anything at all.
    func testSnapshotWithoutPropertiesStillDecodes() throws {
        let json = """
            {"frameCount":1,"generatedAtMilliseconds":1,\
            "nodes":[{"id":"root","kind":"TextNode","label":"Hi","depth":0}],\
            "renderCommands":[],"hitRegions":[]}
            """
        let decoded = try JSONDecoder().decode(InspectorSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(decoded.nodes[0].properties)
    }
}
