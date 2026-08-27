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

    public init(status: Int = 200, contentType: String = "application/json", body: Data = Data()) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public static func text(_ text: String, contentType: String = "text/plain; charset=utf-8") -> DevDashboardResponse {
        DevDashboardResponse(contentType: contentType, body: Data(text.utf8))
    }

    public static func json<T: Encodable>(_ value: T) -> DevDashboardResponse {
        DevDashboardResponse(contentType: "application/json", body: (try? JSONEncoder().encode(value)) ?? Data())
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
    private var captured: [CapturedHTTPRequest] = []
    public var dashboardURL: String
    public var state: String = "ready"

    public init(project: Project, workspace: DevWorkspace, events: DevEventLog, port: Int = 5757) {
        self.project = project
        self.workspace = workspace
        self.events = events
        self.sandbox = SandboxBrowser(project: project)
        self.dashboardURL = "http://127.0.0.1:\(port)/"
    }

    public func writeStaticAssets() throws {
        try workspace.prepare()
        try DevDashboardAssets.indexHTML.write(to: workspace.dashboardDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try DevDashboardAssets.appCSS.write(to: workspace.dashboardDirectory.appendingPathComponent("app.css"), atomically: true, encoding: .utf8)
        try DevDashboardAssets.appJS.write(to: workspace.dashboardDirectory.appendingPathComponent("app.js"), atomically: true, encoding: .utf8)
    }

    public func handle(method: String, path: String, query: [String: String] = [:], body: Data = Data()) -> DevDashboardResponse {
        do {
            switch (method.uppercased(), path) {
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
            case ("POST", "/api/sandbox/reset"):
                try sandbox.reset(); events.append(kind: "sandbox", message: "sandbox reset"); return .json(["ok": true])
            default:
                return DevDashboardResponse(status: 404, contentType: "text/plain", body: Data("not found".utf8))
            }
        } catch {
            return DevDashboardResponse(status: 500, contentType: "text/plain", body: Data(String(describing: error).utf8))
        }
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
