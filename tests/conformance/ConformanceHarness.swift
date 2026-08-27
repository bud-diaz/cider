//  Shared machinery for the conformance suite.
//
//  Every conformance test drives a real `ApplicationRuntime` over the headless
//  backend. Testing the layers separately would be easier and would prove less:
//  the whole point of the suite is that the seams line up, and a bug where the
//  compatibility layer and the runtime disagree about node identity only shows
//  up when both are running.

import XCTest

import CiderCore
import CiderHost
import CiderHostTesting
import CiderRuntime
import CiderUITree

@testable import CiderUI

/// A runtime, its backend and its log, wired together for a test.
final class ConformanceHarness {
    let backend: TestingHostBackend
    let runtime: ApplicationRuntime
    let logSink = MemoryLogSink()

    init<App: CiderApp>(
        _ app: App,
        device: String = "phone-standard",
        permissions: AppPermissions = .none,
        sandboxDataRoot: String = "",
        logLevel: LogLevel = .trace
    ) throws {
        self.backend = TestingHostBackend()
        self.runtime = try ApplicationRuntime(
            descriptor: LaunchDescriptor(
                appID: "dev.cider.conformance",
                appName: "Conformance",
                appEntry: "\(App.self)",
                minimumCompatibility: "0.1",
                deviceProfileName: device,
                permissions: permissions,
                logLevel: logLevel,
                sandboxDataRoot: sandboxDataRoot
            ),
            application: CiderAppAdapter(app: app),
            backend: backend,
            logSink: logSink
        )
    }

    func launch() throws {
        try runtime.launch()
    }

    /// Delivers events and lets the runtime process them.
    func deliver(_ events: [HostEvent]) throws {
        backend.send(events)
        try runtime.pump()
    }

    /// A complete tap: press and release at the same point.
    func tap(at point: Point) throws {
        try deliver([
            .pointerDown(location: point, button: .primary),
            .pointerUp(location: point, button: .primary),
        ])
    }

    /// The centre of a node's hit region, in device pixels.
    ///
    /// The testing window is sized from the device profile at scale 1, so window
    /// pixels and logical points coincide. Any test that needs them to differ
    /// says so explicitly.
    func center(of id: NodeID) throws -> Point {
        let tree = try XCTUnwrap(runtime.currentRenderTree, "no frame has been rendered")
        let region = try XCTUnwrap(
            tree.hitRegions.first { $0.id == id },
            "no hit region for \(id); regions: \(tree.hitRegions.map(\.id.path))"
        )
        return Point(x: region.frame.midX, y: region.frame.midY)
    }

    /// The single button in the current frame.
    func onlyButton() throws -> HitRegion {
        let tree = try XCTUnwrap(runtime.currentRenderTree)
        XCTAssertEqual(tree.hitRegions.count, 1, "this helper expects exactly one button")
        return try XCTUnwrap(tree.hitRegions.first)
    }

    /// Every string the current frame draws, in painter's order.
    func drawnStrings() -> [String] {
        guard let tree = runtime.currentRenderTree else { return [] }
        return tree.commands.compactMap { command in
            if case .text(let content, _, _, _) = command { return content }
            return nil
        }
    }
}

// MARK: - Applications used by the suite

/// The reference application: a title, a button and a counter.
struct CounterApp: CiderApp {
    @CiderState var count = 0

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Cider Demo")
                .font(size: 28, weight: .bold)

            Button("Press Me") {
                count += 1
            }

            Text("Count: \(count)")
        }
    }
}

/// A single line of text, for the text conformance test.
struct TextOnlyApp: CiderApp {
    var body: some CiderView {
        Text("Hello")
    }
}

/// A single image, for the image conformance test.
struct ImageOnlyApp: CiderApp {
    var body: some CiderView {
        Image(.solid(Color(hex: 0xFF00FF), width: 12, height: 8))
    }
}

/// A single text field, for the text-field conformance test.
struct TextFieldTestApp: CiderApp {
    @CiderState var text = ""

    var body: some CiderView {
        TextField($text, width: 100)
    }
}

/// Ten button rows plus a trailing status row, in a viewport short enough
/// that most rows start out scrolled out of view -- for the list
/// conformance test.
struct ListTestApp: CiderApp {
    @CiderState var lastTapped = -1

    var body: some CiderView {
        List(width: 100, height: 30) {
            for index in 0..<10 {
                Button("Row \(index)") { lastTapped = index }.font(size: 10)
            }
            Text("Last: \(lastTapped)").font(size: 10)
        }
    }
}

/// A screen pushed onto the navigation stack, with a way back -- for the
/// navigation conformance tests. Holds the same `CiderState` binding the
/// root screen does, the same reasoning `TextField` binds one -- there's no
/// other channel for a pushed screen to reach the path that put it there.
struct NavigationDetailScreen: CiderView {
    let path: CiderState<[any CiderView]>

    var body: some CiderView {
        VStack {
            Text("Detail")
            Button("Back") { path.wrappedValue.removeLast() }
        }
    }
}

/// A root screen that pushes one screen, and the screen it pushes -- for
/// the navigation conformance test.
struct NavigationTestApp: CiderApp {
    @CiderState var path: [any CiderView] = []

    var body: some CiderView {
        NavigationView($path) {
            VStack {
                Text("Root")
                Button("Go") { path.append(NavigationDetailScreen(path: $path)) }
            }
        }
    }
}

/// The content shown modally -- for the modal conformance test.
struct ModalDetailScreen: CiderView {
    let isPresented: CiderState<Bool>

    var body: some CiderView {
        VStack {
            Text("Presented")
            Button("Dismiss") { isPresented.wrappedValue = false }
        }
    }
}

/// A base screen with a button that presents a modal over it -- for the
/// modal conformance test.
struct ModalTestApp: CiderApp {
    @CiderState var isPresented = false

    var body: some CiderView {
        Modal($isPresented) {
            VStack {
                Text("Base")
                Button("Present") { isPresented = true }
            }
        } presenting: {
            ModalDetailScreen(isPresented: $isPresented)
        }
    }
}

/// A short viewport over content taller than it, with a button positioned so
/// it starts out entirely scrolled out of view -- for the scroll conformance
/// test, including whether hit-testing respects the clip.
struct ScrollTestApp: CiderApp {
    @CiderState var count = 0

    var body: some CiderView {
        ScrollView(width: 100, height: 20) {
            VStack(spacing: 0) {
                Text("Row 0").font(size: 10)
                Text("Row 1").font(size: 10)
                Button("Tap") { count += 1 }.font(size: 10)
                Text("Count: \(count)").font(size: 10)
            }
        }
    }
}
