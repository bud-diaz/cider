//  The Cider conformance suite.
//
//  docs/06-testing-strategy.md: "The test suite is the compatibility contract.
//  Features are not 'supported' because a demo happened to work once."
//
//  Each test carries a stable identifier. Those identifiers are what the
//  compatibility registry will cite when it claims a behaviour is supported, so
//  they must not be renamed once published -- a renamed test is an unverifiable
//  claim.
//
//    APP-LAUNCH-001    an application launches and presents a first frame
//    UI-TEXT-001       Text renders at the right place with the right content
//    UI-VSTACK-001     VStack stacks and aligns its children
//    UI-BUTTON-001     Button draws a background, a label and a hit region
//    INPUT-POINTER-001 a pointer becomes a touch, and a touch hit-tests
//    STATE-UPDATE-001  a button action changes state and the next frame shows it

import XCTest

import CiderCore
import CiderHost
import CiderHostTesting
import CiderRuntime
import CiderUITree

@testable import CiderUI

final class ConformanceTests: XCTestCase {

    // MARK: - APP-LAUNCH-001

    /// APP-LAUNCH-001: launching an application takes it to the foreground and
    /// presents one frame before any event arrives.
    func testAPP_LAUNCH_001_launchPresentsFirstFrame() throws {
        let harness = try ConformanceHarness(CounterApp())
        XCTAssertEqual(harness.runtime.state, .notRunning)

        try harness.launch()

        XCTAssertEqual(harness.runtime.state, .foreground)
        XCTAssertEqual(
            harness.backend.presentedFrames.count, 1,
            "a window that stays blank until the first event looks broken"
        )
        XCTAssertNotNil(harness.runtime.currentRenderTree)

        let canvas = try XCTUnwrap(harness.backend.lastFrame)
        let profile = harness.runtime.deviceProfile
        XCTAssertEqual(canvas.width, profile.pixelSize.width)
        XCTAssertEqual(canvas.height, profile.pixelSize.height)
    }

    /// APP-LAUNCH-001: the launch sequence is reported on the runtime channel.
    func testAPP_LAUNCH_001_launchIsLogged() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let messages = harness.logSink.messages(channel: .runtime)
        XCTAssertTrue(messages.contains("launching dev.cider.conformance"))
        XCTAssertTrue(messages.contains("device: phone-standard"))
        XCTAssertTrue(messages.contains("renderer initialized"))
        XCTAssertTrue(messages.contains("application started"))
    }

    /// APP-LAUNCH-001: terminating runs the shutdown sequence once, and is safe
    /// to repeat.
    func testAPP_LAUNCH_001_terminationIsIdempotent() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        try harness.deliver([.closeRequested])
        XCTAssertEqual(harness.runtime.state, .terminated)

        harness.runtime.terminate()
        XCTAssertEqual(harness.runtime.state, .terminated)

        let terminations = harness.logSink.messages(channel: .runtime)
            .filter { $0 == "application terminated" }
        XCTAssertEqual(terminations.count, 1)
    }

    /// APP-LAUNCH-001: an unknown device profile fails before a window opens,
    /// with a diagnostic naming the profiles that do exist.
    func testAPP_LAUNCH_001_unknownDeviceProfileIsRefused() {
        XCTAssertThrowsError(try ConformanceHarness(CounterApp(), device: "phone-enormous")) { error in
            let diagnostic = error as? Diagnostic
            XCTAssertEqual(diagnostic?.code, "CID0201")
            XCTAssertTrue(diagnostic?.remedy?.contains("phone-standard") ?? false)
        }
    }

    // MARK: - UI-TEXT-001

    /// UI-TEXT-001: a `Text` view becomes one TextNode carrying its content.
    func testUI_TEXT_001_textLowersToATextNode() throws {
        let scene = Lowering.scene(from: TextOnlyApp().body)

        guard case .text(let node) = scene.root else {
            return XCTFail("expected a TextNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(node.text, "Hello")
        XCTAssertEqual(node.font.size, Theme.bodyFontSize)
        XCTAssertTrue(scene.actions.isEmpty, "text is not interactive")
    }

    /// UI-TEXT-001: text is drawn once, on its baseline, at the ascent below the
    /// top of its layout box.
    func testUI_TEXT_001_textDrawsOnItsBaseline() throws {
        let harness = try ConformanceHarness(TextOnlyApp())
        try harness.launch()

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        XCTAssertEqual(tree.commands.count, 1)

        guard case .text(let content, let baseline, let font, _) = tree.commands[0] else {
            return XCTFail("expected a text command")
        }
        XCTAssertEqual(content, "Hello")

        let box = try XCTUnwrap(harness.runtime.currentLayout)
        let ascent = DeterministicTextEngine(scale: 1).metrics(for: font).ascent
        XCTAssertEqual(baseline.y, box.frame.minY + ascent, accuracy: 1e-9)
        XCTAssertEqual(baseline.x, box.frame.minX, accuracy: 1e-9)
    }

    /// UI-TEXT-001: a text-only screen is centred in the device's safe area, not
    /// in its full bounds.
    func testUI_TEXT_001_contentSitsInsideTheSafeArea() throws {
        let harness = try ConformanceHarness(TextOnlyApp())
        try harness.launch()

        let box = try XCTUnwrap(harness.runtime.currentLayout)
        let safeArea = harness.runtime.deviceProfile.safeAreaBounds

        XCTAssertEqual(box.frame.midY, safeArea.midY, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(box.frame.minY, safeArea.minY)
        XCTAssertLessThanOrEqual(box.frame.maxY, safeArea.maxY)
    }

    /// UI-TEXT-001: modifiers reach the node.
    func testUI_TEXT_001_fontAndColorModifiers() throws {
        struct StyledApp: CiderApp {
            var body: some CiderView {
                Text("Styled").font(size: 28, weight: .bold).foregroundColor(Color(hex: 0xFF0000))
            }
        }

        let scene = Lowering.scene(from: StyledApp().body)
        guard case .text(let node) = scene.root else {
            return XCTFail("expected a TextNode")
        }
        XCTAssertEqual(node.font.size, 28)
        XCTAssertEqual(node.font.weight, .bold)
        XCTAssertEqual(node.color, Color(hex: 0xFF0000))
    }

    // MARK: - UI-VSTACK-001

    /// UI-VSTACK-001: a stack's children keep source order and their identities
    /// follow their position.
    func testUI_VSTACK_001_childrenKeepSourceOrder() throws {
        let scene = Lowering.scene(from: CounterApp().body)

        guard case .vstack(let stack) = scene.root else {
            return XCTFail("expected a VStackNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(stack.children.count, 3)
        XCTAssertEqual(stack.children.map(\.kindName), ["TextNode", "ButtonNode", "TextNode"])
        XCTAssertEqual(
            stack.children.map(\.id.path),
            ["root/0/0", "root/0/1", "root/0/2"]
        )
        XCTAssertEqual(stack.spacing, 24)
    }

    /// UI-VSTACK-001: children are stacked top to bottom with the declared gap
    /// between them, and no gap outside them.
    func testUI_VSTACK_001_childrenAreStackedWithSpacing() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let stack = try XCTUnwrap(harness.runtime.currentLayout)
        XCTAssertEqual(stack.children.count, 3)

        let boxes = stack.children.map(\.frame)
        XCTAssertEqual(boxes[0].minY, stack.frame.minY, accuracy: 1e-9, "no leading gap")
        XCTAssertEqual(boxes[2].maxY, stack.frame.maxY, accuracy: 1e-9, "no trailing gap")
        XCTAssertEqual(boxes[1].minY - boxes[0].maxY, 24, accuracy: 1e-9)
        XCTAssertEqual(boxes[2].minY - boxes[1].maxY, 24, accuracy: 1e-9)
    }

    /// UI-VSTACK-001: the default alignment centres children on the stack's
    /// widest child.
    func testUI_VSTACK_001_defaultAlignmentIsCentre() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let stack = try XCTUnwrap(harness.runtime.currentLayout)
        for child in stack.children {
            XCTAssertEqual(child.frame.midX, stack.frame.midX, accuracy: 1e-9)
        }
    }

    /// UI-VSTACK-001: the stack is exactly as wide as its widest child.
    func testUI_VSTACK_001_widthIsTheWidestChild() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let stack = try XCTUnwrap(harness.runtime.currentLayout)
        let widest = stack.children.map(\.frame.width).max() ?? 0
        XCTAssertEqual(stack.frame.width, widest, accuracy: 1e-9)
    }

    // MARK: - UI-BUTTON-001

    /// UI-BUTTON-001: a `Button` becomes a ButtonNode with an action registered
    /// under its identity.
    func testUI_BUTTON_001_buttonLowersWithARegisteredAction() throws {
        let scene = Lowering.scene(from: CounterApp().body)

        guard case .vstack(let stack) = scene.root,
              case .button(let button) = stack.children[1] else {
            return XCTFail("expected a ButtonNode as the second child")
        }
        XCTAssertEqual(button.title, "Press Me")
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(Array(scene.actions.keys), [button.id])
    }

    /// UI-BUTTON-001: a button draws a background then its label, and publishes
    /// exactly one hit region covering its box.
    func testUI_BUTTON_001_buttonDrawsBackgroundLabelAndHitRegion() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        let region = try harness.onlyButton()

        var fill: (rect: Rect, radius: Double)?
        for command in tree.commands {
            if case .fillRect(let rect, _, let radius) = command {
                XCTAssertNil(fill, "the MVP draws one filled rectangle: the button")
                fill = (rect, radius)
            }
        }
        let background = try XCTUnwrap(fill)
        XCTAssertEqual(background.rect, region.frame, "the fill covers the hit region")
        XCTAssertEqual(background.radius, Theme.buttonCornerRadius)

        XCTAssertTrue(harness.drawnStrings().contains("Press Me"))
    }

    /// UI-BUTTON-001: the label is centred in the button box, and the box is the
    /// label plus its padding.
    func testUI_BUTTON_001_labelIsCentredInsideItsPadding() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let region = try harness.onlyButton()
        let engine = DeterministicTextEngine(scale: 1)
        let run = engine.shape("Press Me", font: FontRequest(size: Theme.bodyFontSize))

        XCTAssertEqual(
            region.frame.width,
            run.width + Theme.buttonPadding.horizontal,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            region.frame.height,
            run.metrics.lineHeight + Theme.buttonPadding.vertical,
            accuracy: 1e-9
        )
    }

    /// UI-BUTTON-001: a disabled button still draws and still occupies space,
    /// but registers no action and cannot be hit.
    func testUI_BUTTON_001_disabledButtonRegistersNoAction() throws {
        struct DisabledApp: CiderApp {
            var body: some CiderView {
                Button("Nope") { XCTFail("a disabled button must not run its action") }
                    .disabled()
            }
        }

        let harness = try ConformanceHarness(DisabledApp())
        try harness.launch()

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        XCTAssertEqual(tree.hitRegions.count, 1)
        XCTAssertFalse(tree.hitRegions[0].isEnabled)
        XCTAssertNil(tree.hitTest(Point(x: tree.hitRegions[0].frame.midX,
                                        y: tree.hitRegions[0].frame.midY)))

        try harness.tap(at: Point(x: tree.hitRegions[0].frame.midX,
                                  y: tree.hitRegions[0].frame.midY))
    }

    // MARK: - INPUT-POINTER-001

    /// INPUT-POINTER-001: hit testing finds the button under a point and nothing
    /// under empty space.
    func testINPUT_POINTER_001_hitTesting() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        let region = try harness.onlyButton()

        XCTAssertEqual(tree.hitTest(Point(x: region.frame.midX, y: region.frame.midY)), region.id)
        XCTAssertNil(tree.hitTest(Point(x: 5, y: 5)), "the top-left corner is empty")
        XCTAssertNil(
            tree.hitTest(Point(x: region.frame.maxX, y: region.frame.midY)),
            "hit regions are half-open on their max edge"
        )
    }

    /// INPUT-POINTER-001: pressing marks the button pressed; releasing clears it.
    func testINPUT_POINTER_001_pressAndReleaseTrackPressedState() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let button = try harness.onlyButton()
        let center = Point(x: button.frame.midX, y: button.frame.midY)

        try harness.deliver([.pointerDown(location: center, button: .primary)])
        XCTAssertEqual(harness.runtime.currentPressedNode, button.id)

        try harness.deliver([.pointerUp(location: center, button: .primary)])
        XCTAssertNil(harness.runtime.currentPressedNode)
    }

    /// INPUT-POINTER-001: dragging off a button before releasing cancels it --
    /// the behaviour a user expects when they change their mind.
    func testINPUT_POINTER_001_draggingOffCancelsTheAction() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let button = try harness.onlyButton()
        let center = Point(x: button.frame.midX, y: button.frame.midY)
        let outside = Point(x: button.frame.midX, y: button.frame.maxY + 40)

        try harness.deliver([
            .pointerDown(location: center, button: .primary),
            .pointerMove(location: outside),
            .pointerUp(location: outside, button: .primary),
        ])

        XCTAssertNil(harness.runtime.currentPressedNode)
        XCTAssertTrue(harness.drawnStrings().contains("Count: 0"), "the action must not have run")
    }

    /// INPUT-POINTER-001: the pointer leaving the window cancels an in-flight
    /// touch, because the release will never arrive.
    func testINPUT_POINTER_001_pointerExitCancelsTheTouch() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let button = try harness.onlyButton()
        try harness.deliver([
            .pointerDown(location: Point(x: button.frame.midX, y: button.frame.midY), button: .primary),
            .pointerExit,
        ])

        XCTAssertNil(harness.runtime.currentPressedNode)
    }

    /// INPUT-POINTER-001: a secondary click is not a touch. Cider models one
    /// finger, and a right-click is not a tap the user made.
    func testINPUT_POINTER_001_secondaryButtonIsIgnored() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let button = try harness.onlyButton()
        let center = Point(x: button.frame.midX, y: button.frame.midY)

        try harness.deliver([
            .pointerDown(location: center, button: .secondary),
            .pointerUp(location: center, button: .secondary),
        ])

        XCTAssertNil(harness.runtime.currentPressedNode)
        XCTAssertTrue(harness.drawnStrings().contains("Count: 0"))
    }

    // MARK: - STATE-UPDATE-001

    /// STATE-UPDATE-001: tapping the button runs Swift application code, changes
    /// state, and the next frame shows the new value.
    ///
    /// This is the vertical slice the first milestone is defined by.
    func testSTATE_UPDATE_001_tappingIncrementsAndRedraws() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        XCTAssertTrue(harness.drawnStrings().contains("Count: 0"))

        let center = try harness.center(of: harness.onlyButton().id)

        try harness.tap(at: center)
        XCTAssertTrue(harness.drawnStrings().contains("Count: 1"))

        try harness.tap(at: center)
        try harness.tap(at: center)
        XCTAssertTrue(harness.drawnStrings().contains("Count: 3"))
    }

    /// STATE-UPDATE-001: each state change presents a new frame.
    func testSTATE_UPDATE_001_eachChangePresentsAFrame() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let framesAfterLaunch = harness.backend.presentedFrames.count
        let center = try harness.center(of: harness.onlyButton().id)

        try harness.tap(at: center)
        XCTAssertGreaterThan(harness.backend.presentedFrames.count, framesAfterLaunch)

        let framesAfterTap = harness.backend.presentedFrames.count
        try harness.runtime.pump()
        XCTAssertEqual(
            harness.backend.presentedFrames.count, framesAfterTap,
            "an idle pump must not redraw; invalidation is what schedules a frame"
        )
    }

    /// STATE-UPDATE-001: identities are stable across a rebuild, so the button a
    /// user is holding stays the same button after state changes underneath it.
    func testSTATE_UPDATE_001_identitiesSurviveARebuild() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let before = try harness.onlyButton().id
        try harness.tap(at: try harness.center(of: before))
        let after = try harness.onlyButton().id

        XCTAssertEqual(before, after)
    }

    /// STATE-UPDATE-001: the rendered pixels actually change, not just the tree.
    func testSTATE_UPDATE_001_pixelsChange() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let before = try XCTUnwrap(harness.backend.lastFrame)
        try harness.tap(at: try harness.center(of: harness.onlyButton().id))
        let after = try XCTUnwrap(harness.backend.lastFrame)

        // Counted rather than compared: an array assertion on 329,160 pixels
        // prints all of them on failure and tells you nothing.
        let changed = zip(before.pixels, after.pixels).count { $0 != $1 }
        XCTAssertGreaterThan(changed, 0, "the counter text must have redrawn")
    }
}
