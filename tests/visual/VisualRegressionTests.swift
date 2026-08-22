//  Visual regression tests.
//
//  docs/06-testing-strategy.md scopes these precisely: they validate Cider's own
//  renderer against Cider's own baselines. They are not a comparison with any
//  other platform's output and must never be described as one.
//
//  Two decisions make these deterministic enough to be worth having.
//
//  They use `DeterministicTextEngine`, so nothing depends on which fonts the
//  machine has or which FreeType version rasterized them. Real glyph
//  rasterization is not reproducible across hosts, and a baseline that changes
//  with the font package is a baseline nobody trusts.
//
//  And they call layout and the rasterizer directly rather than going through
//  the runtime, so a scene can be small. A full phone frame would be a megabyte
//  of baseline per case.
//
//  To re-record after an intended change:
//
//      CIDER_UPDATE_BASELINES=1 swift test --filter CiderVisualTests
//
//  then read the diff before committing it. A baseline updated without looking
//  at the image is a test that has been switched off.

import XCTest

import CiderCore
import CiderHostTesting
import CiderUI
import CiderUITree

final class VisualRegressionTests: XCTestCase {

    private let engine = DeterministicTextEngine(scale: 1)

    private var baselineDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Baselines")
    }

    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["CIDER_UPDATE_BASELINES"] == "1"
    }

    // MARK: - Scenes

    /// The reference screen, at a size small enough to keep the baseline small.
    func testCounterScreen() throws {
        let view = VStack(spacing: 8) {
            Text("Cider Demo").font(size: 14, weight: .bold)
            Button("Press Me") {}
            Text("Count: 0").font(size: 10)
        }

        try assertMatchesBaseline(
            render(view, width: 200, height: 130),
            named: "counter-screen"
        )
    }

    /// The same screen with the button held down, which is the only state change
    /// the renderer draws differently today.
    func testCounterScreenPressed() throws {
        let view = VStack(spacing: 8) {
            Text("Cider Demo").font(size: 14, weight: .bold)
            Button("Press Me") {}
            Text("Count: 0").font(size: 10)
        }

        let scene = Lowering.scene(from: view)
        let button = try XCTUnwrap(firstButtonID(in: scene.root))

        try assertMatchesBaseline(
            render(view, width: 200, height: 130, pressed: button),
            named: "counter-screen-pressed"
        )
    }

    /// Corner antialiasing on its own, so a change in the rounded-rectangle
    /// coverage function is visible without the text drowning it out.
    func testRoundedRectangleCorners() throws {
        let canvas = renderShape(
            .fillRect(
                rect: Rect(x: 8, y: 8, width: 48, height: 24),
                color: Color(hex: 0x1F6FEB),
                cornerRadius: 12
            )
        )
        try assertMatchesBaseline(canvas, named: "rounded-rectangle")
    }

    /// A radius larger than half the shorter side must clamp to a capsule rather
    /// than inverting the corner arc.
    func testOversizedCornerRadiusClampsToACapsule() throws {
        let canvas = renderShape(
            .fillRect(
                rect: Rect(x: 8, y: 12, width: 48, height: 16),
                color: Color(hex: 0x1F6FEB),
                cornerRadius: 999
            )
        )
        try assertMatchesBaseline(canvas, named: "capsule")
    }

    /// Image rendering through a real scene, so the nearest-neighbour sampler is
    /// covered by a reviewable pixel baseline rather than unit tests alone.
    func testImageScreen() throws {
        let source = ImageSource(
            width: 12,
            height: 8,
            pixels: checkerboardPixels(width: 12, height: 8)
        )
        let view = VStack(spacing: 8) {
            Text("Image")
                .font(size: 12, weight: .bold)
            Image(source)
        }

        try assertMatchesBaseline(render(view, width: 120, height: 90), named: "image-screen")
    }

    /// ScrollView clipping is visual: rows outside the viewport must not paint.
    func testScrollViewScreen() throws {
        let view = ScrollView(width: 96, height: 36) {
            VStack(spacing: 0) {
                Text("Row 0").font(size: 10)
                Text("Row 1").font(size: 10)
                Text("Row 2").font(size: 10)
                Text("Row 3").font(size: 10)
            }
        }

        try assertMatchesBaseline(render(view, width: 140, height: 90), named: "scroll-view-screen")
    }

    /// A focused TextField has distinct renderer output: the text box plus its
    /// caret. This keeps the focus-specific drawing path under visual coverage.
    func testTextFieldFocusedScreen() throws {
        let text = CiderState(wrappedValue: "Bud")
        let view = TextField(text, width: 100).font(size: 12)
        let scene = Lowering.scene(from: view)
        let focused = try XCTUnwrap(firstTextFieldID(in: scene.root))

        try assertMatchesBaseline(
            render(view, width: 140, height: 80, focused: focused),
            named: "text-field-focused-screen"
        )
    }

    /// List is implemented as a scroll view over rows; this baseline guards the
    /// composition rather than introducing a fake List-specific renderer path.
    func testListScreen() throws {
        let view = List(width: 96, height: 48, spacing: 2) {
            Text("Alpha").font(size: 10)
            Text("Beta").font(size: 10)
            Text("Gamma").font(size: 10)
            Text("Delta").font(size: 10)
        }

        try assertMatchesBaseline(render(view, width: 140, height: 100), named: "list-screen")
    }

    /// NavigationView fills the proposed root bounds, so a visual baseline catches
    /// regressions where the active screen collapses back to intrinsic centering.
    func testNavigationScreen() throws {
        let path = CiderState<[any CiderView]>(wrappedValue: [])
        let view = NavigationView(path) {
            VStack(spacing: 8) {
                Text("Root").font(size: 12, weight: .bold)
                Button("Open") {}
            }
        }

        try assertMatchesBaseline(render(view, width: 160, height: 110), named: "navigation-screen")
    }

    /// A presented Modal draws base content, a dim overlay and presented content
    /// in painter's order. That z-order is easier to trust as a baseline than as
    /// a long list of command-order assertions alone.
    func testModalPresentedScreen() throws {
        let isPresented = CiderState(wrappedValue: true)
        let view = Modal(isPresented) {
            VStack(spacing: 8) {
                Text("Base").font(size: 12)
                Button("Present") {}
            }
        } presenting: {
            VStack(spacing: 8) {
                Text("Presented").font(size: 12, weight: .bold)
                Button("Dismiss") {}
            }
        }

        try assertMatchesBaseline(render(view, width: 160, height: 110), named: "modal-presented-screen")
    }

    // MARK: - Properties that hold regardless of baseline

    /// Rendering the same scene twice must produce identical pixels. If this
    /// fails, every baseline in the suite is meaningless.
    func testRenderingIsDeterministic() {
        let view = VStack(spacing: 8) {
            Text("Cider Demo").font(size: 14, weight: .bold)
            Button("Press Me") {}
        }

        let first = render(view, width: 200, height: 130)
        let second = render(view, width: 200, height: 130)
        XCTAssertEqual(first.pixels, second.pixels)
    }

    /// Baselines round-trip through the file format without loss.
    func testPPMRoundTrip() throws {
        var canvas = Canvas(width: 3, height: 2, fill: Color(hex: 0x102030))
        canvas.blend(x: 1, y: 1, color: Color(hex: 0xFFCC00))

        let decoded = try PPM.decode(PPM.encode(canvas))
        XCTAssertEqual(decoded, PPM.image(from: canvas))
    }

    // MARK: - Helpers

    private func render(
        _ view: some CiderView,
        width: Int,
        height: Int,
        pressed: NodeID? = nil,
        focused: NodeID? = nil,
        scrollOffsets: [NodeID: Point] = [:]
    ) -> Canvas {
        let scene = Lowering.scene(from: view)
        let context = LayoutContext(textEngine: engine)
        let bounds = Rect(x: 0, y: 0, width: Double(width), height: Double(height))

        let layout = LayoutEngine.layoutCentered(scene.root, in: bounds, context: context)
        let tree = RenderTreeBuilder.build(
            node: scene.root,
            layout: layout,
            backgroundColor: Theme.backgroundColor,
            pressedNode: pressed,
            focusedNode: focused,
            scrollOffsets: scrollOffsets,
            context: context
        )

        return Rasterizer.render(
            tree,
            pixelWidth: width,
            pixelHeight: height,
            scale: 1,
            textEngine: engine
        )
    }

    /// Rasterizes one drawing command on a white field, through the same public
    /// entry point the runtime uses.
    private func renderShape(_ command: RenderCommand) -> Canvas {
        Rasterizer.render(
            RenderTree(backgroundColor: Color(hex: 0xFFFFFF), commands: [command]),
            pixelWidth: 64,
            pixelHeight: 40,
            scale: 1,
            textEngine: engine
        )
    }

    private func firstButtonID(in node: UINode) -> NodeID? {
        if case .button(let button) = node { return button.id }
        for child in node.children {
            if let found = firstButtonID(in: child) { return found }
        }
        return nil
    }

    private func firstTextFieldID(in node: UINode) -> NodeID? {
        if case .textField(let field) = node { return field.id }
        for child in node.children {
            if let found = firstTextFieldID(in: child) { return found }
        }
        return nil
    }

    private func checkerboardPixels(width: Int, height: Int) -> [UInt8] {
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let isAccent = (x / 3 + y / 2).isMultiple(of: 2)
                if isAccent {
                    pixels.append(contentsOf: [0x1F, 0x6F, 0xEB, 0xFF])
                } else {
                    pixels.append(contentsOf: [0xFF, 0xCC, 0x00, 0xFF])
                }
            }
        }
        return pixels
    }

    private func assertMatchesBaseline(
        _ canvas: Canvas,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let url = baselineDirectory.appendingPathComponent("\(name).ppm")

        if isRecording {
            try FileManager.default.createDirectory(
                at: baselineDirectory,
                withIntermediateDirectories: true
            )
            try PPM.encode(canvas).write(to: url)
            // Not a pass: a recording run has asserted nothing.
            XCTFail(
                "recorded baseline \(name).ppm; re-run without CIDER_UPDATE_BASELINES to verify",
                file: file,
                line: line
            )
            return
        }

        guard let data = FileManager.default.contents(atPath: url.path) else {
            XCTFail(
                """
                no baseline for `\(name)`.
                Record one with: CIDER_UPDATE_BASELINES=1 swift test --filter CiderVisualTests
                """,
                file: file,
                line: line
            )
            return
        }

        let baseline = try PPM.decode(data)
        let rendered = PPM.image(from: canvas)

        guard let comparison = ImageComparison.compare(rendered, baseline) else {
            XCTFail(
                """
                `\(name)` changed size: rendered \(rendered.width)x\(rendered.height), \
                baseline \(baseline.width)x\(baseline.height)
                """,
                file: file,
                line: line
            )
            return
        }

        XCTAssertTrue(
            comparison.matches,
            "`\(name)` does not match its baseline: \(comparison.summary)",
            file: file,
            line: line
        )
    }
}
