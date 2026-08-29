//  The runtime core.
//
//  Responsibilities, per docs/03-technical-architecture.md section C: lifecycle,
//  the event loop, invalidation, render scheduling, the device profile and
//  logging. Explicitly *not* its responsibility: knowing what host it is on,
//  parsing manifests, or building views.
//
//  The loop is exposed two ways. `run()` is what an application binary calls and
//  blocks until the window closes. `pump()` performs exactly one iteration and
//  returns, which is what tests drive -- a conformance test that had to spawn a
//  window and race a real event loop would be a flaky test about threading
//  rather than a test about behaviour.

import Foundation
import CiderCore
import CiderDeviceProfiles
import CiderHost
import CiderInspector
import CiderUITree

public final class ApplicationRuntime: InvalidationTarget {

    // MARK: - Configuration

    public let descriptor: LaunchDescriptor
    public let deviceProfile: DeviceProfile

    private let backend: HostBackend
    private let application: RuntimeApplication
    private let logSink: LogSink
    private let log: Logger

    // MARK: - Host resources
    //
    // Created in `launch()` rather than in `init` so that a failure to reach the
    // display is reported by the call the developer made, not by a constructor.

    private var window: HostWindow?
    private var textEngine: TextEngine?
    private var context: RuntimeContext?

    // MARK: - Frame state

    public private(set) var state: ApplicationState = .notRunning

    /// Seconds between frame-mirror writes. See `writeFrameMirrorIfNeeded`.
    private static let frameMirrorMinimumInterval: TimeInterval = 0.2

    /// When the last frame mirror was written, or nil if none has been.
    private var lastFrameMirrorTime: TimeInterval?

    private var scene: ApplicationScene?
    private var renderTree: RenderTree?
    private var lastLayout: LayoutBox?

    /// The application's view description is stale and must be rebuilt.
    private var needsRebuild = true

    /// The framebuffer is stale and must be redrawn and presented. Rebuilding
    /// always implies redrawing; the reverse is not true (an expose event, or a
    /// button changing to its pressed appearance, redraws without rebuilding).
    private var needsRender = true

    /// The button currently held down, if any.
    private var pressedNode: NodeID?

    /// The node with keyboard focus, if any. Set by tapping a text field;
    /// cleared by tapping anything else, or by that node vanishing in a
    /// rebuild -- the same reasoning `pressedNode` already has for touch.
    private var focusedNode: NodeID?

    /// Current scroll position of every scroll view that has one, keyed by
    /// identity. A view not in this dictionary is at (0, 0); an entry is
    /// pruned when its node disappears in a rebuild, the same reasoning as
    /// `pressedNode`/`focusedNode`.
    private var scrollOffsets: [NodeID: Point] = [:]

    /// Frames presented since launch. Exposed for tests and the inspector.
    public private(set) var frameCount = 0

    // MARK: - Appearance
    //
    // Hard-coded for the MVP. Kept in sync with CiderUI.Theme.backgroundColor
    // without importing CiderUI into the runtime layer: CiderRuntime sits below
    // the compatibility API in the package graph, so brand tokens have to cross
    // this boundary as plain CiderCore colors for now. A theme belongs with the
    // rest of the environment values in Stage 3.

    public var backgroundColor = Color(hex: 0x10100F)

    /// Points a single wheel notch scrolls. Chosen to feel like a few lines
    /// of body text per notch; there is no reference platform behaviour to
    /// match yet, the same reasoning as `backgroundColor` above.
    public var scrollNotchDistance = 40.0

    public init(
        descriptor: LaunchDescriptor,
        application: RuntimeApplication,
        backend: HostBackend,
        logSink: LogSink
    ) throws {
        self.descriptor = descriptor
        self.application = application
        self.backend = backend
        self.deviceProfile = try DeviceProfileRegistry.resolve(descriptor.deviceProfileName)
        self.logSink = logSink
        self.log = Logger(
            sink: logSink,
            channel: .runtime,
            minimumLevel: descriptor.logLevel
        )
    }

    // MARK: - Lifecycle

    /// Opens the window, initialises services, and tells the application it
    /// launched. Throws a `Diagnostic` if the host cannot provide what is needed.
    public func launch() throws {
        precondition(state == .notRunning, "launch() may only be called once")
        state = .launching

        log.info("launching \(descriptor.appID)")
        log.info("device: \(deviceProfile.name)")
        log.debug("host: \(backend.description.identifier) (\(backend.description.detail))")

        let engine = try backend.makeTextEngine(scale: deviceProfile.scale)
        self.textEngine = engine

        let pixels = deviceProfile.pixelSize
        let window = try backend.makeWindow(
            WindowConfiguration(
                title: descriptor.appName,
                pixelWidth: pixels.width,
                pixelHeight: pixels.height
            )
        )
        self.window = window
        log.info("renderer initialized")

        let context = RuntimeContext(
            deviceProfile: deviceProfile,
            permissions: descriptor.permissions,
            sandbox: descriptor.sandboxDataRoot.isEmpty ? nil : SandboxPaths(root: descriptor.sandboxDataRoot),
            appID: descriptor.appID,
            appName: descriptor.appName,
            requestCaptureProxyURL: descriptor.requestCaptureProxyURL,
            // Same sink, different channel: developer output interleaves with
            // Cider's in real order while staying visually distinguishable.
            log: log.scoped(to: .application),
            invalidationTarget: self
        )
        self.context = context

        application.didLaunch(context: context)
        state = .foreground
        log.info("application started")

        // Draw immediately: a window that appears blank until the first event
        // looks broken even when it is not.
        renderFrameIfNeeded()
    }

    /// The blocking loop an application binary runs.
    public func run() throws {
        if state == .notRunning {
            try launch()
        }
        while state == .foreground || state == .background {
            try pump()
            idle()
        }
    }

    /// Performs one iteration: drain events, rebuild if invalidated, redraw if
    /// stale. Returns `true` while the application is still running.
    @discardableResult
    public func pump() throws -> Bool {
        guard let window, state == .foreground || state == .background else {
            return false
        }

        for event in window.pollEvents() {
            handle(event)
            if state == .terminated { break }
        }

        guard state != .terminated else { return false }
        try renderFrame()
        return true
    }

    /// Runs the shutdown sequence. Safe to call more than once.
    public func terminate() {
        guard state != .terminated else { return }
        log.debug("terminating \(descriptor.appID)")
        application.willTerminate()
        window?.close()
        window = nil
        state = .terminated
        log.info("application terminated")
    }

    /// Simulates the application moving to the background.
    ///
    /// Stage 3 services need lifecycle transitions that tests and developer
    /// tooling can drive without a real operating-system app switcher. The
    /// runtime continues pumping in background so timers and service callbacks
    /// can still invalidate state under test.
    public func enterBackground() {
        guard state == .foreground else { return }
        state = .background
        application.didEnterBackground()
        log.info("application entered background")
    }

    /// Simulates the application returning to the foreground.
    public func enterForeground() {
        guard state == .background else { return }
        state = .foreground
        needsRender = true
        application.didEnterForeground()
        log.info("application entered foreground")
    }

    // MARK: - Events

    private func handle(_ event: HostEvent) {
        switch event {
        case .closeRequested:
            terminate()

        case .redrawRequested:
            needsRender = true

        case .resized:
            // The framebuffer is sized by the device profile, not the window, so
            // a resize changes only where it is letterboxed.
            needsRender = true

        case .pointerDown, .pointerMove, .pointerUp, .pointerExit:
            guard let touch = translator?.touch(for: event) else { return }
            handle(touch)

        case .scroll(let location, let deltaX, let deltaY):
            handleScroll(at: location, deltaX: deltaX, deltaY: deltaY)

        case .keyDown(let keyCode):
            handleKeyDown(keyCode)

        case .keyUp:
            // Typing only reacts to key-down; a held key's repeat already
            // arrives as repeated keyDown events from the host, and nothing
            // in the MVP (no modifier tracking, no key-repeat timing of its
            // own) needs to know when a key comes back up.
            break

        case .textInput(let text):
            insertText(text)
        }
    }

    private func insertText(_ text: String) {
        guard let focusedNode, let scene else { return }
        guard let handler = scene.textInputHandlers[focusedNode] else { return }
        guard case .textField(let field) = scene.root.find(focusedNode) else { return }
        log.trace("text input \(text.debugDescription) (focus: \(focusedNode))")
        handler(field.text + text)
    }

    /// X11 keysym for Backspace. Named here rather than imported from a
    /// header: this file has no C dependency, and one raw constant does not
    /// justify adding one. See docs/07-legal-distribution-boundaries.md if
    /// this list ever grows enough to need a real source.
    private static let backspaceKeyCode = 0xFF08

    /// Turns a raw key into a text edit, for whatever text field has focus.
    ///
    /// Scoped to what X11 keysyms make possible without an input method: the
    /// keysyms for printable ASCII are, by X11's own design, identical to
    /// their Unicode code points (true for the whole Latin-1 range, 0x20 to
    /// 0xFF), so basic typing works from `keyDown` alone. Composed text --
    /// dead keys, IME, anything outside Latin-1 -- needs `Xutf8LookupString`
    /// in the X11 shim, which does not exist yet (see HostEvent.textInput's
    /// doc comment); this only ever produces what a keysym in that range
    /// spells out directly. Editing is append/remove-from-the-end only: no
    /// cursor movement, no selection.
    private func handleKeyDown(_ keyCode: Int) {
        guard let focusedNode, let scene else { return }
        guard let handler = scene.textInputHandlers[focusedNode] else { return }
        guard case .textField(let field) = scene.root.find(focusedNode) else { return }

        let newText: String
        if keyCode == Self.backspaceKeyCode {
            guard !field.text.isEmpty else { return }
            newText = String(field.text.dropLast())
        } else if let scalar = Unicode.Scalar(keyCode), (0x20...0x7E).contains(keyCode) {
            newText = field.text + String(Character(scalar))
        } else {
            return
        }

        handler(newText)
    }

    private var translator: PointerTranslator? {
        guard let window else { return nil }
        let pixels = deviceProfile.pixelSize
        return PointerTranslator(
            scale: deviceProfile.scale,
            surfacePixelWidth: pixels.width,
            surfacePixelHeight: pixels.height,
            windowPixelWidth: window.pixelWidth,
            windowPixelHeight: window.pixelHeight
        )
    }

    /// The input pipeline's last stage: touch to hit test to action.
    private func handle(_ touch: Touch) {
        guard let renderTree else { return }

        switch touch.phase {
        case .began:
            let hit = renderTree.hitTest(touch.location)
            if hit != pressedNode {
                pressedNode = hit
                // Only a visual change, so redraw without rebuilding.
                needsRender = true
            }
            if let hit {
                log.trace("touch began on \(hit)")
            }

            // Focus follows the tap, the same as most direct-manipulation UI:
            // landing on a text field gives it focus, landing on anything
            // else -- another control, empty space -- takes focus away.
            // `scene` (not `pressedNode`/`hitTest`) is what says whether a
            // hit id is actually a text field, since nothing about a
            // `NodeID` says what kind of node it names.
            let newFocus = hit.flatMap { scene?.textInputHandlers[$0] != nil ? $0 : nil }
            if newFocus != focusedNode {
                focusedNode = newFocus
                needsRender = true
            }

        case .moved:
            // A press is abandoned when the finger leaves the control it started
            // on, and resumed if it comes back -- the behaviour a user expects
            // from a button they are having second thoughts about.
            guard pressedNode != nil else { return }
            let hit = renderTree.hitTest(touch.location)
            let stillInside = hit == pressedNode
            if !stillInside {
                pressedNode = nil
                needsRender = true
            }

        case .ended:
            guard let pressed = pressedNode else { return }
            pressedNode = nil
            needsRender = true

            // The action fires only if the release landed on the same control,
            // so dragging off cancels.
            guard renderTree.hitTest(touch.location) == pressed else {
                log.trace("touch ended outside \(pressed); no action")
                return
            }
            guard let action = scene?.actions[pressed] else { return }

            log.debug("invoking action for \(pressed)")
            action()

            // The action almost certainly changed state, but Cider does not
            // assume so: `invalidate()` from the state wrapper is what marks the
            // tree stale. An action that changes nothing costs one redraw for
            // the released appearance and no rebuild.

        case .cancelled:
            guard pressedNode != nil else { return }
            pressedNode = nil
            needsRender = true
        }
    }

    /// Routes a wheel notch to whichever scroll view is under it, and clamps
    /// the result so content can't be scrolled past its own edges.
    ///
    /// Clamping needs both the viewport's size and its content's natural
    /// size. Both are sitting in `lastLayout` already -- the scroll view's
    /// own placed frame is the viewport, and its one child's placed frame
    /// (computed at the content's unbounded intrinsic size; see
    /// `LayoutEngine.place`'s `.scrollView` case) is the content -- so this
    /// reads the existing layout tree rather than asking for a fresh one.
    private func handleScroll(at location: Point, deltaX: Double, deltaY: Double) {
        guard let renderTree, let lastLayout, let translator else { return }

        let point = translator.convert(location)
        guard let target = renderTree.scrollTarget(at: point) else { return }
        guard let viewportBox = lastLayout.box(for: target), let contentBox = viewportBox.children.first else {
            return
        }

        let maxOffsetX = max(0, contentBox.frame.width - viewportBox.frame.width)
        let maxOffsetY = max(0, contentBox.frame.height - viewportBox.frame.height)

        let current = scrollOffsets[target] ?? .zero
        let proposed = Point(
            x: current.x + deltaX * scrollNotchDistance,
            y: current.y + deltaY * scrollNotchDistance
        )
        let clamped = Point(
            x: min(max(0, proposed.x), maxOffsetX),
            y: min(max(0, proposed.y), maxOffsetY)
        )

        guard clamped != current else { return }
        scrollOffsets[target] = clamped
        needsRender = true
    }

    // MARK: - Invalidation and rendering

    func setNeedsRebuild() {
        needsRebuild = true
        needsRender = true
    }

    private func renderFrameIfNeeded() {
        try? renderFrame()
    }

    private func renderFrame() throws {
        guard let window, let textEngine else { return }
        guard needsRebuild || needsRender else { return }

        let context = LayoutContext(textEngine: textEngine)

        if needsRebuild || scene == nil {
            let scene = application.makeScene()
            self.scene = scene

            let layout = LayoutEngine.layoutCentered(
                scene.root,
                in: deviceProfile.safeAreaBounds,
                context: context
            )
            self.lastLayout = layout

            // A pressed control that disappeared in the rebuild must not stay
            // pressed, or the next release would fire an action on a node that
            // is no longer on screen.
            if let pressed = pressedNode, layout.box(for: pressed) == nil {
                pressedNode = nil
            }

            // Same reasoning for focus: a focused node that vanished in the
            // rebuild must not keep absorbing keyboard events nothing on
            // screen can show the result of.
            if let focused = focusedNode, layout.box(for: focused) == nil {
                focusedNode = nil
            }

            // And for scroll position: a scroll view that vanished must not
            // leave a stale offset sitting around forever, and if a scroll
            // view with the same identity reappears (same structural path),
            // this correctly does nothing -- box(for:) finds it and the old
            // offset is exactly what a developer would expect to survive an
            // unrelated state change.
            scrollOffsets = scrollOffsets.filter { id, _ in layout.box(for: id) != nil }

            needsRebuild = false

            if descriptor.inspectorEnabled {
                log.debug("ui tree:\n" + Inspector.describe(node: scene.root, layout: layout))
            }
        }

        guard let scene, let layout = lastLayout else { return }

        let tree = RenderTreeBuilder.build(
            node: scene.root,
            layout: layout,
            backgroundColor: backgroundColor,
            pressedNode: pressedNode,
            focusedNode: focusedNode,
            scrollOffsets: scrollOffsets,
            context: context
        )
        self.renderTree = tree

        let pixels = deviceProfile.pixelSize
        let canvas = Rasterizer.render(
            tree,
            pixelWidth: pixels.width,
            pixelHeight: pixels.height,
            scale: deviceProfile.scale,
            textEngine: textEngine
        )

        try window.present(canvas)
        frameCount += 1
        writeInspectorSnapshotIfNeeded(node: scene.root, layout: layout, renderTree: tree)
        writeFrameMirrorIfNeeded(canvas)
        needsRender = false
        log.trace("presented frame \(frameCount)")
    }

    private func writeInspectorSnapshotIfNeeded(node: UINode, layout: LayoutBox, renderTree: RenderTree) {
        guard descriptor.inspectorEnabled, !descriptor.inspectorSnapshotPath.isEmpty else { return }
        do {
            let snapshot = Inspector.snapshot(
                node: node,
                layout: layout,
                renderTree: renderTree,
                frameCount: frameCount,
                origins: scene?.origins ?? [:]
            )
            let text = try Inspector.json(snapshot)
            let url = URL(fileURLWithPath: descriptor.inspectorSnapshotPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            log.warning("could not write inspector snapshot: \(error)")
        }
    }

    /// Mirrors the presented frame for the `cider dev` editor.
    ///
    /// Throttled rather than written every frame. A presented frame is about a
    /// megabyte, and an application driving a timer can present at the loop's
    /// full rate; at that point the mirror would cost more disk bandwidth than
    /// the application costs CPU. Five frames a second is well past what a
    /// developer reading a property panel can perceive.
    private func writeFrameMirrorIfNeeded(_ canvas: Canvas) {
        guard !descriptor.inspectorFramePath.isEmpty else { return }

        let now = Date().timeIntervalSince1970
        if let last = lastFrameMirrorTime, now - last < Self.frameMirrorMinimumInterval { return }
        lastFrameMirrorTime = now

        do {
            let url = URL(fileURLWithPath: descriptor.inspectorFramePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Atomically, so the console never reads a half-written frame.
            let bytes = FrameMirror.encode(
                canvas,
                logicalWidth: Int(deviceProfile.logicalWidth.rounded()),
                logicalHeight: Int(deviceProfile.logicalHeight.rounded())
            )
            try Data(bytes).write(to: url, options: .atomic)
        } catch {
            log.warning("could not write frame mirror: \(error)")
        }
    }

    // MARK: - Introspection, for tests and the inspector

    /// The render tree behind the most recently presented frame.
    public var currentRenderTree: RenderTree? { renderTree }

    /// The layout behind the most recently presented frame.
    public var currentLayout: LayoutBox? { lastLayout }

    /// The node currently held down, if any.
    public var currentPressedNode: NodeID? { pressedNode }

    /// The node with keyboard focus, if any -- the text field last tapped,
    /// unless focus has since moved or been cleared.
    public var currentFocusedNode: NodeID? { focusedNode }

    /// The current scroll position of the scroll view identified by `id`,
    /// or `.zero` if it has never been scrolled (or isn't a scroll view).
    public func currentScrollOffset(for id: NodeID) -> Point {
        scrollOffsets[id] ?? .zero
    }

    // MARK: - Plumbing

    private func idle() {
        // Nothing happened, so give the CPU back. 8ms is roughly a frame at
        // 120Hz: fast enough that input feels immediate, slow enough that an
        // idle application is not a busy loop. Real frame pacing arrives with
        // animation in a later stage.
        Sleep.milliseconds(8)
    }
}
