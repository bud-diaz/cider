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
}
