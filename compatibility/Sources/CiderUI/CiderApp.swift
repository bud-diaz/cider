//  The application entry point.
//
//  `@_exported` re-exports CiderCore's types (`Color`, `FontRequest`,
//  `ImageSource`, ...) so an application that only depends on the `CiderUI`
//  product -- as every example under `examples/` does -- can still name them
//  (`Image(.solid(Color(hex: ...), ...))`, `.foregroundColor(...)`) without
//  a separate dependency on a module Cider never published as its own
//  library product. `CiderUITree` stays unexported: nothing in the
//  application-facing API (`Text`, `Image`, `Button`, ...) hands an
//  application `UINode` or a sibling type to name.
@_exported import CiderCore
import CiderHostBootstrap
import CiderRuntime
import CiderUITree

#if canImport(Glibc)
import Glibc
#endif

/// The protocol an application conforms to.
///
///     import CiderUI
///
///     @main
///     struct DemoApp: CiderApp {
///         @CiderState private var count = 0
///
///         var body: some CiderView {
///             VStack {
///                 Text("Cider Demo")
///                 Button("Press Me") { count += 1 }
///                 Text("Count: \(count)")
///             }
///         }
///     }
///
/// Marking the type `@main` is what makes it the executable's entry point;
/// `main()` below is the implementation Swift calls.
public protocol CiderApp {
    associatedtype Body: CiderView

    init()

    @CiderViewBuilder
    var body: Body { get }

    /// Called when the runtime simulates the app moving to the background
    /// (`ApplicationRuntime.enterBackground()`). Optional — override to react
    /// to the transition; the default does nothing.
    func didEnterBackground()

    /// Called when the runtime simulates the app returning to the foreground
    /// (`ApplicationRuntime.enterForeground()`). Optional — override to react
    /// to the transition; the default does nothing.
    func didEnterForeground()
}

public extension CiderApp {
    func didEnterBackground() {}
    func didEnterForeground() {}
}

public extension CiderApp {
    /// Starts the runtime and blocks until the window closes.
    ///
    /// Every failure between here and the first frame is a `Diagnostic`, so a
    /// developer gets the four-part message described in
    /// docs/02-product-requirements.md FR-007 rather than an exit code.
    static func main() {
        let sink = RedactingLogSink(wrapping: StandardOutputLogSink())

        do {
            let descriptor = try LaunchEnvironment.resolveDescriptor()
            let backend = try HostBootstrap.makeDefaultBackend()
            let application = CiderAppAdapter(app: Self())

            let runtime = try ApplicationRuntime(
                descriptor: descriptor,
                application: application,
                backend: backend,
                logSink: sink
            )
            try runtime.run()
            runtime.terminate()
        } catch let diagnostic as Diagnostic {
            StandardStreams.error("")
            StandardStreams.error(diagnostic.formatted())
            StandardStreams.error("")
            exit(1)
        } catch {
            StandardStreams.error("error: \(error)")
            exit(1)
        }
    }
}

/// Bridges a `CiderApp` value to the runtime's `RuntimeApplication` protocol.
///
/// The adapter is the only part of the compatibility layer the runtime sees, and
/// the only place that knows an application is a Swift struct with property
/// wrappers in it.
final class CiderAppAdapter<App: CiderApp>: RuntimeApplication {
    private let app: App
    private var context: RuntimeContext?

    init(app: App) {
        self.app = app
    }

    func didLaunch(context: RuntimeContext) {
        self.context = context
        CiderServiceContext.attach(context)
        attachState(of: app, invalidate: { [weak context] in context?.invalidate() })
    }

    func makeScene() -> ApplicationScene {
        Lowering.scene(from: app.body)
    }

    func willTerminate() {
        CiderServiceContext.detach()
    }

    func didEnterBackground() {
        app.didEnterBackground()
    }

    func didEnterForeground() {
        app.didEnterForeground()
    }

    /// Finds every `@CiderState` on the application and wires it to invalidation.
    ///
    /// Reflection is used because there is no way for a property wrapper to
    /// discover the runtime on its own, and requiring an application author to
    /// register each property by hand would be a step they can forget -- which
    /// would show up as a UI that silently stops updating.
    ///
    /// Only the application's own stored properties are visited. Nested views
    /// hold no state in the MVP; when they do, this walk grows to match, which
    /// is a change confined to this function.
    private func attachState(of value: Any, invalidate: @escaping () -> Void) {
        for child in Mirror(reflecting: value).children {
            if let storage = child.value as? any CiderStateStorage {
                storage.attach(invalidate: invalidate)
            }
        }
    }
}

/// Reads the launch descriptor the CLI wrote.
enum LaunchEnvironment {
    /// Command-line flag `cider run` passes to the application binary.
    static let descriptorFlag = "--cider-launch"

    /// Environment variable honoured as an alternative, for debuggers and IDEs
    /// that make it awkward to add arguments.
    static let descriptorVariable = "CIDER_LAUNCH_DESCRIPTOR"

    /// Returns the descriptor for this launch.
    ///
    /// Running the binary directly -- without going through `cider run` -- is
    /// supported and yields defaults. That keeps a debugger session or a
    /// `swift run` from being a different code path than the supported one.
    static func resolveDescriptor() throws -> LaunchDescriptor {
        guard let path = descriptorPath() else {
            return defaultDescriptor()
        }
        guard let text = readFile(path) else {
            throw Diagnostic(
                code: "CID0304",
                summary: "could not read the launch descriptor",
                location: DiagnosticLocation(file: path),
                reason: "The runtime was told to read \(path), but the file could not be opened.",
                remedy: "Re-run `cider run` from the project directory."
            )
        }
        return try LaunchDescriptor.decode(text)
    }

    private static func descriptorPath() -> String? {
        var arguments = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = arguments.next() {
            if argument == descriptorFlag {
                return arguments.next()
            }
            if argument.hasPrefix("\(descriptorFlag)=") {
                return String(argument.dropFirst(descriptorFlag.count + 1))
            }
        }
        if let value = getenv(descriptorVariable) {
            let path = String(cString: value)
            return path.isEmpty ? nil : path
        }
        return nil
    }

    private static func defaultDescriptor() -> LaunchDescriptor {
        LaunchDescriptor(
            appID: "dev.cider.unconfigured",
            appName: "Cider Application",
            appEntry: "unknown",
            minimumCompatibility: "0.1",
            deviceProfileName: "phone-standard",
            permissions: .none,
            logLevel: LogLevel(name: getenv("CIDER_LOG_LEVEL").map { String(cString: $0) } ?? "") ?? .info,
            inspectorEnabled: getenv("CIDER_INSPECT") != nil
        )
    }

    private static func readFile(_ path: String) -> String? {
        guard let file = fopen(path, "rb") else { return nil }
        defer { fclose(file) }

        var bytes: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let read = chunk.withUnsafeMutableBytes { buffer in
                fread(buffer.baseAddress, 1, buffer.count, file)
            }
            if read <= 0 { break }
            bytes.append(contentsOf: chunk[0..<read])
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
