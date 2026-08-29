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
//    UI-BUTTON-002     Button's style modifiers reach ButtonNode, and unset ones stay Theme's
//    INPUT-POINTER-001 a pointer becomes a touch, and a touch hit-tests
//    STATE-UPDATE-001  a button action changes state and the next frame shows it
//    UI-IMAGE-001      Image lowers to an ImageNode and draws at its intrinsic size
//    UI-SCROLL-001     ScrollView clips its content and scrolling moves it, clamped
//    UI-TEXTFIELD-001  TextField gains focus on tap and edits its bound state
//    UI-TEXTFIELD-002  TextField's style modifiers reach TextFieldNode, and unset ones stay Theme's
//    UI-LIST-001       List's rows keep source order and scroll like a ScrollView
//    NAV-PUSH-001      NavigationView lowers to a NavigationStackNode and pushes screens
//    NAV-POP-001       popping a navigation stack returns to the screen underneath
//    UI-MODAL-001      Modal dims and overlays base content, and blocks taps to it
//    STYLE-BRAND-001   Stage 2 defaults use the locked Cider brand palette
//    ENV-VALUES-001    runtime environment values are visible to application code
//    STORE-PREF-001    preferences persist values inside the app sandbox
//    STORE-FILE-001    documents/cache/temp text files are scoped to the sandbox
//    CLIPBOARD-001     the development clipboard stores text for the running app
//    TIMER-001         one-shot timers run application code after their interval
//    LIFE-BG-001       foreground/background lifecycle transitions can be simulated
//    LIFE-BG-002       CiderApp.didEnterBackground()/didEnterForeground() fire on those transitions
//    NET-HTTP-001      HTTP requests enforce manifest network permission
//    EDIT-ORIGIN-001   a view records the source position it was written at
//    EDIT-ORIGIN-002   two views on one line get distinct recorded columns
//    EDIT-ORIGIN-003   synthetic wrapper nodes record no origin
//    EDIT-ORIGIN-004   every view still accepts its ordinary trailing-closure form

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

    // MARK: - UI-BUTTON-002

    /// UI-BUTTON-002: `Button`'s style modifiers reach `ButtonNode`.
    ///
    /// These properties were hard-wired from `Theme` until the visual editor
    /// needed them to be things a developer had actually written -- an editor
    /// cannot offer to change a value that has no source to change.
    func testUI_BUTTON_002_styleModifiersReachTheNode() throws {
        let scene = Lowering.scene(from: StyledButtonApp().body)
        guard case .button(let button) = scene.root else {
            return XCTFail("expected a ButtonNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(button.titleColor, Color(hex: 0x101010))
        XCTAssertEqual(button.backgroundColor, Color(hex: 0x2040C0))
        XCTAssertEqual(button.pressedBackgroundColor, Color(hex: 0x3050D0))
        XCTAssertEqual(button.cornerRadius, 2)
        XCTAssertEqual(button.padding, EdgeInsets(horizontal: 30, vertical: 14))
    }

    /// UI-BUTTON-002: a button nobody styled still gets every `Theme` default.
    /// The modifiers are additive; they do not move where the defaults live.
    func testUI_BUTTON_002_unstyledButtonKeepsThemeDefaults() throws {
        let scene = Lowering.scene(from: CounterApp().body)
        guard case .vstack(let stack) = scene.root,
              case .button(let button) = stack.children[1] else {
            return XCTFail("expected a ButtonNode as the second child")
        }
        XCTAssertEqual(button.titleColor, Theme.accentTextColor)
        XCTAssertEqual(button.backgroundColor, Theme.accentColor)
        XCTAssertEqual(button.pressedBackgroundColor, Theme.accentPressedColor)
        XCTAssertEqual(button.cornerRadius, Theme.buttonCornerRadius)
        XCTAssertEqual(button.padding, Theme.buttonPadding)
    }

    // MARK: - UI-TEXTFIELD-002

    /// UI-TEXTFIELD-002: `TextField`'s style modifiers reach `TextFieldNode`.
    func testUI_TEXTFIELD_002_styleModifiersReachTheNode() throws {
        let scene = Lowering.scene(from: StyledTextFieldApp().body)
        guard case .textField(let field) = scene.root else {
            return XCTFail("expected a TextFieldNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(field.textColor, Color(hex: 0xEFEFEF))
        XCTAssertEqual(field.backgroundColor, Color(hex: 0x202020))
        XCTAssertEqual(field.cornerRadius, 3)
        XCTAssertEqual(field.padding, EdgeInsets(horizontal: 18, vertical: 6))
        XCTAssertEqual(field.width, 120, "styling must not disturb the initializer's width")
    }

    /// UI-TEXTFIELD-002: an unstyled field still gets every `Theme` default.
    func testUI_TEXTFIELD_002_unstyledFieldKeepsThemeDefaults() throws {
        let scene = Lowering.scene(from: TextFieldTestApp().body)
        guard case .textField(let field) = scene.root else {
            return XCTFail("expected a TextFieldNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(field.textColor, Theme.textColor)
        XCTAssertEqual(field.backgroundColor, Theme.textFieldBackgroundColor)
        XCTAssertEqual(field.cornerRadius, Theme.textFieldCornerRadius)
        XCTAssertEqual(field.padding, Theme.textFieldPadding)
    }

    // MARK: - EDIT-ORIGIN-001

    /// EDIT-ORIGIN-001: a view records the file and line it was written at.
    ///
    /// The developer console rewrites Swift to change a property, so something
    /// has to lead from a node in a running process back to a call in a file.
    /// This is that link, and it is the only part of the chain that cannot be
    /// checked by reading the code -- what the compiler reports for a defaulted
    /// `#line` has to be observed.
    func testEDIT_ORIGIN_001_aViewRecordsWhereItWasWritten() throws {
        let scene = Lowering.scene(from: OriginFixtures.singleText)
        let origins = try XCTUnwrap(scene.origins[scene.root.id])

        XCTAssertEqual(origins.construction.line, OriginFixtures.singleTextLine)
        XCTAssertTrue(
            origins.construction.file.hasSuffix("OriginFixtures.swift"),
            "expected an absolute path from #filePath, got \(origins.construction.file)"
        )
        XCTAssertGreaterThan(origins.construction.column, 0)

        // The content is an initializer argument, so it is written wherever the
        // view is.
        XCTAssertEqual(origins.properties["text"], origins.construction)
    }

    /// EDIT-ORIGIN-001: a modifier the developer wrote is recorded; one they
    /// did not write is absent. That difference is what decides whether an edit
    /// rewrites an argument or has to insert a call.
    func testEDIT_ORIGIN_001_onlyWrittenValuesAreRecorded() throws {
        let styled = Lowering.scene(from: OriginFixtures.chained)
        let styledOrigins = try XCTUnwrap(styled.origins[styled.root.id])
        XCTAssertNotNil(styledOrigins.properties["fontSize"])
        XCTAssertNotNil(styledOrigins.properties["fontWeight"])
        XCTAssertNil(styledOrigins.properties["color"], "nothing wrote a colour")

        // A chained modifier resolves to the same file as the chain's head, and
        // the rewriter relies on that: a modifier applied in some other file
        // would run after any edit made here and silently win.
        XCTAssertEqual(styledOrigins.properties["fontSize"]?.file, styledOrigins.construction.file)
        XCTAssertEqual(styledOrigins.construction.line, OriginFixtures.chainedLine)

        // What the compiler reports for a chained call is the one thing this
        // design could not settle by reading the language reference, so record
        // it where a CI log will show it.
        print("EDIT-ORIGIN-001 chained: construction=\(styledOrigins.construction) fontSize=\(String(describing: styledOrigins.properties["fontSize"]))")
    }

    /// EDIT-ORIGIN-001: an initializer argument the caller omitted is not
    /// recorded, even though the node ends up carrying a value for it.
    func testEDIT_ORIGIN_001_defaultedInitializerArgumentsAreNotRecorded() throws {
        let written = Lowering.scene(from: OriginFixtures.stackWithWrittenSpacing)
        let writtenOrigins = try XCTUnwrap(written.origins[written.root.id])
        XCTAssertNotNil(writtenOrigins.properties["spacing"])
        XCTAssertNil(writtenOrigins.properties["alignment"])

        let defaulted = Lowering.scene(from: OriginFixtures.stackWithDefaultSpacing)
        let defaultedOrigins = try XCTUnwrap(defaulted.origins[defaulted.root.id])
        XCTAssertNil(defaultedOrigins.properties["spacing"], "nobody wrote a spacing")

        // ...and the node still carries the Theme value either way.
        guard case .vstack(let stack) = defaulted.root else {
            return XCTFail("expected a VStackNode, got \(defaulted.root.kindName)")
        }
        XCTAssertEqual(stack.spacing, Theme.stackSpacing)
    }

    // MARK: - EDIT-ORIGIN-002

    /// EDIT-ORIGIN-002: two views written on one line are told apart by column.
    ///
    /// Without this the editor could not address either of them, because the
    /// only handle it has on a value is where it was written.
    func testEDIT_ORIGIN_002_twoViewsOnOneLineGetDistinctColumns() throws {
        let scene = Lowering.scene(from: OriginFixtures.pair)
        guard case .vstack(let stack) = scene.root else {
            return XCTFail("expected a VStackNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(stack.children.count, 2)

        let left = try XCTUnwrap(scene.origins[stack.children[0].id])
        let right = try XCTUnwrap(scene.origins[stack.children[1].id])

        XCTAssertEqual(left.construction.line, OriginFixtures.pairLine)
        XCTAssertEqual(right.construction.line, OriginFixtures.pairLine)
        XCTAssertNotEqual(
            left.construction.column,
            right.construction.column,
            "two views on one line must be distinguishable, or neither can be edited"
        )
        XCTAssertLessThan(left.construction.column, right.construction.column)
    }

    // MARK: - EDIT-ORIGIN-003

    /// EDIT-ORIGIN-003: the wrapper nodes containers synthesize record no
    /// origin. Nobody wrote them, and attributing the parent's position to them
    /// would aim an edit at an expression that does not hold the value.
    func testEDIT_ORIGIN_003_syntheticWrapperNodesHaveNoOrigin() throws {
        let scroll = Lowering.scene(from: OriginFixtures.scrollWithLooseChildren)
        guard case .scrollView(let viewport) = scroll.root else {
            return XCTFail("expected a ScrollViewNode, got \(scroll.root.kindName)")
        }
        XCTAssertNotNil(scroll.origins[viewport.id], "the ScrollView itself was written")
        XCTAssertEqual(viewport.content.id.description, "\(viewport.id.path)/wrap")
        XCTAssertNil(scroll.origins[viewport.content.id], "nobody wrote the wrapper")

        let list = Lowering.scene(from: OriginFixtures.listWithRows)
        guard case .scrollView(let listViewport) = list.root else {
            return XCTFail("expected a ScrollViewNode, got \(list.root.kindName)")
        }
        XCTAssertNotNil(list.origins[listViewport.id])
        XCTAssertEqual(listViewport.content.id.description, "\(listViewport.id.path)/rows")
        XCTAssertNil(list.origins[listViewport.content.id], "nobody wrote the rows container")
    }

    // MARK: - EDIT-ORIGIN-004

    /// EDIT-ORIGIN-004: every view still accepts its ordinary call form.
    ///
    /// Adding defaulted parameters after a closure parameter changes how Swift
    /// matches a trailing closure. `EveryViewFormApp` exercises every form in
    /// the API, so a regression here is a compile error rather than a puzzle in
    /// somebody's application.
    func testEDIT_ORIGIN_004_everyViewFormStillLowers() throws {
        let scene = Lowering.scene(from: EveryViewFormApp().body)
        guard case .vstack(let stack) = scene.root else {
            return XCTFail("expected a VStackNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(stack.children.count, 8)
        XCTAssertEqual(
            stack.children.map(\.kindName),
            [
                "TextNode",
                "ButtonNode",
                "ImageNode",
                "TextFieldNode",
                "ScrollViewNode",
                "ScrollViewNode",
                "NavigationStackNode",
                "ModalPresenterNode",
            ]
        )
        for child in stack.children {
            XCTAssertNotNil(scene.origins[child.id], "\(child.kindName) recorded no origin")
        }
    }

    // MARK: - STYLE-BRAND-001

    /// STYLE-BRAND-001: the Stage 2 default theme follows the locked brand palette from
    /// docs/Cider_DESIGN.md: dark technical surfaces, warm white text, and amber
    /// as the restrained accent instead of the old generic blue UI colour.
    func testSTYLE_BRAND_001_lockedPaletteDrivesTheMVPTheme() {
        XCTAssertEqual(Theme.ciderBlack.packed, 0xFF10100F)
        XCTAssertEqual(Theme.ciderGraphite.packed, 0xFF1C1C1A)
        XCTAssertEqual(Theme.ciderSurface.packed, 0xFF242421)
        XCTAssertEqual(Theme.ciderBorder.packed, 0xFF34342F)
        XCTAssertEqual(Theme.ciderMuted.packed, 0xFF8F8D86)
        XCTAssertEqual(Theme.ciderText.packed, 0xFFF5F1E8)
        XCTAssertEqual(Theme.ciderAmber.packed, 0xFFE89A2F)
        XCTAssertEqual(Theme.ciderAmberBright.packed, 0xFFFFB547)

        XCTAssertEqual(Theme.backgroundColor, Theme.ciderBlack)
        XCTAssertEqual(Theme.textColor, Theme.ciderText)
        XCTAssertEqual(Theme.accentColor, Theme.ciderAmber)
        XCTAssertEqual(Theme.accentPressedColor, Theme.ciderAmberBright)
        XCTAssertEqual(Theme.accentTextColor, Theme.ciderBlack)
        XCTAssertEqual(Theme.textFieldBackgroundColor, Theme.ciderSurface)
        XCTAssertEqual(Theme.buttonCornerRadius, 8)
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

    // MARK: - UI-IMAGE-001

    /// UI-IMAGE-001: an `Image` view becomes one ImageNode carrying its pixels.
    func testUI_IMAGE_001_imageLowersToAnImageNode() throws {
        let scene = Lowering.scene(from: ImageOnlyApp().body)

        guard case .image(let node) = scene.root else {
            return XCTFail("expected an ImageNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(node.source.width, 12)
        XCTAssertEqual(node.source.height, 8)
        XCTAssertTrue(scene.actions.isEmpty, "an image is not interactive")
    }

    /// UI-IMAGE-001: an image is sized to its source's pixel dimensions, with
    /// no separate resizing modifier in the MVP.
    func testUI_IMAGE_001_imageIsSizedToItsIntrinsicDimensions() throws {
        let harness = try ConformanceHarness(ImageOnlyApp())
        try harness.launch()

        let box = try XCTUnwrap(harness.runtime.currentLayout)
        XCTAssertEqual(box.frame.width, 12, accuracy: 1e-9)
        XCTAssertEqual(box.frame.height, 8, accuracy: 1e-9)
    }

    /// UI-IMAGE-001: an image draws as a single `.image` render command
    /// carrying its placed frame and its source pixels, and publishes no hit
    /// region -- an image is not interactive in the MVP.
    func testUI_IMAGE_001_imageDrawsAsARenderCommand() throws {
        let harness = try ConformanceHarness(ImageOnlyApp())
        try harness.launch()

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        XCTAssertEqual(tree.commands.count, 1)
        XCTAssertTrue(tree.hitRegions.isEmpty)

        guard case .image(let rect, let source) = tree.commands[0] else {
            return XCTFail("expected an image command")
        }

        let box = try XCTUnwrap(harness.runtime.currentLayout)
        XCTAssertEqual(rect, box.frame)
        XCTAssertEqual(source.width, 12)
        XCTAssertEqual(source.height, 8)
    }

    // MARK: - UI-SCROLL-001

    /// UI-SCROLL-001: a `ScrollView` becomes one ScrollViewNode at its
    /// explicit viewport size, wrapping its content.
    func testUI_SCROLL_001_scrollViewLowersToAScrollViewNode() throws {
        struct App: CiderApp {
            var body: some CiderView {
                ScrollView(width: 100, height: 20) { Text("Hello") }
            }
        }

        let scene = Lowering.scene(from: App().body)
        guard case .scrollView(let node) = scene.root else {
            return XCTFail("expected a ScrollViewNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(node.viewportSize, Size(width: 100, height: 20))
        guard case .text(let text) = node.content else {
            return XCTFail("expected the scroll view's content to be the Text directly")
        }
        XCTAssertEqual(text.text, "Hello")
    }

    /// UI-SCROLL-001: the viewport is sized exactly as declared, and its
    /// content is laid out at its own natural size -- taller than the
    /// viewport here, which is the point of a scroll view.
    func testUI_SCROLL_001_viewportIsExplicitAndContentCanBeTaller() throws {
        let harness = try ConformanceHarness(ScrollTestApp())
        try harness.launch()

        let box = try XCTUnwrap(harness.runtime.currentLayout)
        XCTAssertEqual(box.frame.width, 100, accuracy: 1e-9)
        XCTAssertEqual(box.frame.height, 20, accuracy: 1e-9)

        let content = try XCTUnwrap(box.children.first)
        XCTAssertGreaterThan(content.frame.height, box.frame.height)
        XCTAssertEqual(content.frame.height, 72, accuracy: 1e-9, "2 rows + a button + a row, all at 10pt")
    }

    /// UI-SCROLL-001: the scroll view's content is bracketed by a matching
    /// pushClip/popClip pair -- nothing else is drawn between them, since the
    /// scroll view is this app's only content.
    func testUI_SCROLL_001_contentIsClipped() throws {
        let harness = try ConformanceHarness(ScrollTestApp())
        try harness.launch()

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        guard case .pushClip = tree.commands.first else {
            return XCTFail("expected the first command to be pushClip, got \(tree.commands.first as Any)")
        }
        guard case .popClip = tree.commands.last else {
            return XCTFail("expected the last command to be popClip, got \(tree.commands.last as Any)")
        }
    }

    /// UI-SCROLL-001: a button scrolled entirely out of the viewport cannot
    /// be tapped at its unscrolled position -- hit-testing must agree with
    /// what's actually visible, not with the content's full, unclipped extent.
    func testUI_SCROLL_001_contentOutsideTheViewportIsNotHittable() throws {
        let harness = try ConformanceHarness(ScrollTestApp())
        try harness.launch()

        // The button sits at content y 24...60; the viewport shows only 0...20.
        // Tapping anywhere in the button's full-content vertical range, at the
        // viewport's own (visible) horizontal position, must not hit it.
        let viewport = try XCTUnwrap(harness.runtime.currentRenderTree?.scrollRegions.first)
        try harness.tap(at: Point(x: viewport.frame.midX, y: viewport.frame.minY + 24 + 5))

        XCTAssertTrue(harness.drawnStrings().contains("Count: 0"), "the button must not have been reachable")
    }

    /// UI-SCROLL-001: scrolling moves the content, and a control that scrolls
    /// into view becomes tappable at its new, on-screen position.
    func testUI_SCROLL_001_scrollingBringsContentIntoViewAndItBecomesTappable() throws {
        let harness = try ConformanceHarness(ScrollTestApp())
        try harness.launch()

        let viewport = try XCTUnwrap(harness.runtime.currentRenderTree?.scrollRegions.first)
        let scrollViewID = viewport.id

        // Scroll, one notch (ApplicationRuntime.scrollNotchDistance's default
        // 40pt) at a time, until the button's top (content y 24) has cleared
        // the viewport's top edge. Bounded rather than an unconditional
        // `while` so a scrolling regression fails the assertion below instead
        // of hanging the suite.
        for _ in 0..<10 where harness.runtime.currentScrollOffset(for: scrollViewID).y < 24 {
            try harness.deliver([
                .scroll(location: Point(x: viewport.frame.midX, y: viewport.frame.midY), deltaX: 0, deltaY: 1),
            ])
        }

        let offset = harness.runtime.currentScrollOffset(for: scrollViewID)
        XCTAssertGreaterThanOrEqual(offset.y, 24)

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        let button = try XCTUnwrap(tree.hitRegions.first, "the button should now be at least partly visible")
        try harness.tap(at: Point(x: button.frame.midX, y: button.frame.midY))

        XCTAssertTrue(harness.drawnStrings().contains("Count: 1"), "the button is now visible and must be tappable")
    }

    /// UI-SCROLL-001: scrolling cannot push content past its own end.
    func testUI_SCROLL_001_scrollingClampsAtTheContentsEnd() throws {
        let harness = try ConformanceHarness(ScrollTestApp())
        try harness.launch()

        let viewport = try XCTUnwrap(harness.runtime.currentRenderTree?.scrollRegions.first)
        let scrollViewID = viewport.id

        // Content is 72pt tall, the viewport 20pt: the maximum offset is 52.
        // 20 notches at 40pt each is far more than enough to over-scroll.
        for _ in 0..<20 {
            try harness.deliver([
                .scroll(location: Point(x: viewport.frame.midX, y: viewport.frame.midY), deltaX: 0, deltaY: 1),
            ])
        }

        XCTAssertEqual(harness.runtime.currentScrollOffset(for: scrollViewID).y, 52, accuracy: 1e-9)
    }

    /// UI-SCROLL-001: scrolling cannot push content before its own start.
    func testUI_SCROLL_001_scrollingClampsAtTheStart() throws {
        let harness = try ConformanceHarness(ScrollTestApp())
        try harness.launch()

        let viewport = try XCTUnwrap(harness.runtime.currentRenderTree?.scrollRegions.first)
        let scrollViewID = viewport.id

        try harness.deliver([
            .scroll(location: Point(x: viewport.frame.midX, y: viewport.frame.midY), deltaX: 0, deltaY: -5),
        ])

        XCTAssertEqual(harness.runtime.currentScrollOffset(for: scrollViewID).y, 0, accuracy: 1e-9)
    }

    // MARK: - UI-TEXTFIELD-001

    /// UI-TEXTFIELD-001: a `TextField` becomes one TextFieldNode carrying the
    /// bound state's current value, with a registered text handler and no
    /// action -- it is editable, not tappable-as-a-button.
    func testUI_TEXTFIELD_001_textFieldLowersToATextFieldNode() throws {
        let scene = Lowering.scene(from: TextFieldTestApp().body)
        guard case .textField(let node) = scene.root else {
            return XCTFail("expected a TextFieldNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(node.text, "")
        XCTAssertEqual(node.width, 100)
        XCTAssertEqual(scene.textInputHandlers.count, 1)
        XCTAssertTrue(scene.actions.isEmpty, "a text field is not a button")
    }

    /// UI-TEXTFIELD-001: tapping a text field gives it focus; tapping
    /// somewhere else takes focus away.
    func testUI_TEXTFIELD_001_tappingSetsFocusAndTappingElsewhereClearsIt() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()

        XCTAssertNil(harness.runtime.currentFocusedNode)

        let field = try XCTUnwrap(harness.runtime.currentRenderTree?.hitRegions.first)
        try harness.tap(at: Point(x: field.frame.midX, y: field.frame.midY))
        XCTAssertEqual(harness.runtime.currentFocusedNode, field.id)

        try harness.tap(at: Point(x: field.frame.maxX + 50, y: field.frame.maxY + 50))
        XCTAssertNil(harness.runtime.currentFocusedNode)
    }

    /// UI-TEXTFIELD-001: typing while focused appends to the bound state,
    /// and the next frame shows it -- the same state -> invalidate ->
    /// rebuild loop a button's action already goes through.
    func testUI_TEXTFIELD_001_typingWhileFocusedAppendsToTheBoundState() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()
        let field = try XCTUnwrap(harness.runtime.currentRenderTree?.hitRegions.first)

        try harness.tap(at: Point(x: field.frame.midX, y: field.frame.midY))

        for character in "hi" {
            try harness.deliver([.keyDown(keyCode: Int(character.unicodeScalars.first!.value))])
        }

        XCTAssertTrue(harness.drawnStrings().contains("hi"))
    }

    /// UI-TEXTFIELD-001: composed text events append the host-provided text while focused.
    func testUI_TEXTFIELD_001_textInputWhileFocusedAppendsComposedText() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()
        let field = try XCTUnwrap(harness.runtime.currentRenderTree?.hitRegions.first)

        try harness.tap(at: Point(x: field.frame.midX, y: field.frame.midY))
        try harness.deliver([.textInput("hé")])

        XCTAssertTrue(harness.drawnStrings().contains("hé"))
    }

    /// UI-TEXTFIELD-001: backspace removes one character from the end.
    func testUI_TEXTFIELD_001_backspaceRemovesTheLastCharacter() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()

        let field = try XCTUnwrap(harness.runtime.currentRenderTree?.hitRegions.first)
        try harness.tap(at: Point(x: field.frame.midX, y: field.frame.midY))

        for character in "cat" {
            try harness.deliver([.keyDown(keyCode: Int(character.unicodeScalars.first!.value))])
        }
        XCTAssertTrue(harness.drawnStrings().contains("cat"))

        try harness.deliver([.keyDown(keyCode: 0xFF08)])
        XCTAssertTrue(harness.drawnStrings().contains("ca"))
        XCTAssertFalse(harness.drawnStrings().contains("cat"))
    }

    /// UI-TEXTFIELD-001: backspace on an empty field has nothing to remove,
    /// and must not redraw for no reason.
    func testUI_TEXTFIELD_001_backspaceOnAnEmptyFieldDoesNothing() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()

        let field = try XCTUnwrap(harness.runtime.currentRenderTree?.hitRegions.first)
        try harness.tap(at: Point(x: field.frame.midX, y: field.frame.midY))

        let framesBefore = harness.backend.presentedFrames.count
        try harness.deliver([.keyDown(keyCode: 0xFF08)])

        XCTAssertEqual(harness.backend.presentedFrames.count, framesBefore)
    }

    /// UI-TEXTFIELD-001: typing while nothing is focused reaches no field.
    func testUI_TEXTFIELD_001_typingWhileUnfocusedDoesNothing() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()

        XCTAssertNil(harness.runtime.currentFocusedNode)
        try harness.deliver([.keyDown(keyCode: Int(UnicodeScalar("x").value))])

        XCTAssertFalse(harness.drawnStrings().contains("x"))
    }

    /// UI-TEXTFIELD-001: a key outside backspace and the printable ASCII
    /// range (an arrow key, here) is not mapped to an edit and must not
    /// redraw for no reason.
    func testUI_TEXTFIELD_001_unmappedKeysAreIgnored() throws {
        let harness = try ConformanceHarness(TextFieldTestApp())
        try harness.launch()

        let field = try XCTUnwrap(harness.runtime.currentRenderTree?.hitRegions.first)
        try harness.tap(at: Point(x: field.frame.midX, y: field.frame.midY))

        let framesBefore = harness.backend.presentedFrames.count
        try harness.deliver([.keyDown(keyCode: 0xFF52)])

        XCTAssertEqual(harness.backend.presentedFrames.count, framesBefore)
    }

    // MARK: - UI-LIST-001

    /// UI-LIST-001: a `List` lowers to a ScrollViewNode wrapping a VStack of
    /// its rows -- there is no dedicated node kind, this pairing *is* the
    /// implementation.
    func testUI_LIST_001_listLowersToAScrollViewWrappingItsRows() throws {
        struct App: CiderApp {
            var body: some CiderView {
                List(width: 100, height: 50) {
                    Text("a")
                    Text("b")
                    Text("c")
                }
            }
        }

        let scene = Lowering.scene(from: App().body)
        guard case .scrollView(let scroll) = scene.root else {
            return XCTFail("expected a ScrollViewNode, got \(scene.root.kindName)")
        }
        XCTAssertEqual(scroll.viewportSize, Size(width: 100, height: 50))

        guard case .vstack(let rows) = scroll.content else {
            return XCTFail("expected the list's content to be a VStack of rows")
        }
        XCTAssertEqual(rows.children.map(\.kindName), ["TextNode", "TextNode", "TextNode"])
    }

    /// UI-LIST-001: rows keep source order -- the same structural,
    /// index-based identity every other container already uses. Every row's
    /// title draws regardless of scroll position (draw commands aren't
    /// clip-filtered, only hit regions are -- B4's fix), so this reads
    /// order directly off what's drawn rather than off what's currently
    /// reachable by touch.
    func testUI_LIST_001_rowsKeepSourceOrder() throws {
        let harness = try ConformanceHarness(ListTestApp())
        try harness.launch()

        let titles = harness.drawnStrings().filter { $0.hasPrefix("Row ") }
        XCTAssertEqual(titles, (0..<10).map { "Row \($0)" })

        // The 30pt viewport is shorter than one 36pt row, so only the first
        // row's button is even partly visible at launch -- the rest are
        // legitimately unreachable until scrolled into view (see the next
        // test), not a bug in this assertion.
        XCTAssertEqual(harness.runtime.currentRenderTree?.hitRegions.count, 1)
    }

    /// UI-LIST-001: a list scrolls exactly like the ScrollView it's built
    /// from -- a row far down the list, initially clipped out entirely,
    /// becomes tappable once scrolled into view, and firing its action is
    /// visible on the next frame.
    func testUI_LIST_001_aRowFarDownTheListBecomesTappableOnceScrolledIntoView() throws {
        let harness = try ConformanceHarness(ListTestApp())
        try harness.launch()

        let viewport = try XCTUnwrap(harness.runtime.currentRenderTree?.scrollRegions.first)

        // Row 9 sits at content y 324...360, the trailing status row at
        // 360...372, and the 30pt viewport clamps at content end (372 - 30 =
        // 342): far enough that row 9 starts entirely out of view.
        for _ in 0..<10 {
            try harness.deliver([
                .scroll(location: Point(x: viewport.frame.midX, y: viewport.frame.midY), deltaX: 0, deltaY: 1),
            ])
        }

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        let visibleRow = try XCTUnwrap(tree.hitRegions.last, "row 9 should be the only button left in view")
        try harness.tap(at: Point(x: visibleRow.frame.midX, y: visibleRow.frame.midY))

        XCTAssertTrue(harness.drawnStrings().contains("Last: 9"), "tapping the visible row must fire row 9's action")
    }

    // MARK: - NAV-PUSH-001

    /// NAV-PUSH-001: a `NavigationView` becomes one NavigationStackNode whose
    /// content is the root screen when nothing has been pushed yet.
    func testNAV_PUSH_001_navigationViewLowersToANavigationStackNode() throws {
        let scene = Lowering.scene(from: NavigationTestApp().body)

        guard case .navigationStack(let nav) = scene.root else {
            return XCTFail("expected a NavigationStackNode, got \(scene.root.kindName)")
        }
        guard case .vstack(let root) = nav.content else {
            return XCTFail("expected the root screen's VStack as content, got \(nav.content.kindName)")
        }
        XCTAssertEqual(root.children.map(\.kindName), ["TextNode", "ButtonNode"])
    }

    /// NAV-PUSH-001: unlike every other node kind, the active screen fills
    /// the whole safe area rather than being sized to its own content and
    /// centred within it -- `layoutCentered` proposing its own bounds is
    /// what makes this happen (see `LayoutEngine.measure`'s
    /// `.navigationStack` case).
    func testNAV_PUSH_001_theActiveScreenFillsTheSafeArea() throws {
        let harness = try ConformanceHarness(NavigationTestApp())
        try harness.launch()

        let box = try XCTUnwrap(harness.runtime.currentLayout)
        let safeArea = harness.runtime.deviceProfile.safeAreaBounds
        XCTAssertEqual(box.frame.width, safeArea.width, accuracy: 1e-9)
        XCTAssertEqual(box.frame.height, safeArea.height, accuracy: 1e-9)
    }

    /// NAV-PUSH-001: tapping a button that appends to the bound path pushes
    /// a new screen -- the next frame shows it in place of the root, not
    /// layered underneath it (there is no screen history in the tree, only
    /// ever the one currently on top; see `NavigationStackNode`'s doc
    /// comment).
    func testNAV_PUSH_001_tappingPushesANewScreen() throws {
        let harness = try ConformanceHarness(NavigationTestApp())
        try harness.launch()

        XCTAssertTrue(harness.drawnStrings().contains("Root"))
        XCTAssertFalse(harness.drawnStrings().contains("Detail"))

        let go = try harness.onlyButton()
        try harness.tap(at: Point(x: go.frame.midX, y: go.frame.midY))

        XCTAssertTrue(harness.drawnStrings().contains("Detail"))
        XCTAssertFalse(
            harness.drawnStrings().contains("Root"),
            "the root screen is replaced by the pushed one, not layered under it"
        )
    }

    // MARK: - NAV-POP-001

    /// NAV-POP-001: tapping a button that removes the last path entry pops
    /// back to the screen underneath -- the root, here.
    func testNAV_POP_001_tappingPopsBackToThePreviousScreen() throws {
        let harness = try ConformanceHarness(NavigationTestApp())
        try harness.launch()

        let go = try harness.onlyButton()
        try harness.tap(at: Point(x: go.frame.midX, y: go.frame.midY))
        XCTAssertTrue(harness.drawnStrings().contains("Detail"))

        let back = try harness.onlyButton()
        try harness.tap(at: Point(x: back.frame.midX, y: back.frame.midY))

        XCTAssertTrue(harness.drawnStrings().contains("Root"))
        XCTAssertFalse(harness.drawnStrings().contains("Detail"))
    }

    /// NAV-POP-001: a pushed screen and the root occupy the same structural
    /// position (each is the navigation stack's one `content` child), so a
    /// pop returns the same structural identity the root had before the
    /// push -- consistent with, not a new instance of, the index-based
    /// identity scheme every other container already uses (ADR 0003).
    func testNAV_POP_001_poppingReturnsTheSameStructuralIdentityTheRootHad() throws {
        let harness = try ConformanceHarness(NavigationTestApp())
        try harness.launch()
        let rootButtonID = try harness.onlyButton().id

        try harness.tap(at: try harness.center(of: rootButtonID))
        let detailButtonID = try harness.onlyButton().id
        try harness.tap(at: try harness.center(of: detailButtonID))
        let poppedButtonID = try harness.onlyButton().id

        XCTAssertEqual(poppedButtonID, rootButtonID)
    }

    // MARK: - UI-MODAL-001

    /// UI-MODAL-001: a `Modal` becomes one ModalPresenterNode; while nothing
    /// is presented its `presented` field is nil, and the base content is
    /// what lowers into `content`.
    func testUI_MODAL_001_modalLowersToAModalPresenterNode() throws {
        let scene = Lowering.scene(from: ModalTestApp().body)

        guard case .modal(let modal) = scene.root else {
            return XCTFail("expected a ModalPresenterNode, got \(scene.root.kindName)")
        }
        XCTAssertNil(modal.presented)
        guard case .vstack(let base) = modal.content else {
            return XCTFail("expected the base screen's VStack as content, got \(modal.content.kindName)")
        }
        XCTAssertEqual(base.children.map(\.kindName), ["TextNode", "ButtonNode"])
    }

    /// UI-MODAL-001: with nothing presented, only the base content draws --
    /// no dim overlay -- and the base's one button is the only hit region.
    func testUI_MODAL_001_nothingPresentedDrawsOnlyTheBase() throws {
        let harness = try ConformanceHarness(ModalTestApp())
        try harness.launch()

        XCTAssertTrue(harness.drawnStrings().contains("Base"))
        XCTAssertFalse(harness.drawnStrings().contains("Presented"))
        XCTAssertEqual(harness.runtime.currentRenderTree?.hitRegions.count, 1)
    }

    /// UI-MODAL-001: presenting draws a dimming overlay after the base
    /// content, then the presented content after that -- painter's order
    /// puts what's presented visually on top, the same as a button's label
    /// painting after its own background.
    func testUI_MODAL_001_presentingDrawsTheOverlayAndPresentedContentOnTop() throws {
        let harness = try ConformanceHarness(ModalTestApp())
        try harness.launch()

        let present = try harness.onlyButton()
        try harness.tap(at: Point(x: present.frame.midX, y: present.frame.midY))

        XCTAssertTrue(harness.drawnStrings().contains("Base"), "the base still draws, dimmed underneath")
        XCTAssertTrue(harness.drawnStrings().contains("Presented"))

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        var baseIndex: Int?
        var overlayIndex: Int?
        var presentedIndex: Int?
        for (index, command) in tree.commands.enumerated() {
            switch command {
            case .text(let content, _, _, _) where content == "Base":
                baseIndex = index
            case .text(let content, _, _, _) where content == "Presented":
                presentedIndex = index
            case .fillRect(_, let color, _) where color == Theme.modalOverlayColor:
                overlayIndex = index
            default:
                break
            }
        }

        let base = try XCTUnwrap(baseIndex, "expected the base's text to have drawn")
        let overlay = try XCTUnwrap(overlayIndex, "expected a dim-overlay fill")
        let presented = try XCTUnwrap(presentedIndex, "expected the presented content's text to have drawn")
        XCTAssertLessThan(base, overlay, "the overlay paints after the base")
        XCTAssertLessThan(overlay, presented, "and before the presented content")
    }

    /// UI-MODAL-001: while presented, a tap on the dimmed area is swallowed
    /// rather than reaching the base content underneath -- an enabled hit
    /// region with no registered action still blocks `hitTest`'s reversed
    /// scan from ever reaching what the overlay visually covers.
    func testUI_MODAL_001_tappingTheDimmedOverlayDoesNotReachTheBase() throws {
        let harness = try ConformanceHarness(ModalTestApp())
        try harness.launch()

        let present = try harness.onlyButton()
        try harness.tap(at: Point(x: present.frame.midX, y: present.frame.midY))
        XCTAssertTrue(harness.drawnStrings().contains("Presented"))

        // Both screens lay out top-anchored (see LayoutEngine.place's
        // `.modal`/`.navigationStack` cases), so a point near the bottom of
        // the safe area is reliably clear of either screen's controls.
        let safeArea = harness.runtime.deviceProfile.safeAreaBounds
        try harness.tap(at: Point(x: safeArea.midX, y: safeArea.maxY - 2))

        XCTAssertTrue(harness.drawnStrings().contains("Presented"), "the modal must still be showing")
    }

    /// UI-MODAL-001: tapping the presented content's own dismiss button
    /// hides it, returning to the base content alone.
    func testUI_MODAL_001_dismissingHidesThePresentedContent() throws {
        let harness = try ConformanceHarness(ModalTestApp())
        try harness.launch()

        let present = try harness.onlyButton()
        try harness.tap(at: Point(x: present.frame.midX, y: present.frame.midY))
        XCTAssertTrue(harness.drawnStrings().contains("Presented"))

        let tree = try XCTUnwrap(harness.runtime.currentRenderTree)
        let dismiss = try XCTUnwrap(
            tree.hitRegions.last,
            "the dismiss button, appended last, should be the topmost hit region"
        )
        try harness.tap(at: Point(x: dismiss.frame.midX, y: dismiss.frame.midY))

        XCTAssertFalse(harness.drawnStrings().contains("Presented"))
        XCTAssertTrue(harness.drawnStrings().contains("Base"))
    }
}
