//  Unit tests for the layout engine.
//
//  Every assertion here is a number the deterministic text engine makes
//  predictable: advance is 0.6x the font size, line height is 1.2x. A test that
//  used the host's fonts would be asserting about the machine.

import XCTest

@testable import CiderCore
@testable import CiderHostTesting
@testable import CiderUITree

final class LayoutTests: XCTestCase {

    private let engine = DeterministicTextEngine(scale: 1)
    private var context: LayoutContext { LayoutContext(textEngine: engine) }

    private func text(_ id: String, _ content: String, size: Double = 10) -> UINode {
        .text(
            TextNode(
                id: NodeID(path: id),
                text: content,
                font: FontRequest(size: size),
                color: .black
            )
        )
    }

    private func button(_ id: String, _ title: String, size: Double = 10) -> UINode {
        .button(
            ButtonNode(
                id: NodeID(path: id),
                title: title,
                font: FontRequest(size: size),
                titleColor: .white,
                backgroundColor: .black,
                pressedBackgroundColor: .black,
                cornerRadius: 4,
                padding: EdgeInsets(horizontal: 10, vertical: 5)
            )
        )
    }

    private func textField(_ id: String, _ text: String, width: Double, size: Double = 10) -> UINode {
        .textField(
            TextFieldNode(
                id: NodeID(path: id),
                text: text,
                font: FontRequest(size: size),
                textColor: .black,
                backgroundColor: .white,
                cornerRadius: 4,
                padding: EdgeInsets(horizontal: 8, vertical: 4),
                width: width
            )
        )
    }

    private func scrollView(_ id: String, width: Double, height: Double, content: UINode) -> UINode {
        .scrollView(
            ScrollViewNode(
                id: NodeID(path: id),
                viewportSize: Size(width: width, height: height),
                content: content
            )
        )
    }

    private func image(_ id: String, width: Int, height: Int) -> UINode {
        .image(
            ImageNode(
                id: NodeID(path: id),
                source: .solid(.black, width: width, height: height)
            )
        )
    }

    // MARK: - Measurement

    func testTextMeasuresToAdvanceTimesLineHeight() {
        let size = LayoutEngine.measure(text("t", "abcde", size: 10), context: context)
        XCTAssertEqual(size.width, 5 * 6, accuracy: 1e-9, "five glyphs at 0.6 x 10pt")
        XCTAssertEqual(size.height, 12, accuracy: 1e-9, "1.2 x 10pt line height")
    }

    func testEmptyTextHasZeroWidthButFullLineHeight() {
        // A blank line still occupies a line; collapsing it would make an empty
        // label silently change the layout around it.
        let size = LayoutEngine.measure(text("t", "", size: 10), context: context)
        XCTAssertEqual(size.width, 0)
        XCTAssertEqual(size.height, 12, accuracy: 1e-9)
    }

    func testButtonAddsItsPadding() {
        let size = LayoutEngine.measure(button("b", "ok", size: 10), context: context)
        XCTAssertEqual(size.width, 2 * 6 + 20, accuracy: 1e-9)
        XCTAssertEqual(size.height, 12 + 10, accuracy: 1e-9)
    }

    func testVStackSumsHeightsAndTakesWidestChild() {
        let stack = UINode.vstack(
            VStackNode(
                id: .root,
                spacing: 4,
                alignment: .center,
                children: [text("a", "ab", size: 10), text("b", "abcd", size: 10)]
            )
        )

        let size = LayoutEngine.measure(stack, context: context)
        XCTAssertEqual(size.width, 4 * 6, accuracy: 1e-9, "the widest child")
        XCTAssertEqual(size.height, 12 + 4 + 12, accuracy: 1e-9, "heights plus one gap")
    }

    func testSpacingIsBetweenChildrenNotAroundThem() {
        let single = UINode.vstack(
            VStackNode(id: .root, spacing: 100, alignment: .center, children: [text("a", "ab")])
        )
        XCTAssertEqual(LayoutEngine.measure(single, context: context).height, 12, accuracy: 1e-9)
    }

    func testEmptyVStackIsZeroSized() {
        let empty = UINode.vstack(VStackNode(id: .root, spacing: 8, alignment: .center, children: []))
        XCTAssertEqual(LayoutEngine.measure(empty, context: context), .zero)
    }

    func testImageMeasuresToItsSourcePixelDimensions() {
        let size = LayoutEngine.measure(image("i", width: 40, height: 30), context: context)
        XCTAssertEqual(size, Size(width: 40, height: 30))
    }

    func testTextFieldMeasuresToItsExplicitWidthAndTheFontsLineHeight() {
        // Width doesn't depend on the text -- see TextFieldNode's doc
        // comment -- and height doesn't need a shaped run, only the font's
        // metrics, since it doesn't depend on the text either.
        let empty = LayoutEngine.measure(textField("f", "", width: 80, size: 10), context: context)
        let long = LayoutEngine.measure(textField("f", "a very long string indeed", width: 80, size: 10), context: context)

        XCTAssertEqual(empty, long, "content must not affect size")
        XCTAssertEqual(empty.width, 80, accuracy: 1e-9)
        XCTAssertEqual(empty.height, 12 + 4 + 4, accuracy: 1e-9, "1.2 x 10pt line height plus vertical padding")
    }

    func testScrollViewMeasuresToItsExplicitViewportSizeRegardlessOfContent() {
        // The whole point of a scroll view is that its content can be a
        // different size than it is -- much larger, here.
        let tallContent = UINode.vstack(
            VStackNode(
                id: NodeID(path: "s/0"),
                spacing: 0,
                alignment: .center,
                children: (0..<20).map { text("s/0/\($0)", "row", size: 10) }
            )
        )
        let scroll = scrollView("s", width: 90, height: 50, content: tallContent)

        let size = LayoutEngine.measure(scroll, context: context)
        XCTAssertEqual(size, Size(width: 90, height: 50))
    }

    // MARK: - Placement

    func testVStackStacksChildrenWithSpacing() {
        let stack = UINode.vstack(
            VStackNode(
                id: .root,
                spacing: 4,
                alignment: .leading,
                children: [text("a", "ab", size: 10), text("b", "cd", size: 10)]
            )
        )

        let box = LayoutEngine.place(
            stack,
            at: Point(x: 0, y: 0),
            size: LayoutEngine.measure(stack, context: context),
            context: context
        )

        XCTAssertEqual(box.children[0].frame.minY, 0)
        XCTAssertEqual(box.children[1].frame.minY, 16, accuracy: 1e-9, "12pt line + 4pt spacing")
    }

    func testAlignment() {
        func stack(_ alignment: HorizontalAlignment) -> LayoutBox {
            let node = UINode.vstack(
                VStackNode(
                    id: .root,
                    spacing: 0,
                    alignment: alignment,
                    children: [text("narrow", "ab", size: 10), text("wide", "abcdef", size: 10)]
                )
            )
            return LayoutEngine.place(
                node,
                at: .zero,
                size: LayoutEngine.measure(node, context: context),
                context: context
            )
        }

        // The narrow child is 12 wide inside a 36-wide stack.
        XCTAssertEqual(stack(.leading).children[0].frame.minX, 0)
        XCTAssertEqual(stack(.center).children[0].frame.minX, 12, accuracy: 1e-9)
        XCTAssertEqual(stack(.trailing).children[0].frame.minX, 24, accuracy: 1e-9)
    }

    func testLayoutCenteredCentresInsideBounds() {
        let node = text("t", "abcde", size: 10)
        let bounds = Rect(x: 0, y: 47, width: 390, height: 763)

        let box = LayoutEngine.layoutCentered(node, in: bounds, context: context)

        XCTAssertEqual(box.frame.midX, bounds.midX, accuracy: 1e-9)
        XCTAssertEqual(box.frame.midY, bounds.midY, accuracy: 1e-9)
    }

    func testImagePlacesAtItsMeasuredFrame() {
        let node = image("i", width: 40, height: 30)
        let box = LayoutEngine.place(node, at: Point(x: 5, y: 9), size: Size(width: 40, height: 30), context: context)

        XCTAssertEqual(box.frame, Rect(x: 5, y: 9, width: 40, height: 30))
        XCTAssertTrue(box.children.isEmpty)
    }

    func testTextFieldPlacesAtItsMeasuredFrame() {
        let node = textField("f", "hello", width: 80, size: 10)
        let box = LayoutEngine.place(node, at: Point(x: 5, y: 9), size: Size(width: 80, height: 20), context: context)

        XCTAssertEqual(box.frame, Rect(x: 5, y: 9, width: 80, height: 20))
        XCTAssertTrue(box.children.isEmpty)
    }

    func testScrollViewPlacesItsContentAtTheViewportsOriginUnscrolled() {
        // Layout describes the *unscrolled* reference frame -- content starts
        // flush with the viewport's top-left. Applying an actual scroll
        // offset is RenderTreeBuilder's job (see RasterizerClipTests-adjacent
        // coverage in ConformanceTests' UI-SCROLL-001 for that half).
        let content = text("s/0", "hello", size: 10)
        let node = scrollView("s", width: 90, height: 50, content: content)

        let box = LayoutEngine.place(node, at: Point(x: 5, y: 9), size: Size(width: 90, height: 50), context: context)

        XCTAssertEqual(box.frame, Rect(x: 5, y: 9, width: 90, height: 50))
        XCTAssertEqual(box.children.count, 1)

        let contentBox = box.children[0]
        XCTAssertEqual(contentBox.frame.minX, 5, accuracy: 1e-9)
        XCTAssertEqual(contentBox.frame.minY, 9, accuracy: 1e-9)
        // The content's own natural size (5 glyphs at 0.6 x 10pt, 1.2 x 10pt
        // line height), not the viewport's -- it can be smaller or larger.
        XCTAssertEqual(contentBox.frame.width, 5 * 6, accuracy: 1e-9)
        XCTAssertEqual(contentBox.frame.height, 12, accuracy: 1e-9)
    }

    func testScrollViewContentCanExceedTheViewport() {
        let tallContent = UINode.vstack(
            VStackNode(
                id: NodeID(path: "s/0"),
                spacing: 0,
                alignment: .center,
                children: (0..<20).map { text("s/0/\($0)", "row", size: 10) }
            )
        )
        let node = scrollView("s", width: 90, height: 50, content: tallContent)
        let box = LayoutEngine.place(node, at: .zero, size: Size(width: 90, height: 50), context: context)

        XCTAssertGreaterThan(box.children[0].frame.height, box.frame.height)
    }

    func testBoxLookupFindsNestedNodes() {
        let node = UINode.vstack(
            VStackNode(
                id: .root,
                spacing: 0,
                alignment: .center,
                children: [text("root/0", "ab"), button("root/1", "ok")]
            )
        )
        let box = LayoutEngine.place(
            node,
            at: .zero,
            size: LayoutEngine.measure(node, context: context),
            context: context
        )

        XCTAssertNotNil(box.box(for: NodeID(path: "root/1")))
        XCTAssertNil(box.box(for: NodeID(path: "root/9")))
    }
}

final class UINodeFindTests: XCTestCase {

    func testFindsANestedNodeByIdentity() {
        let node = UINode.vstack(
            VStackNode(
                id: .root,
                spacing: 0,
                alignment: .center,
                children: [
                    .text(TextNode(id: NodeID(path: "root/0"), text: "a", font: FontRequest(size: 10), color: .black)),
                    .button(
                        ButtonNode(
                            id: NodeID(path: "root/1"),
                            title: "ok",
                            font: FontRequest(size: 10),
                            titleColor: .white,
                            backgroundColor: .black,
                            pressedBackgroundColor: .black,
                            cornerRadius: 0,
                            padding: .zero
                        )
                    ),
                ]
            )
        )

        guard case .button(let found) = node.find(NodeID(path: "root/1")) else {
            return XCTFail("expected to find the button")
        }
        XCTAssertEqual(found.title, "ok")
        XCTAssertNil(node.find(NodeID(path: "root/9")))
    }
}

final class NodeIdentityTests: XCTestCase {

    func testChildPathsAreStableAndOrdered() {
        // Identity is what lets a pressed button survive a rebuild, so the same
        // structure must always produce the same paths.
        let root = NodeID.root
        XCTAssertEqual(root.child(0).path, "root/0")
        XCTAssertEqual(root.child(1).child(2).path, "root/1/2")
        XCTAssertEqual(root.child(0), NodeID(path: "root/0"))
        XCTAssertNotEqual(root.child(0), root.child(1))
    }
}
