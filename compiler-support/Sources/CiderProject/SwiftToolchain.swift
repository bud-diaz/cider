//  Driving the Swift toolchain.
//
//  Cider does not implement a build system. `cider build` locates the project,
//  validates its manifest, and hands the compilation to SwiftPM -- which is
//  already the supported way to build Swift on Linux, already produces
//  incremental builds, and already knows how to link Cider's C shims through
//  pkg-config. See docs/adr/0005-swift-runtime-integration.md.
//
//  What Cider adds is everything around the compile: the manifest, the device
//  profile, the launch descriptor and the runtime.

import Foundation

import CiderCore

/// The result of running a subprocess.
public struct ProcessResult {
    public var exitCode: Int32
    public var standardOutput: String
    public var standardError: String

    public var succeeded: Bool { exitCode == 0 }
}

public enum SwiftToolchain {

    /// Runs an executable and captures its output.
    ///
    /// Output is captured rather than inherited so callers can decide what to
    /// show. `cider build` streams the compiler's own diagnostics through
    /// untouched, because a Swift error message is already better than anything
    /// Cider would produce by reformatting it.
    public static func run(
        _ executable: String,
        _ arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        if let environment {
            process.environment = environment
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw Diagnostic(
                code: "CID0430",
                summary: "could not run `\(executable)`",
                reason: "The process could not be started: \(error.localizedDescription)",
                remedy: "Check that `\(executable)` is installed and on PATH."
            )
        }

        // Read both pipes before waiting: a child that fills a pipe buffer while
        // the parent waits for exit deadlocks, and the Swift compiler is
        // perfectly capable of producing that much output.
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )
    }

    /// Returns the version string `swift --version` reports, or nil when Swift
    /// is not installed.
    public static func swiftVersion() -> String? {
        guard let result = try? run("swift", ["--version"]), result.succeeded else {
            return nil
        }
        let combined = result.standardOutput + result.standardError
        return combined
            .split(separator: "\n")
            .first { $0.contains("Swift version") }
            .map { $0.trimmingASCIIWhitespace() }
    }

    /// Extracts `(major, minor)` from a `swift --version` line.
    public static func parseSwiftVersion(_ text: String) -> (major: Int, minor: Int)? {
        guard let range = text.range(of: "Swift version ") else { return nil }
        let remainder = text[range.upperBound...]
        let token = remainder.prefix { $0.isNumber || $0 == "." }
        let parts = token.split(separator: ".")
        guard let major = parts.first.flatMap({ Int($0) }) else { return nil }
        let minor = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return (major, minor)
    }

    /// Builds the package rooted at `directory`.
    ///
    /// Compiler diagnostics are returned verbatim in the result; the caller
    /// prints them.
    public static func build(
        packageDirectory: URL,
        configuration: String = "debug"
    ) throws -> ProcessResult {
        try run(
            "swift",
            ["build", "--package-path", packageDirectory.path, "-c", configuration],
            workingDirectory: packageDirectory
        )
    }

    /// Returns the directory SwiftPM puts binaries in.
    public static func binaryDirectory(
        packageDirectory: URL,
        configuration: String = "debug"
    ) throws -> URL {
        let result = try run(
            "swift",
            ["build", "--package-path", packageDirectory.path, "-c", configuration, "--show-bin-path"],
            workingDirectory: packageDirectory
        )
        guard result.succeeded else {
            throw Diagnostic(
                code: "CID0431",
                summary: "could not determine the build output directory",
                reason: result.standardError.trimmingASCIIWhitespace(),
                remedy: "Run `swift build --show-bin-path` in the project directory to see the failure."
            )
        }
        let path = result.standardOutput.trimmingASCIIWhitespace()
        guard !path.isEmpty else {
            throw Diagnostic(
                code: "CID0431",
                summary: "could not determine the build output directory",
                reason: "`swift build --show-bin-path` produced no output.",
                remedy: "Check that the project has a Package.swift."
            )
        }
        return URL(fileURLWithPath: path)
    }

    /// Finds the single executable product the project builds.
    ///
    /// Cider requires exactly one. Guessing which of several to launch would be
    /// the kind of implicit behaviour that is fine until the day it picks wrong.
    public static func executableProduct(packageDirectory: URL) throws -> String {
        let result = try run(
            "swift",
            ["package", "--package-path", packageDirectory.path, "describe", "--type", "json"],
            workingDirectory: packageDirectory
        )
        guard result.succeeded else {
            throw Diagnostic(
                code: "CID0432",
                summary: "could not read the Swift package description",
                location: DiagnosticLocation(file: packageDirectory.appendingPathComponent("Package.swift").path),
                reason: result.standardError.trimmingASCIIWhitespace(),
                remedy: "Fix the errors reported above, then run `cider build` again."
            )
        }

        guard
            let data = result.standardOutput.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let products = root["products"] as? [[String: Any]]
        else {
            throw Diagnostic(
                code: "CID0432",
                summary: "could not read the Swift package description",
                reason: "`swift package describe --type json` produced output Cider could not parse.",
                remedy: "Report this with the output of that command."
            )
        }

        let executables = products.compactMap { product -> String? in
            guard let name = product["name"] as? String else { return nil }
            // SwiftPM describes a product's type as a dictionary keyed by kind.
            guard let type = product["type"] as? [String: Any], type["executable"] != nil else {
                return nil
            }
            return name
        }

        switch executables.count {
        case 1:
            return executables[0]
        case 0:
            throw Diagnostic(
                code: "CID0433",
                summary: "the project builds no executable",
                location: DiagnosticLocation(file: packageDirectory.appendingPathComponent("Package.swift").path),
                reason: "Cider launches an executable product, and Package.swift declares none.",
                remedy: """
                    Add an executable product to Package.swift:

                        products: [.executable(name: "MyApp", targets: ["MyApp"])]
                    """
            )
        default:
            let names = executables.sorted().joined(separator: ", ")
            throw Diagnostic(
                code: "CID0434",
                summary: "the project builds more than one executable",
                location: DiagnosticLocation(file: packageDirectory.appendingPathComponent("Package.swift").path),
                reason: "Cider found \(executables.count) executable products: \(names).",
                remedy: "Leave exactly one executable product in Package.swift."
            )
        }
    }
}
