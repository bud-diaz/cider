//  `cider build`

import Foundation

import CiderCore
import CiderProject

enum BuildCommand {

    static func run(_ command: ParsedCommand) throws -> Int32 {
        let project = try locateProject(command)
        let configuration = command.option("--configuration") ?? "debug"
        try validate(configuration: configuration)

        StandardStreams.out("[cider] building \(project.manifest.appID) (\(configuration))")
        StandardStreams.out("[cider] project: \(project.root.path)")

        let result = try SwiftToolchain.build(
            packageDirectory: project.root,
            configuration: configuration
        )

        // The Swift compiler's diagnostics are better than anything Cider would
        // produce by reformatting them, so they go through untouched.
        let compilerOutput = (result.standardOutput + result.standardError).trimmingASCIIWhitespace()
        if !compilerOutput.isEmpty {
            StandardStreams.out(compilerOutput)
        }

        guard result.succeeded else {
            throw Diagnostic(
                code: "CID0520",
                summary: "the application did not compile",
                location: DiagnosticLocation(file: project.root.appendingPathComponent("Package.swift").path),
                reason: "`swift build` exited with status \(result.exitCode). Its output is above.",
                remedy: "Fix the errors the compiler reported, then run `cider build` again."
            )
        }

        let artifact = try artifactURL(for: project, configuration: configuration)
        StandardStreams.out("[cider] built \(artifact.path)")
        return 0
    }

    /// Locates the project a command should act on.
    static func locateProject(_ command: ParsedCommand) throws -> Project {
        let directory = command.option("--path").map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return try ProjectLocator.locate(from: directory)
    }

    static func validate(configuration: String) throws {
        guard configuration == "debug" || configuration == "release" else {
            throw Diagnostic(
                code: "CID0521",
                summary: "unknown build configuration `\(configuration)`",
                reason: "SwiftPM builds either `debug` or `release`.",
                remedy: "Pass `--configuration debug` or `--configuration release`."
            )
        }
    }

    /// The runnable host artifact a build produced.
    static func artifactURL(for project: Project, configuration: String) throws -> URL {
        let product = try SwiftToolchain.executableProduct(packageDirectory: project.root)
        let binaryDirectory = try SwiftToolchain.binaryDirectory(
            packageDirectory: project.root,
            configuration: configuration
        )
        let artifact = binaryDirectory.appendingPathComponent(product)

        guard FileManager.default.isExecutableFile(atPath: artifact.path) else {
            throw Diagnostic(
                code: "CID0522",
                summary: "the build produced no runnable artifact",
                reason: """
                    Cider expected an executable at \(artifact.path) after a successful build, \
                    and found none.
                    """,
                remedy: "Run `swift build` in \(project.root.path) and check what it produced."
            )
        }
        return artifact
    }
}
