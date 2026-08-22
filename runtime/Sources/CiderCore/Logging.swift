//  Logging.
//
//  Two requirements shape this design. First, docs/02-product-requirements.md
//  asks that developer application logs stay distinguishable from Cider's own
//  output -- so every record carries a `LogChannel`, and the default formatter
//  gives each channel its own prefix. Second, nothing here may reach for a
//  global: a test that captures logs must be able to do so without disturbing
//  another test running beside it, so a `Logger` always writes to a sink it was
//  handed.

public enum LogLevel: Int, Comparable, Sendable, CaseIterable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var name: String {
        switch self {
        case .trace: return "trace"
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        }
    }

    /// Parses a level name, for `CIDER_LOG_LEVEL` and `--log-level`.
    public init?(name: String) {
        switch name.lowercased() {
        case "trace": self = .trace
        case "debug": self = .debug
        case "info": self = .info
        case "warn", "warning": self = .warning
        case "error": self = .error
        default: return nil
        }
    }
}

/// Who emitted a record. The distinction matters to a developer scanning
/// output: `runtime` lines are Cider's, `application` lines are theirs.
public enum LogChannel: String, Sendable {
    case runtime
    case application

    public var prefix: String {
        switch self {
        case .runtime: return "[cider]"
        case .application: return "[app]"
        }
    }
}

public struct LogRecord: Sendable {
    public var level: LogLevel
    public var channel: LogChannel
    public var message: String

    public init(level: LogLevel, channel: LogChannel, message: String) {
        self.level = level
        self.channel = channel
        self.message = message
    }

    /// The one-line form used on a terminal.
    ///
    /// `info` on the runtime channel prints bare -- `[cider] application
    /// started` -- because that is the common case and a level tag on every
    /// line makes normal output harder to read, not easier.
    public func formatted() -> String {
        if level == .info {
            return "\(channel.prefix) \(message)"
        }
        return "\(channel.prefix) \(level.name): \(message)"
    }
}

/// Somewhere records go. Implementations must tolerate being called from the
/// runtime's thread only; Cider does not log from background threads.
public protocol LogSink: AnyObject {
    func write(_ record: LogRecord)
}

/// Collects records in memory. Used by tests and by the inspector.
public final class MemoryLogSink: LogSink {
    public private(set) var records: [LogRecord] = []

    public init() {}

    public func write(_ record: LogRecord) {
        records.append(record)
    }

    public func messages(channel: LogChannel? = nil) -> [String] {
        records
            .filter { channel == nil || $0.channel == channel }
            .map(\.message)
    }
}

/// Emits records at or above `minimumLevel` to a sink.
public struct Logger {
    public var minimumLevel: LogLevel
    public var channel: LogChannel
    private let sink: LogSink

    public init(sink: LogSink, channel: LogChannel = .runtime, minimumLevel: LogLevel = .info) {
        self.sink = sink
        self.channel = channel
        self.minimumLevel = minimumLevel
    }

    /// Returns a logger writing to the same sink on a different channel, so the
    /// runtime can hand an application its own logger without exposing the sink.
    public func scoped(to channel: LogChannel) -> Logger {
        Logger(sink: sink, channel: channel, minimumLevel: minimumLevel)
    }

    public func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        guard level >= minimumLevel else { return }
        sink.write(LogRecord(level: level, channel: channel, message: message()))
    }

    public func trace(_ message: @autoclosure () -> String) { log(.trace, message()) }
    public func debug(_ message: @autoclosure () -> String) { log(.debug, message()) }
    public func info(_ message: @autoclosure () -> String) { log(.info, message()) }
    public func warning(_ message: @autoclosure () -> String) { log(.warning, message()) }
    public func error(_ message: @autoclosure () -> String) { log(.error, message()) }
}
