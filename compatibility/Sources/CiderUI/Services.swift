//  Stage 3 application services exposed to Cider applications.
//
//  These are deliberately project-owned APIs rather than Foundation/UIKit
//  facades. The contract is Cider's documented development-runtime behaviour:
//  permission checked, sandbox scoped, deterministic enough for tests, and small
//  enough to port behind the same public surface later.

import CiderCore
import CiderRuntime
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Runtime values for the currently running Cider application.
public enum CiderEnvironment {
    public static var appID: String? { CiderServiceContext.current?.appID }
    public static var appName: String? { CiderServiceContext.current?.appName }
    public static var deviceName: String? { CiderServiceContext.current?.deviceProfile.name }
    public static var sandboxRoot: String? { CiderServiceContext.current?.sandbox?.root }
}

/// A per-application key/value preferences store.
public struct CiderPreferences: Sendable {
    public static let standard = CiderPreferences()

    public func string(forKey key: String) throws -> String? {
        try CiderServiceContext.requireLocalStorage()
        return try readAll()[key]
    }

    public func set(_ value: String?, forKey key: String) throws {
        try CiderServiceContext.requireSafeKey(key)
        try CiderServiceContext.requireLocalStorage()
        var values = try readAll()
        values[key] = value
        try writeAll(values)
    }

    private var fileURL: URL {
        get throws {
            let root = try CiderServiceContext.requireSandboxRoot()
            return URL(fileURLWithPath: root)
                .appendingPathComponent("Preferences", isDirectory: true)
                .appendingPathComponent("preferences.txt")
        }
    }

    private func readAll() throws -> [String: String] {
        let url = try fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let text = try String(contentsOf: url, encoding: .utf8)
        var values: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) where !line.isEmpty {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let keyData = Data(base64Encoded: String(parts[0])),
                  let valueData = Data(base64Encoded: String(parts[1])),
                  let key = String(data: keyData, encoding: .utf8),
                  let value = String(data: valueData, encoding: .utf8)
            else { continue }
            values[key] = value
        }
        return values
    }

    private func writeAll(_ values: [String: String]) throws {
        let url = try fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = values.keys.sorted().map { key in
            let encodedKey = Data(key.utf8).base64EncodedString()
            let encodedValue = Data((values[key] ?? "").utf8).base64EncodedString()
            return "\(encodedKey)\t\(encodedValue)"
        }.joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Sandboxed documents/cache/temp text-file storage.
public enum CiderStorage {
    public static let documents = CiderStorageArea(directoryName: "Documents")
    public static let cache = CiderStorageArea(directoryName: "Cache")
    public static let temporary = CiderStorageArea(directoryName: "tmp")
}

public struct CiderStorageArea: Sendable {
    let directoryName: String

    public func writeText(_ text: String, named name: String) throws {
        let url = try fileURL(named: name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func readText(named name: String) throws -> String {
        try String(contentsOf: fileURL(named: name), encoding: .utf8)
    }

    private func fileURL(named name: String) throws -> URL {
        try CiderServiceContext.requireLocalStorage()
        try CiderServiceContext.requireSafeRelativePath(name)
        let root = try CiderServiceContext.requireSandboxRoot()
        return URL(fileURLWithPath: root)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(name)
    }
}

/// A development clipboard scoped to the running Cider process.
public enum CiderClipboard {
    public static var text: String? { CiderServiceContext.clipboardText }

    public static func copy(_ text: String) {
        CiderServiceContext.clipboardText = text
    }

    public static func clear() {
        CiderServiceContext.clipboardText = nil
    }
}

/// One-shot timers for application code.
public enum CiderTimer {
    public static func after(milliseconds: Int, _ action: @escaping @Sendable () -> Void) {
        let delay = DispatchTimeInterval.milliseconds(max(0, milliseconds))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
}

public struct CiderHTTPResponse: Equatable, Sendable {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}


private struct CiderHTTPProxyRequest: Codable {
    var id: String
    var method: String
    var url: String
    var headers: [String: String]
}

private struct CiderHTTPProxyResponse: Codable {
    var statusCode: Int
    var headers: [String: String]
    var body: String
    var error: String?
}

/// Minimal HTTP/HTTPS client with manifest permission enforcement.
public enum CiderHTTP {
    public static func get(_ urlString: String) async throws -> CiderHTTPResponse {
        let url = try checkedURL(urlString)
        if let proxy = CiderServiceContext.current?.requestCaptureProxyURL, !proxy.isEmpty {
            return try await getThroughProxy(url.absoluteString, proxyURL: proxy)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        return responseFrom(data: data, response: response)
    }

    /// Synchronous GET for simple button-action demos. Real applications should
    /// prefer the async form once Cider has an event-loop-friendly task API.
    public static func getBlocking(_ urlString: String) throws -> CiderHTTPResponse {
        let url = try checkedURL(urlString)
        if let proxy = CiderServiceContext.current?.requestCaptureProxyURL, !proxy.isEmpty {
            return try getBlockingThroughProxy(url.absoluteString, proxyURL: proxy)
        }
        let semaphore = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var result: Result<(Data, URLResponse?), Error>? }
        let box = Box()
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error { box.result = .failure(error) }
            else { box.result = .success((data ?? Data(), response)) }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        let (data, response) = try box.result!.get()
        guard let response else { return CiderHTTPResponse(statusCode: 0, body: String(decoding: data, as: UTF8.self)) }
        return responseFrom(data: data, response: response)
    }



    private static func proxyPayload(for urlString: String) throws -> Data {
        let request = CiderHTTPProxyRequest(
            id: UUID().uuidString,
            method: "GET",
            url: urlString,
            headers: [:]
        )
        return try JSONEncoder().encode(request)
    }

    private static func proxyEndpoint(_ proxyURL: String) throws -> URL {
        let trimmed = proxyURL.hasSuffix("/") ? String(proxyURL.dropLast()) : proxyURL
        guard let url = URL(string: trimmed + "/api/proxy/fetch") else {
            throw Diagnostic(code: "CID0606", summary: "request capture proxy URL is invalid")
        }
        return url
    }

    private static func responseFromProxyData(_ data: Data) throws -> CiderHTTPResponse {
        let proxyResponse = try JSONDecoder().decode(CiderHTTPProxyResponse.self, from: data)
        if let error = proxyResponse.error, !error.isEmpty {
            throw Diagnostic(code: "CID0607", summary: "request capture proxy failed", reason: error)
        }
        return CiderHTTPResponse(statusCode: proxyResponse.statusCode, body: proxyResponse.body)
    }

    private static func getThroughProxy(_ urlString: String, proxyURL: String) async throws -> CiderHTTPResponse {
        var request = URLRequest(url: try proxyEndpoint(proxyURL))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let (data, _) = try await URLSession.shared.upload(for: request, from: try proxyPayload(for: urlString))
        return try responseFromProxyData(data)
    }

    private static func getBlockingThroughProxy(_ urlString: String, proxyURL: String) throws -> CiderHTTPResponse {
        var request = URLRequest(url: try proxyEndpoint(proxyURL))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try proxyPayload(for: urlString)
        let semaphore = DispatchSemaphore(value: 0)
        final class Box: @unchecked Sendable { var result: Result<Data, Error>? }
        let box = Box()
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error { box.result = .failure(error) }
            else { box.result = .success(data ?? Data()) }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return try responseFromProxyData(try box.result!.get())
    }

    private static func checkedURL(_ urlString: String) throws -> URL {
        guard CiderServiceContext.current?.permissions.network == true else {
            throw Diagnostic(
                code: "CID0604",
                summary: "network permission is required",
                reason: "This application called CiderHTTP, but its manifest did not grant `permissions.network`.",
                remedy: "Set `permissions.network: true` in Cider.yaml, then re-run `cider run`."
            )
        }
        guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased()) else {
            throw Diagnostic(
                code: "CID0605",
                summary: "HTTP URL is invalid",
                reason: "CiderHTTP supports absolute http:// and https:// URLs."
            )
        }
        return url
    }

    private static func responseFrom(data: Data, response: URLResponse) -> CiderHTTPResponse {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return CiderHTTPResponse(statusCode: status, body: String(decoding: data, as: UTF8.self))
    }
}

enum CiderServiceContext {
    nonisolated(unsafe) static var current: RuntimeContext?
    nonisolated(unsafe) static var clipboardText: String?

    static func attach(_ context: RuntimeContext) {
        current = context
        clipboardText = nil
    }

    static func detach() {
        current = nil
        clipboardText = nil
    }

    static func requireLocalStorage() throws {
        guard current?.permissions.localStorage == true else {
            throw Diagnostic(
                code: "CID0601",
                summary: "local storage permission is required",
                reason: "This application tried to use sandboxed storage, but its manifest did not grant `permissions.localStorage`.",
                remedy: "Set `permissions.localStorage: true` in Cider.yaml, then re-run `cider run`."
            )
        }
    }

    static func requireSandboxRoot() throws -> String {
        guard let root = current?.sandbox?.root, !root.isEmpty else {
            throw Diagnostic(
                code: "CID0602",
                summary: "sandbox storage is unavailable",
                reason: "The application was not launched through `cider run`, so no sandbox data root was prepared.",
                remedy: "Launch the app with `cider run` before using CiderStorage or CiderPreferences."
            )
        }
        return root
    }

    static func requireSafeKey(_ key: String) throws {
        guard !key.isEmpty, !key.contains("\n"), !key.contains("\t") else {
            throw Diagnostic(code: "CID0603", summary: "storage key is invalid")
        }
    }

    static func requireSafeRelativePath(_ path: String) throws {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.split(separator: "/").contains(".."),
              !path.contains("\0")
        else {
            throw Diagnostic(
                code: "CID0603",
                summary: "storage path escapes the sandbox",
                reason: "Storage names must be relative paths inside the selected Cider storage area."
            )
        }
    }
}
