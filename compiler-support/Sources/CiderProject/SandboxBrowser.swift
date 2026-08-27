//  Safe browser for an application's Cider sandbox.

import Foundation
import CiderCore

public struct SandboxFileEntry: Codable, Equatable, Sendable {
    public var path: String
    public var size: Int
    public var modifiedAtMilliseconds: Int64
}

public struct SandboxFilePreview: Codable, Equatable, Sendable {
    public var path: String
    public var size: Int
    public var text: String
    public var isText: Bool
}

public final class SandboxBrowser {
    public let root: URL

    public init(project: Project, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.root = SandboxPathResolver.dataRoot(for: project.manifest.appID, environment: environment)
    }

    public func tree() throws -> [SandboxFileEntry] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var entries: [SandboxFileEntry] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isRegularFile == true else { continue }
            let relative = String(url.path.dropFirst(root.path.count + 1))
            entries.append(SandboxFileEntry(
                path: relative,
                size: values.fileSize ?? 0,
                modifiedAtMilliseconds: Int64((values.contentModificationDate ?? .distantPast).timeIntervalSince1970 * 1000)
            ))
        }
        return entries.sorted { $0.path < $1.path }
    }

    public func preview(relativePath: String) throws -> SandboxFilePreview {
        let url = try resolve(relativePath)
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
        return SandboxFilePreview(
            path: relativePath,
            size: data.count,
            text: text ?? data.prefix(512).map { String(format: "%02X", $0) }.joined(separator: " "),
            isText: text != nil
        )
    }

    public func reset() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        for name in ["Documents", "Cache", "tmp"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
        }
    }

    private func resolve(_ relativePath: String) throws -> URL {
        guard !relativePath.hasPrefix("/"), !relativePath.split(separator: "/").contains("..") else {
            throw Diagnostic(code: "CID0614", summary: "sandbox path escapes the app root")
        }
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path == root.path || url.path.hasPrefix(root.path + "/") else {
            throw Diagnostic(code: "CID0614", summary: "sandbox path escapes the app root")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Diagnostic(code: "CID0615", summary: "sandbox file does not exist", location: DiagnosticLocation(file: relativePath))
        }
        return url
    }
}
