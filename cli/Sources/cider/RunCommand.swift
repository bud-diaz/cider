//  `cider run`
//
//  The division of labour matters here. The CLI resolves configuration and
//  starts a process; the runtime runs the application. Nothing about lifecycle,
//  rendering or input lives in this file -- if it did, the runtime would only be
//  correct when launched from the CLI, and every test would have to go through a
//  subprocess to be realistic.

import Foundation

import CiderCore
import CiderDeviceProfiles
import CiderProject

enum RunCommand {

    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try BuildCommand.locateProject(command)
        let configuration = command.option("--configuration") ?? "debug"
        try BuildCommand.validate(configuration: configuration)

        let logLevel = try resolveLogLevel(command)
        let device = try resolveDevice(command, manifest: project.manifest)

        if !command.has("--no-build") {
            let status = try BuildCommand.run(command)
            guard status == 0 else { return status }
        }

        let artifact = try BuildCommand.artifactURL(for: project, configuration: configuration)

        let sandboxRoot = try SandboxPathResolver.prepare(for: project.manifest.appID)

        let descriptor = project.manifest.launchDescriptor(
            deviceOverride: device.name,
            logLevel: logLevel,
            inspectorEnabled: command.has("--inspect"),
            sandboxDataRoot: sandboxRoot.path
        )
        let descriptorURL = try write(descriptor, for: project)

        // The runtime logs its own "launching" line as soon as it starts, so the
        // CLI does not repeat it.

        // The application is a separate process on purpose: it owns the window
        // and the event loop, and a crash in developer code should not take the
        // toolchain's error reporting down with it.
        let process = Process()
        process.executableURL = artifact
        process.arguments = [LaunchFlags.descriptor, descriptorURL.path]
        process.currentDirectoryURL = project.root

        // Output is inherited rather than captured: `cider run` is an
        // interactive command, and a developer's print statements should appear
        // as they happen, not after the window closes.
        do {
            try process.run()
        } catch {
            throw Diagnostic(
                code: "CID0530",
                summary: "could not start the application",
                location: DiagnosticLocation(file: artifact.path),
                reason: "The built artifact could not be executed: \(error.localizedDescription)",
                remedy: "Run `cider build` and check that the artifact exists and is executable."
            )
        }
        process.waitUntilExit()

        let status = process.terminationStatus
        if status != 0 {
            StandardStreams.out("[cider] application exited with status \(status)")
        }
        return status
    }

    // MARK: - Configuration

    static func resolveLogLevel(_ command: ParsedCommand) throws -> LogLevel {
        guard let raw = command.option("--log-level") else { return .info }
        guard let level = LogLevel(name: raw) else {
            let names = LogLevel.allCases.map(\.name).joined(separator: ", ")
            throw Diagnostic(
                code: "CID0531",
                summary: "unknown log level `\(raw)`",
                reason: "Cider has five log levels.",
                remedy: "Pass one of: \(names)."
            )
        }
        return level
    }

    static func resolveDevice(_ command: ParsedCommand, manifest: Manifest) throws -> DeviceProfile {
        let name = command.option("--device") ?? manifest.deviceProfileName
        return try DeviceProfileRegistry.resolve(name)
    }

    /// Writes the launch descriptor into the project's work directory.
    static func write(_ descriptor: LaunchDescriptor, for project: Project) throws -> URL {
        let directory = project.workDirectory
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try descriptor.encoded().write(
                to: project.launchDescriptorURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw Diagnostic(
                code: "CID0532",
                summary: "could not write the launch descriptor",
                location: DiagnosticLocation(file: project.launchDescriptorURL.path),
                reason: "Cider writes the resolved configuration to \(directory.path): \(error.localizedDescription)",
                remedy: "Check that \(project.root.path) is writable."
            )
        }
        return project.launchDescriptorURL
    }
}

enum LaunchFlags {
    /// Must match `LaunchEnvironment.descriptorFlag` in CiderUI. The two sides
    /// are in different modules because the CLI must not link the runtime.
    static let descriptor = "--cider-launch"
}
