//  Orchestrates the Stage 4 local developer loop.

import Foundation
import CiderCore

public final class DevSession {
    private let project: Project
    private let configuration: String
    private let port: Int
    private let openBrowser: Bool
    private let once: Bool
    public let workspace: DevWorkspace
    public let events: DevEventLog
    public let dashboard: DevDashboardServer
    private var watcher: ProjectFileWatcher?
    private var appProcess: Process?
    private var httpServer: DevHTTPServer?

    public init(project: Project, configuration: String = "debug", port: Int = 5757, openBrowser: Bool = false, once: Bool = false) {
        self.project = project
        self.configuration = configuration
        self.port = port
        self.openBrowser = openBrowser
        self.once = once
        self.workspace = DevWorkspace(project: project)
        self.events = DevEventLog(url: DevWorkspace(project: project).eventsURL)
        self.dashboard = DevDashboardServer(project: project, workspace: DevWorkspace(project: project), events: self.events, port: port)
    }

    public func start() throws -> String {
        try workspace.prepare()
        try dashboard.writeStaticAssets()
        if httpServer == nil {
            let server = DevHTTPServer(port: port) { [dashboard] request in
                dashboard.handle(method: request.method, path: request.path, query: request.query, body: request.body)
            }
            try server.start()
            httpServer = server
        }
        events.append(kind: "server", message: "dashboard listening at \(dashboard.dashboardURL)")
        watcher = try ProjectFileWatcher(project: project)
        if once {
            dashboard.state = "once"
            _ = dashboard.handle(method: "GET", path: "/api/status")
            events.append(kind: "server", message: "once validation completed")
            return dashboard.dashboardURL
        }
        try rebuildAndRelaunch()
        if openBrowser { _ = try? SwiftToolchain.run("xdg-open", [dashboard.dashboardURL]) }
        dashboard.state = "watching"
        return dashboard.dashboardURL
    }

    public func pollOnce() throws {
        guard let watcher else { return }
        let changes = try watcher.scan()
        guard !changes.isEmpty else { return }
        events.append(kind: "watch", message: "changed: " + changes.map(\.path).joined(separator: ", "))
        try rebuildAndRelaunch()
    }

    public func runForever() throws {
        _ = try start()
        while true {
            try pollOnce()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    public func stop() {
        if let appProcess, appProcess.isRunning { appProcess.terminate() }
        appProcess = nil
        events.append(kind: "app", message: "app stopped")
    }

    private func rebuildAndRelaunch() throws {
        stop()
        dashboard.state = "building"
        events.append(kind: "build", message: "swift build -c \(configuration) started")
        let result = try SwiftToolchain.build(packageDirectory: project.root, configuration: configuration)
        guard result.succeeded else {
            dashboard.state = "build failed"
            events.append(kind: "build", message: "build failed with status \(result.exitCode)")
            throw Diagnostic(code: "CID0620", summary: "dev build failed", reason: (result.standardOutput + result.standardError).trimmingASCIIWhitespace())
        }
        events.append(kind: "build", message: "build succeeded")
        let artifact = try artifactURL()
        let sandboxRoot = try SandboxPathResolver.prepare(for: project.manifest.appID)
        let descriptor = project.manifest.launchDescriptor(
            logLevel: .debug,
            inspectorEnabled: true,
            sandboxDataRoot: sandboxRoot.path,
            inspectorSnapshotPath: workspace.inspectorSnapshotURL.path,
            requestCaptureProxyURL: String(dashboard.dashboardURL.dropLast())
        )
        try write(descriptor)
        let process = Process()
        process.executableURL = artifact
        process.arguments = ["--cider-launch", project.launchDescriptorURL.path]
        process.currentDirectoryURL = project.root
        try process.run()
        appProcess = process
        dashboard.state = "running"
        events.append(kind: "app", message: "launched \(artifact.path)")
    }

    private func write(_ descriptor: LaunchDescriptor) throws {
        try FileManager.default.createDirectory(at: project.workDirectory, withIntermediateDirectories: true)
        try descriptor.encoded().write(to: project.launchDescriptorURL, atomically: true, encoding: .utf8)
    }

    private func artifactURL() throws -> URL {
        let product = try SwiftToolchain.executableProduct(packageDirectory: project.root)
        let binaryDirectory = try SwiftToolchain.binaryDirectory(packageDirectory: project.root, configuration: configuration)
        let artifact = binaryDirectory.appendingPathComponent(product)
        guard FileManager.default.isExecutableFile(atPath: artifact.path) else {
            throw Diagnostic(code: "CID0621", summary: "dev build produced no runnable artifact", location: DiagnosticLocation(file: artifact.path))
        }
        return artifact
    }
}
