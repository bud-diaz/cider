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

    /// Frames presented since launch. Exposed for tests and the inspector.
    public private(set) var frameCount = 0

    // MARK: - Appearance
    //
    // Hard-coded for the MVP. A theme belongs with the rest of the environment
    // values in Stage 3; inventing one now would mean designing it against a
    // single screen.

    public var backgroundColor = Color(hex: 0xF2F2F7)

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
        }
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
        needsRender = false
        log.trace("presented frame \(frameCount)")
    }

    // MARK: - Introspection, for tests and the inspector

    /// The render tree behind the most recently presented frame.
    public var currentRenderTree: RenderTree? { renderTree }

    /// The layout behind the most recently presented frame.
    public var currentLayout: LayoutBox? { lastLayout }

    /// The node currently held down, if any.
    public var currentPressedNode: NodeID? { pressedNode }

    // MARK: - Plumbing

    private func idle() {
        // Nothing happened, so give the CPU back. 8ms is roughly a frame at
        // 120Hz: fast enough that input feels immediate, slow enough that an
        // idle application is not a busy loop. Real frame pacing arrives with
        // animation in a later stage.
        Sleep.milliseconds(8)
    }
}
