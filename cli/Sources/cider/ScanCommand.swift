//  `cider scan`
//
//  Stage 4 developer-experience command. It scans Swift source for the small
//  compatibility registry's recognized-unsupported APIs and prints actionable
//  diagnostics before a developer reaches a vague compiler or runtime failure.

import CiderCore
import CiderProject

enum ScanCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        let diagnostics = try CompatibilityScanner.scan(project: project)

        if diagnostics.isEmpty {
            StandardStreams.out("[cider] compatibility scan passed")
            StandardStreams.out("[cider] project: \(project.root.path)")
            return 0
        }

        throw DiagnosticBundle(diagnostics)
    }
}
