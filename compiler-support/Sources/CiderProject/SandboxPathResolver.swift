//  Where an application's isolated data lives on disk, and creating it.
//
//  docs/03-technical-architecture.md section 8 (Security Model) asks for
//  per-app data roots. Nothing consumes this yet -- storage services are
//  Stage 3 -- but the root itself, isolated by app identifier, is a Stage 1
//  deliverable: `cider run` should hand every application a real, private
//  place on disk before there is anything to put in it.

import Foundation

import CiderCore

public enum SandboxPathResolver {

    /// Resolves the data root for `appID`, without touching the filesystem.
    ///
    /// Follows the XDG base directory spec: `$XDG_DATA_HOME/cider/apps/<id>`,
    /// falling back to `~/.local/share/cider/apps/<id>` when unset, which is
    /// what XDG itself specifies as the default.
    public static func dataRoot(for appID: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let base: URL
        if let xdgDataHome = environment["XDG_DATA_HOME"], !xdgDataHome.isEmpty {
            base = URL(fileURLWithPath: xdgDataHome)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("share", isDirectory: true)
        }
        return base
            .appendingPathComponent("cider", isDirectory: true)
            .appendingPathComponent("apps", isDirectory: true)
            .appendingPathComponent(appID, isDirectory: true)
    }

    /// Resolves and creates the data root and its standard subdirectories,
    /// and returns the root.
    ///
    /// `appID` is validated here rather than trusted from the caller: this is
    /// the one place a malformed or hostile identifier could turn into a path
    /// that escapes the sandbox root, so docs/06-testing-strategy.md's "path
    /// traversal resistance" is enforced at the point of use, not only by the
    /// manifest parser that happens to call this today.
    public static func prepare(
        for appID: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        guard ManifestParser.isValidAppID(appID) else {
            throw Diagnostic(
                code: "CID0423",
                summary: "`\(appID)` is not a valid application identifier",
                reason: """
                    Cider derives the sandbox data root from the application identifier. An \
                    identifier containing a path separator or `..` could escape the sandbox root.
                    """,
                remedy: "Use a reverse-DNS identifier such as `dev.example.myapp`."
            )
        }

        let root = dataRoot(for: appID, environment: environment)
        do {
            for subdirectory in ["Documents", "Cache", "tmp"] {
                try FileManager.default.createDirectory(
                    at: root.appendingPathComponent(subdirectory, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
        } catch {
            throw Diagnostic(
                code: "CID0424",
                summary: "could not prepare the application's sandbox data root",
                location: DiagnosticLocation(file: root.path),
                reason: "Cider isolates each application's on-disk data under this root: \(error.localizedDescription)",
                remedy: "Check that \(root.deletingLastPathComponent().path) is writable."
            )
        }
        return root
    }
}
