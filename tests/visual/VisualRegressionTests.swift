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
        pressed: NodeID? = nil
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
