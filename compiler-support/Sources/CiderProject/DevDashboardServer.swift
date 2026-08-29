//  Local dashboard routing for Stage 4 developer tools.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CiderCore

public struct DevDashboardStatus: Codable, Equatable, Sendable {
    public var project: String
    public var state: String
    public var dashboardURL: String
}

public struct DevDashboardResponse: Sendable {
    public var status: Int
    public var contentType: String
    public var body: Data

    /// Extra response headers, for the CORS preflight a token-gated route needs.
    public var headers: [String: String]

    public init(
        status: Int = 200,
        contentType: String = "application/json",
        body: Data = Data(),
        headers: [String: String] = [:]
    ) {
        self.status = status
        self.contentType = contentType
        self.body = body
        self.headers = headers
    }

    public static func text(_ text: String, contentType: String = "text/plain; charset=utf-8") -> DevDashboardResponse {
        DevDashboardResponse(contentType: contentType, body: Data(text.utf8))
    }

    public static func json<T: Encodable>(_ value: T) -> DevDashboardResponse {
        DevDashboardResponse(contentType: "application/json", body: (try? JSONEncoder().encode(value)) ?? Data())
    }

    /// A refusal the dashboard can render: the four parts of a `Diagnostic`,
    /// as JSON. `Diagnostic` itself stays non-`Codable` -- making a `CiderCore`
    /// type serialisable for one consumer's convenience is a public API change
    /// this does not need.
    public static func refusal(_ diagnostic: Diagnostic, status: Int) -> DevDashboardResponse {
        DevDashboardResponse(
            status: status,
            contentType: "application/json",
            body: (try? JSONEncoder().encode(DevDiagnosticPayload(diagnostic))) ?? Data()
        )
    }
}

/// A `Diagnostic` flattened for the wire.
public struct DevDiagnosticPayload: Codable, Equatable, Sendable {
    public var code: String
    public var summary: String
    public var location: String?
    public var reason: String?
    public var remedy: String?

    public init(_ diagnostic: Diagnostic) {
        code = diagnostic.code
        summary = diagnostic.summary
        location = diagnostic.location?.description
        reason = diagnostic.reason
        remedy = diagnostic.remedy
    }
}

/// The per-run secret the dashboard sends with every mutating request.
///
/// Loopback is not a security boundary: any web page the developer visits can
/// POST to `127.0.0.1` and the browser will deliver it, even though CORS stops
/// the page reading the reply. That was already true of the sandbox reset; it
/// becomes far worse once a route can write a Swift file that `cider dev` then
/// rebuilds and runs. A custom header also forces a CORS preflight, which a
/// cross-origin simple request cannot send.
public struct DevSessionToken: Codable, Equatable, Sendable {
    public static let headerName = "x-cider-dev-token"

    public var token: String

    public init(token: String) {
        self.token = token
    }

    /// 32 bytes of randomness, hex-encoded. Regenerated every `cider dev`, so a
    /// token cannot outlive the session it belongs to.
    public static func generate() -> DevSessionToken {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return DevSessionToken(token: bytes.map { String(format: "%02x", $0) }.joined())
    }
}

public struct DevProxyFetchRequest: Codable, Sendable {
    public var id: String
    public var method: String
    public var url: String
    public var headers: [String: String]
}

public struct DevProxyFetchResponse: Codable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: String
    public var error: String?
}

public final class DevDashboardServer: @unchecked Sendable {
    private let project: Project
    private let workspace: DevWorkspace
    private let events: DevEventLog
    private let sandbox: SandboxBrowser
    private let editor: SourceEditService
    private var captured: [CapturedHTTPRequest] = []
    private let port: Int
    private let sessionToken: DevSessionToken
    public var dashboardURL: String
    public var state: String = "ready"

    public init(
        project: Project,
        workspace: DevWorkspace,
        events: DevEventLog,
        port: Int = 5757,
        sessionToken: DevSessionToken = .generate()
    ) {
        self.project = project
        self.workspace = workspace
        self.events = events
        self.sandbox = SandboxBrowser(project: project)
        self.editor = SourceEditService(project: project, events: events)
        self.port = port
        self.sessionToken = sessionToken
        self.dashboardURL = "http://127.0.0.1:\(port)/"
    }

    /// The secret a caller must present to use a mutating route. Handed to the
    /// running application through its launch descriptor, and to the dashboard
    /// through a route CORS keeps same-origin.
    public var token: String { sessionToken.token }

    public func writeStaticAssets() throws {
        try workspace.prepare()
        try DevDashboardAssets.indexHTML.write(to: workspace.dashboardDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try DevDashboardAssets.appCSS.write(to: workspace.dashboardDirectory.appendingPathComponent("app.css"), atomically: true, encoding: .utf8)
        try DevDashboardAssets.appJS.write(to: workspace.dashboardDirectory.appendingPathComponent("app.js"), atomically: true, encoding: .utf8)
    }

    public func handle(
        method: String,
        path: String,
        query: [String: String] = [:],
        body: Data = Data(),
        headers: [String: String] = [:]
    ) -> DevDashboardResponse {
        let verb = method.uppercased()

        // A cross-origin page can reach a loopback port; CORS only stops it
        // reading the reply. Every request that changes something -- and the
        // route that hands out the token -- is checked before it is routed.
        if verb == "OPTIONS" {
            return preflight()
        }
        if verb != "GET", let refusal = refuseUnlessAuthorized(headers: headers) {
            return refusal
        }
        if path == "/api/dev/session", let refusal = refuseUnlessSameOrigin(headers: headers) {
            return refusal
        }

        do {
            switch (verb, path) {
            case ("GET", "/api/dev/session"):
                return .json(sessionToken)
            case ("GET", "/"), ("GET", "/index.html"):
                return .text(DevDashboardAssets.indexHTML, contentType: "text/html; charset=utf-8")
            case ("GET", "/assets/app.css"):
                return .text(DevDashboardAssets.appCSS, contentType: "text/css; charset=utf-8")
            case ("GET", "/assets/app.js"):
                return .text(DevDashboardAssets.appJS, contentType: "application/javascript; charset=utf-8")
            case ("GET", "/api/status"):
                return .json(DevDashboardStatus(project: project.manifest.appName, state: state, dashboardURL: dashboardURL))
            case ("GET", "/api/inspector/latest"):
                guard FileManager.default.fileExists(atPath: workspace.inspectorSnapshotURL.path) else { return DevDashboardResponse(status: 204) }
                return DevDashboardResponse(contentType: "application/json", body: try Data(contentsOf: workspace.inspectorSnapshotURL))
            case ("GET", "/api/inspector/frame"):
                // Raw RGBA behind a 16-byte header -- see CiderCore.FrameMirror.
                // Served as bytes because the browser hands it straight to
                // ImageData; encoding it as an image would mean adding a codec
                // Cider deliberately does not have.
                guard FileManager.default.fileExists(atPath: workspace.inspectorFrameURL.path) else {
                    return DevDashboardResponse(status: 204)
                }
                return DevDashboardResponse(
                    contentType: "application/octet-stream",
                    body: try Data(contentsOf: workspace.inspectorFrameURL)
                )
            case ("GET", "/api/events"):
                return .json(events.recent())
            case ("GET", "/api/network/requests"):
                return .json(captured)
            case ("POST", "/api/proxy/fetch"):
                return try proxyFetch(body: body)
            case ("GET", "/api/sandbox/tree"):
                return .json(try sandbox.tree())
            case ("GET", "/api/sandbox/file"):
                return .json(try sandbox.preview(relativePath: query["path"] ?? ""))
            case ("POST", "/api/editor/apply"):
                // A malformed body is the request's problem, not the server's,
                // so it gets a diagnostic rather than falling through to a 500.
                guard let request = try? JSONDecoder().decode(SourceEditRequest.self, from: body) else {
                    throw Diagnostic(
                        code: "CID0643",
                        summary: "malformed source edit request",
                        reason: "The request body was not a source edit the console understands.",
                        remedy: "Reload the dashboard at \(dashboardURL) and try the edit again."
                    )
                }
                return .json(try editor.apply(request))
            case ("POST", "/api/sandbox/reset"):
                try sandbox.reset(); events.append(kind: "sandbox", message: "sandbox reset"); return .json(["ok": true])
            default:
                return DevDashboardResponse(status: 404, contentType: "text/plain", body: Data("not found".utf8))
            }
        } catch let diagnostic as Diagnostic {
            // A refusal is an answer, not a server failure: it names what the
            // editor would not do and what the developer can do instead.
            return .refusal(diagnostic, status: status(for: diagnostic))
        } catch {
            return DevDashboardResponse(status: 500, contentType: "text/plain", body: Data(String(describing: error).utf8))
        }
    }

    /// Maps a refusal onto the status that describes it. Everything the editor
    /// declines is the request's problem, not the server's.
    private func status(for diagnostic: Diagnostic) -> Int {
        switch diagnostic.code {
        case "CID0634", "CID0642": return 409
        case "CID0631": return 403
        case "CID0630": return 413
        default: return 400
        }
    }

    /// Called when a snapshot newer than the last edit lands, meaning the
    /// application has relaunched and the panel's positions are current again.
    public func noteRebuildObserved() {
        editor.rebuildObserved()
    }

    public var isAwaitingRebuild: Bool { editor.isAwaitingRebuild }

    /// The preflight a custom request header forces. Answering it is what lets
    /// the dashboard send `X-Cider-Dev-Token` at all.
    private func preflight() -> DevDashboardResponse {
        DevDashboardResponse(
            status: 204,
            contentType: "text/plain",
            headers: [
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, \(DevSessionToken.headerName)",
                "Access-Control-Max-Age": "600",
            ]
        )
    }

    private func refuseUnlessSameOrigin(headers: [String: String]) -> DevDashboardResponse? {
        let allowed: Set<String> = ["http://127.0.0.1:\(port)", "http://localhost:\(port)"]
        if let origin = headers["origin"], !allowed.contains(origin) {
            return .refusal(Self.crossOrigin(detail: "Origin \(origin) is not this dashboard."), status: 403)
        }
        // A request with no Origin can still carry a forged Host, and a Host
        // that is not this dashboard means the request was not aimed here.
        let hosts: Set<String> = ["127.0.0.1:\(port)", "localhost:\(port)"]
        if let host = headers["host"], !hosts.contains(host) {
            return .refusal(Self.crossOrigin(detail: "Host \(host) is not this dashboard."), status: 403)
        }
        return nil
    }

    private func refuseUnlessAuthorized(headers: [String: String]) -> DevDashboardResponse? {
        if let refusal = refuseUnlessSameOrigin(headers: headers) { return refusal }
        guard headers[DevSessionToken.headerName] == sessionToken.token else {
            return .refusal(
                Diagnostic(
                    code: "CID0631",
                    summary: "dev console rejected an unauthenticated request",
                    reason: """
                        This request changes state and did not carry this session's \
                        \(DevSessionToken.headerName) header.
                        """,
                    remedy: "Reload the dashboard at \(dashboardURL); it fetches a fresh token on load."
                ),
                status: 403
            )
        }
        return nil
    }

    private static func crossOrigin(detail: String) -> Diagnostic {
        Diagnostic(
            code: "CID0631",
            summary: "dev console rejected a cross-origin request",
            reason: detail,
            remedy: "Use the dashboard served by `cider dev`; the console answers only its own origin."
        )
    }

    private func proxyFetch(body: Data) throws -> DevDashboardResponse {
        let request = try JSONDecoder().decode(DevProxyFetchRequest.self, from: body)
        guard request.method.uppercased() == "GET", let url = URL(string: request.url), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return .json(DevProxyFetchResponse(statusCode: 0, headers: [:], body: "", error: "Only absolute HTTP/HTTPS GET requests are supported."))
        }
        let started = DevClock.nowMilliseconds()
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        for (key, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: key) }
        let semaphore = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var data = Data(); var response: URLResponse?; var error: Error? }
        let box = Box()
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            box.data = data ?? Data(); box.response = response; box.error = error; semaphore.signal()
        }.resume()
        semaphore.wait()
        let duration = Int(DevClock.nowMilliseconds() - started)
        let http = box.response as? HTTPURLResponse
        let headers = (http?.allHeaderFields ?? [:]).reduce(into: [String: String]()) { partial, item in
            partial[String(describing: item.key)] = String(describing: item.value)
        }
        let preview = String(decoding: box.data.prefix(4096), as: UTF8.self)
        let record = CapturedHTTPRequest(
            id: request.id,
            startedAtMilliseconds: started,
            method: "GET",
            url: request.url,
            requestHeaders: request.headers,
            statusCode: http?.statusCode,
            responseHeaders: headers,
            responseBodyPreview: preview,
            error: box.error.map { String(describing: $0) },
            durationMilliseconds: duration
        )
        captured.append(record)
        events.append(kind: "network", message: "captured GET \(request.url)")
        appendCapture(record)
        return .json(DevProxyFetchResponse(statusCode: http?.statusCode ?? 0, headers: RequestHeaderRedaction.redact(headers), body: preview, error: box.error.map { String(describing: $0) }))
    }

    private func appendCapture(_ record: CapturedHTTPRequest) {
        guard let data = try? JSONEncoder().encode(record), let line = String(data: data, encoding: .utf8) else { return }
        try? FileManager.default.createDirectory(at: workspace.proxyLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: workspace.proxyLogURL.path), let handle = try? FileHandle(forWritingTo: workspace.proxyLogURL) {
            try? handle.seekToEnd(); try? handle.write(contentsOf: Data((line + "\n").utf8)); try? handle.close()
        } else {
            try? (line + "\n").write(to: workspace.proxyLogURL, atomically: true, encoding: .utf8)
        }
    }
}
