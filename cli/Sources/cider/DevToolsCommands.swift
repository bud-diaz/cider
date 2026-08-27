//  Stage 4 developer-experience CLI commands.

import Foundation
import CiderCore
import CiderProject

enum InspectCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        StandardStreams.out(try ProjectInspector.report(for: project))
        return 0
    }
}

enum NetworkCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        StandardStreams.out(try NetworkViewer.report(for: project))
        return 0
    }
}

enum StorageCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        StandardStreams.out(try StorageViewer.report(for: project))
        return 0
    }
}

enum DevLoopCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        let configuration = command.option("--configuration") ?? "debug"
        try BuildCommand.validate(configuration: configuration)
        StandardStreams.out(DevLoopPlanner.plan(for: project, configuration: configuration))
        return 0
    }
}

enum InitCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        guard let name = command.positional.first else {
            throw Diagnostic(
                code: "CID0613",
                summary: "template name is missing",
                reason: "`cider init` needs the Swift type/package name to create.",
                remedy: "Run `cider init MyApp --app-id dev.example.myapp --path ./MyApp`."
            )
        }
        let appID = command.option("--app-id") ?? "dev.example.\(name.lowercased())"
        let destination = command.option("--path").map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(name, isDirectory: true)
        try TemplateGenerator.createApp(named: name, appID: appID, at: destination)
        StandardStreams.out("[cider] created template at \(destination.path)")
        return 0
    }
}


enum DevCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        let configuration = command.option("--configuration") ?? "debug"
        try BuildCommand.validate(configuration: configuration)
        let port = Int(command.option("--port") ?? "5757") ?? 5757
        let session = DevSession(
            project: project,
            configuration: configuration,
            port: port,
            openBrowser: command.has("--open"),
            once: command.has("--once")
        )
        if command.has("--once") {
            let url = try session.start()
            StandardStreams.out("[cider] dev dashboard validated at \(url)")
            return 0
        }
        StandardStreams.out("[cider] dev dashboard: \(session.dashboard.dashboardURL)")
        StandardStreams.out("[cider] watching for source changes; press Ctrl-C to stop")
        try session.runForever()
        return 0
    }
}
