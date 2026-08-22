//  A headless backend for tests and CI.
//
//  This exists for two reasons.
//
//  The first is practical: conformance and visual tests must run on a machine
//  with no display and produce byte-identical output every time. A test that
//  needs an X server, a window manager and the host's font collection is not a
//  test of Cider, it is a test of the machine.
//
//  The second is architectural. A single backend cannot prove an abstraction.
//  Having two from the first commit means shared code is compiled against more
//  than one implementation continuously -- so a Linux assumption that leaks
//  upward breaks the build here rather than surfacing when the Windows backend
//  is written.

import CiderCore
import CiderHost

public final class TestingHostBackend: HostBackend {
    /// Frames the runtime presented, oldest first. Tests assert on these.
    public private(set) var presentedFrames: [Canvas] = []

    private let window: TestingWindow

    public init(pixelWidth: Int = 0, pixelHeight: Int = 0) {
        self.window = TestingWindow(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        self.window.onPresent = { [weak self] canvas in
            self?.presentedFrames.append(canvas)
        }
    }

    public var description: HostDescription {
        HostDescription(identifier: "testing", detail: "headless")
    }

    public func makeWindow(_ configuration: WindowConfiguration) throws -> HostWindow {
        window.adopt(configuration)
        return window
    }

    public func makeTextEngine(scale: Double) throws -> TextEngine {
        DeterministicTextEngine(scale: scale)
    }

    /// Queues events the runtime will see on its next poll.
    public func send(_ events: [HostEvent]) {
        window.enqueue(events)
    }

    public func send(_ event: HostEvent) {
        window.enqueue([event])
    }

    /// The most recently presented frame, if any.
    public var lastFrame: Canvas? { presentedFrames.last }

    public func clearFrames() {
        presentedFrames.removeAll()
    }
}

final class TestingWindow: HostWindow {
    private(set) var pixelWidth: Int
    private(set) var pixelHeight: Int

    var onPresent: ((Canvas) -> Void)?
    private var pending: [HostEvent] = []
    private(set) var isClosed = false

    init(pixelWidth: Int, pixelHeight: Int) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    func adopt(_ configuration: WindowConfiguration) {
        // A caller may pin a surface size to test letterboxing; otherwise the
        // window is exactly what the runtime asked for.
        if pixelWidth == 0 { pixelWidth = configuration.pixelWidth }
        if pixelHeight == 0 { pixelHeight = configuration.pixelHeight }
    }

    func enqueue(_ events: [HostEvent]) {
        pending.append(contentsOf: events)
    }

    func present(_ canvas: Canvas) throws {
        onPresent?(canvas)
    }

    func pollEvents() -> [HostEvent] {
        defer { pending.removeAll() }
        return pending
    }

    func close() {
        isClosed = true
    }
}
