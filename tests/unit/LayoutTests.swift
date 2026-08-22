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
