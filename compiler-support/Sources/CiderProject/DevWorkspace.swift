//  Paths for the local Stage 4 developer console.

import Foundation

public struct DevWorkspace: Sendable {
    public var root: URL
    public var inspectorSnapshotURL: URL
    public var eventsURL: URL
    public var proxyLogURL: URL
    public var dashboardDirectory: URL

    public init(project: Project) {
        root = project.workDirectory.appendingPathComponent("dev", isDirectory: true)
        inspectorSnapshotURL = root.appendingPathComponent("inspector/latest.json")
        eventsURL = root.appendingPathComponent("events.jsonl")
        proxyLogURL = root.appendingPathComponent("proxy/requests.jsonl")
        dashboardDirectory = root.appendingPathComponent("dashboard", isDirectory: true)
    }

    public func prepare() throws {
        let directories = [
            root,
            inspectorSnapshotURL.deletingLastPathComponent(),
            eventsURL.deletingLastPathComponent(),
            proxyLogURL.deletingLastPathComponent(),
            dashboardDirectory,
        ]
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
