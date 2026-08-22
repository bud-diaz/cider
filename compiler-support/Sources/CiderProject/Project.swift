//  Project discovery and on-disk layout.

import Foundation

import CiderCore

/// A located Cider project.
public struct Project {
    /// Directory containing Cider.yaml.
    public let root: URL

    public let manifestURL: URL
    public let manifest: Manifest

    /// Where Cider keeps generated files. Ignored by version control.
    public var workDirectory: URL {
        root.appendingPathComponent(".cider", isDirectory: true)
    }

    public var launchDescriptorURL: URL {
        workDirectory.appendingPathComponent("launch.descriptor")
    }

    public init(root: URL, manifestURL: URL, manifest: Manifest) {
        self.root = root
        self.manifestURL = manifestURL
        self.manifest = manifest
    }
}

public enum ProjectLocator {
    public static let manifestFileName = "Cider.yaml"

    /// Finds the project containing `directory`, searching upward.
    ///
    /// Searching upward means `cider run` works from a subdirectory, the way
    /// version-control and build tools do. The search stops at the filesystem
    /// root and reports where it looked, so a developer in the wrong directory
    /// finds out immediately.
    public static func locate(from directory: URL) throws -> Project {
        var current = directory.standardizedFileURL
        var searched: [String] = []

        while true {
            let candidate = current.appendingPathComponent(manifestFileName)
            searched.append(candidate.path)

            if FileManager.default.fileExists(atPath: candidate.path) {
                return try load(manifestAt: candidate, root: current)
            }

            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent.path == current.path { break }
            current = parent
        }

        throw Diagnostic(
            code: "CID0420",
            summary: "no Cider project found",
            reason: """
                Cider looked for \(manifestFileName) in \(directory.path) and every directory \
                above it, and found none.
                """,
            remedy: """
                Run this command from a directory containing \(manifestFileName), for example:

                    cd examples/hello-cider
                    cider run
                """
        )
    }

    public static func load(manifestAt url: URL, root: URL) throws -> Project {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw Diagnostic(
                code: "CID0421",
                summary: "could not read \(manifestFileName)",
                location: DiagnosticLocation(file: url.path),
                reason: "The file exists but could not be opened.",
                remedy: "Check the file's permissions."
            )
        }

        let text = String(decoding: data, as: UTF8.self)
        let manifest = try ManifestParser.parse(text, file: url.path)
        return Project(root: root, manifestURL: url, manifest: manifest)
    }
}
