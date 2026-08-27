//  Structured event log for `cider dev`.

import Foundation

public struct DevEvent: Codable, Equatable, Sendable {
    public var timeMilliseconds: Int64
    public var kind: String
    public var message: String

    public init(kind: String, message: String, timeMilliseconds: Int64 = DevClock.nowMilliseconds()) {
        self.kind = kind
        self.message = message
        self.timeMilliseconds = timeMilliseconds
    }
}

public enum DevClock {
    public static func nowMilliseconds() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}

public final class DevEventLog {
    private var events: [DevEvent] = []
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func append(kind: String, message: String) {
        append(DevEvent(kind: kind, message: message))
    }

    public func append(_ event: DevEvent) {
        events.append(event)
        if events.count > 200 { events.removeFirst(events.count - 200) }
        if let data = try? JSONEncoder().encode(event), let line = String(data: data, encoding: .utf8) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path), let handle = try? FileHandle(forWritingTo: url) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: Data((line + "\n").utf8))
                try? handle.close()
            } else {
                try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    public func recent() -> [DevEvent] { events }
}
