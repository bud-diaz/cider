//  Keeping obvious secrets out of logs.
//
//  docs/03-technical-architecture.md section 8 asks for "sanitized logs".
//  Nothing in Cider handles credentials yet -- HTTP and preferences are Stage
//  3 -- so this is deliberately conservative: it recognises `key = value` /
//  `key: value` pairs whose key names a credential, and a token following the
//  `Bearer` scheme, and redacts only the value half, whether the value sits in
//  the same word or the next one. A record it does not recognise as sensitive
//  is left untouched; a logging policy that mangles ordinary output is one
//  developers turn off.

public enum LogRedaction {
    private static let sensitiveKeywords: [String] = [
        "password", "passwd", "secret", "token", "apikey", "api_key", "authorization",
    ]

    /// Returns `message` with the value half of any recognised credential-shaped
    /// pair replaced by `[redacted]`.
    public static func redact(_ message: String) -> String {
        let words = message.split(separator: " ", omittingEmptySubsequences: false)
        var result: [String] = []
        var index = 0

        while index < words.count {
            let word = words[index]

            if word.lowercased() == "bearer", index + 1 < words.count {
                result.append(String(word))
                result.append("[redacted]")
                index += 2
                continue
            }

            if let separator = word.firstIndex(where: { $0 == "=" || $0 == ":" }) {
                let key = word[word.startIndex..<separator].lowercased()
                if sensitiveKeywords.contains(where: key.contains) {
                    let hasInlineValue = word.index(after: separator) < word.endIndex
                    if hasInlineValue {
                        result.append(String(word[word.startIndex...separator]) + "[redacted]")
                        index += 1
                        continue
                    } else if index + 1 < words.count {
                        // "key:" with the value as a separate word, e.g. "token: abc123".
                        result.append(String(word))
                        result.append("[redacted]")
                        index += 2
                        continue
                    }
                }
            }

            result.append(String(word))
            index += 1
        }

        return result.joined(separator: " ")
    }
}

/// Wraps another sink and redacts every record's message before forwarding
/// it. Used on the sink an application binary logs through; test sinks stay
/// unwrapped so assertions can match the exact message a call site wrote.
public final class RedactingLogSink: LogSink {
    private let wrapped: LogSink

    public init(wrapping sink: LogSink) {
        self.wrapped = sink
    }

    public func write(_ record: LogRecord) {
        var redacted = record
        redacted.message = LogRedaction.redact(record.message)
        wrapped.write(redacted)
    }
}
