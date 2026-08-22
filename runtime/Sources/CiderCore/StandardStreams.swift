//  Writing to the process's own output streams.
//
//  These go through raw file descriptors rather than `stdout`/`stderr`. The C
//  stream globals are mutable shared state that Swift 6 will not let a
//  concurrency-checked program touch, and descriptors 1 and 2 are constants, so
//  the direct route is both simpler and legal.

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

public enum StandardStreams {
    private static let standardOutput: Int32 = 1
    private static let standardError: Int32 = 2

    /// Cider's runtime log goes to standard output: it is the normal output of
    /// `cider run`, not an error stream, and a developer piping it into `grep`
    /// should not have to redirect first.
    public static func out(_ text: String) {
        writeLine(text, to: standardOutput)
    }

    /// Diagnostics go to standard error, so `cider build > log` still shows the
    /// developer what went wrong.
    public static func error(_ text: String) {
        writeLine(text, to: standardError)
    }

    public static func writeLine(_ text: String, to descriptor: Int32) {
        write(text + "\n", to: descriptor)
    }

    public static func write(_ text: String, to descriptor: Int32) {
        let bytes = Array(text.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            guard var pointer = buffer.baseAddress else { return }
            var remaining = buffer.count
            // A short write is legal, and a signal can interrupt one. Loop
            // rather than lose the tail of a diagnostic.
            while remaining > 0 {
                #if canImport(Glibc)
                let written = Glibc.write(descriptor, pointer, remaining)
                #else
                let written = Darwin.write(descriptor, pointer, remaining)
                #endif
                if written < 0 {
                    if errno == EINTR { continue }
                    return
                }
                pointer += written
                remaining -= written
            }
        }
    }
}

/// Emits records to standard output.
public final class StandardOutputLogSink: LogSink {
    public init() {}

    public func write(_ record: LogRecord) {
        StandardStreams.out(record.formatted())
    }
}
