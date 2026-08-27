//  Dependency-free polling file watcher for Cider projects.

import Foundation

public struct ProjectChange: Equatable, Sendable {
    public enum Kind: String, Sendable { case created, modified, deleted }
    public var path: String
    public var kind: Kind
}

struct FileFingerprint: Equatable {
    var modified: Date
    var size: UInt64
}

public final class ProjectFileWatcher {
    private let project: Project
    private var snapshot: [String: FileFingerprint]

    public init(project: Project) throws {
        self.project = project
        self.snapshot = try Self.scanFiles(under: project.root)
    }

    public func scan() throws -> [ProjectChange] {
        let current = try Self.scanFiles(under: project.root)
        var changes: [ProjectChange] = []
        for (path, fingerprint) in current {
            if let old = snapshot[path] {
                if old != fingerprint { changes.append(ProjectChange(path: path, kind: .modified)) }
            } else {
                changes.append(ProjectChange(path: path, kind: .created))
            }
        }
        for path in snapshot.keys where current[path] == nil {
            changes.append(ProjectChange(path: path, kind: .deleted))
        }
        snapshot = current
        return changes.sorted { $0.path < $1.path }
    }

    private static func scanFiles(under root: URL) throws -> [String: FileFingerprint] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }
        var files: [String: FileFingerprint] = [:]
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey, .fileSizeKey])
            if values.isDirectory == true, [".build", ".git", ".cider", "DerivedData"].contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true else { continue }
            guard shouldWatch(url) else { continue }
            files[url.path] = FileFingerprint(modified: values.contentModificationDate ?? .distantPast, size: UInt64(values.fileSize ?? 0))
        }
        return files
    }

    private static func shouldWatch(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return url.pathExtension == "swift" || name == "Package.swift" || name == "Cider.yaml"
    }
}
