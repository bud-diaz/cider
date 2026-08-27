//  The `cider` executable.
//
//  This binary deliberately does not link the runtime or any host backend. Two
//  reasons, both about the failure cases rather than the happy path.
//
//  `cider doctor` exists to diagnose a machine that cannot run Cider. A CLI that
//  linked libX11 would fail to start on exactly the machine where libX11 is what
//  is missing, and the developer would get a loader error instead of an
//  explanation.
//
//  And `cider run` launches the application as a separate process, so a crash in
//  developer code cannot take the toolchain's error reporting with it.

#if canImport(Glibc)
import Glibc
#endif

import CiderCore

let arguments = Array(CommandLine.arguments.dropFirst())

let exitCode: Int32 = {
    do {
        let command = try CommandLineParser.parse(arguments)

        if command.has("--version") {
            StandardStreams.out(Usage.version)
            return 0
        }
        if command.has("--help") || command.has("-h") || command.name.isEmpty {
            StandardStreams.out(Usage.text)
            return command.name.isEmpty && !command.has("--help") && !command.has("-h") ? 1 : 0
        }

        switch command.name {
        case "doctor":
            return DoctorCommand.run(command)
        case "scan":
            return try ScanCommand.run(command)
        case "compatibility-docs":
            return try CompatibilityDocsCommand.run(command)
        case "inspect":
            return try InspectCommand.run(command)
        case "network":
            return try NetworkCommand.run(command)
        case "storage":
            return try StorageCommand.run(command)
        case "init":
            return try InitCommand.run(command)
        case "dev-loop":
            return try DevLoopCommand.run(command)
        case "dev":
            return try DevCommand.run(command)
        case "build":
            return try BuildCommand.run(command)
        case "run":
            return try RunCommand.run(command)
        default:
            throw Diagnostic(
                code: "CID0512",
                summary: "unknown command `\(command.name)`",
                reason: "Cider has commands for doctor, scan, compatibility-docs, inspect, network, storage, init, dev-loop, dev, build and run.",
                remedy: "Run `cider --help` to see what each does."
            )
        }
    } catch let diagnostic as Diagnostic {
        StandardStreams.error("")
        StandardStreams.error(diagnostic.formatted())
        StandardStreams.error("")
        return 1
    } catch let bundle as DiagnosticBundle {
        StandardStreams.error("")
        StandardStreams.error(bundle.formatted())
        StandardStreams.error("")
        let count = bundle.diagnostics.count
        StandardStreams.error("\(count) problem\(count == 1 ? "" : "s") found.")
        StandardStreams.error("")
        return 1
    } catch {
        StandardStreams.error("error: \(error)")
        return 1
    }
}()

exit(exitCode)
