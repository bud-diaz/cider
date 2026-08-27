//  Request capture records for the local Stage 4 developer console.

public struct CapturedHTTPRequest: Codable, Equatable, Sendable {
    public var id: String
    public var startedAtMilliseconds: Int64
    public var method: String
    public var url: String
    public var requestHeaders: [String: String]
    public var statusCode: Int?
    public var responseHeaders: [String: String]
    public var responseBodyPreview: String
    public var error: String?
    public var durationMilliseconds: Int?

    public init(
        id: String,
        startedAtMilliseconds: Int64,
        method: String,
        url: String,
        requestHeaders: [String: String] = [:],
        statusCode: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBodyPreview: String = "",
        error: String? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.id = id
        self.startedAtMilliseconds = startedAtMilliseconds
        self.method = method
        self.url = url
        self.requestHeaders = RequestHeaderRedaction.redact(requestHeaders)
        self.statusCode = statusCode
        self.responseHeaders = RequestHeaderRedaction.redact(responseHeaders)
        self.responseBodyPreview = responseBodyPreview
        self.error = error
        self.durationMilliseconds = durationMilliseconds
    }
}

public enum RequestHeaderRedaction {
    public static func redact(_ headers: [String: String]) -> [String: String] {
        var redacted: [String: String] = [:]
        for (key, value) in headers {
            redacted[key] = isSensitive(key) ? "[redacted]" : value
        }
        return redacted
    }

    public static func isSensitive(_ key: String) -> Bool {
        let lower = key.lowercased()
        if lower == "authorization" || lower == "cookie" || lower == "set-cookie" || lower == "x-api-key" {
            return true
        }
        return lower.contains("token") || lower.contains("secret") || lower.contains("key")
    }
}
