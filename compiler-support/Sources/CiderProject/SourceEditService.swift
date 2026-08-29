//  The console's side of a property edit.
//
//  Everything unsafe about writing to a developer's files is decided here, in
//  front of `SwiftSourceEditor`: whether the path is one this project owns,
//  whether an earlier edit is still in flight, and whether the change is worth
//  recording. The rewriter itself is pure and knows nothing about files.
//
//  The request is expressed entirely in source-position terms. No `NodeID`
//  crosses the wire: a structural path can be re-keyed by a state change
//  between the snapshot and the click, and a file position cannot.

import Foundation

import CiderCore

/// What the dashboard asks for when a property is changed.
public struct SourceEditRequest: Codable, Sendable {
    /// Absolute, as `#filePath` recorded it. Validated before it is opened.
    public var file: String
    public var line: Int
    public var column: Int

    /// The view the position is expected to name -- `Text`, `Button`, ... The
    /// editor checks the source agrees before it writes anything.
    public var head: String

    public var property: String

    /// Already a Swift literal: `36`, `"Hello"`, `.bold`, `Color(hex: 0x00FF00)`.
    public var value: String

    /// What the panel displayed, for the compare-and-swap.
    public var expectedCurrentValue: String?

    /// The other arguments of the same call, for when it has to be written
    /// whole. Keyed by argument label.
    public var siblingValues: [String: String]?
}

public struct SourceEditResult: Codable, Sendable {
    public var ok: Bool
    public var file: String
    public var line: Int
}

/// Applies a `SourceEditRequest` to a project's files.
public final class SourceEditService: @unchecked Sendable {
    private let project: Project
    private let events: DevEventLog

    /// Set when an edit has been written and the rebuild it triggers has not
    /// been seen yet. A second edit while this is set would be aimed at line
    /// numbers the first one may already have moved.
    private var awaitingRebuild = false

    public init(project: Project, events: DevEventLog) {
        self.project = project
        self.events = events
    }

    /// Called when a fresh snapshot lands, meaning the application has
    /// relaunched and the panel's positions are current again.
    public func rebuildObserved() {
        awaitingRebuild = false
    }

    public var isAwaitingRebuild: Bool { awaitingRebuild }

    public func apply(_ request: SourceEditRequest) throws -> SourceEditResult {
        guard !awaitingRebuild else {
            throw Diagnostic(
                code: "CID0642",
                summary: "an edit is already waiting for a rebuild",
                reason: """
                    The previous edit has been written but the application has not \
                    relaunched yet, so the positions on screen may not match the file.
                    """,
                remedy: "Wait for the console to return to `running`, then edit again."
            )
        }

        let url = try resolveEditableSource(request.file)
        let original = try String(contentsOf: url, encoding: .utf8)

        let edit = SwiftSourceEditor.Edit(
            head: request.head,
            line: request.line,
            column: request.column,
            property: request.property,
            newValue: request.value,
            expectedCurrentValue: request.expectedCurrentValue,
            siblingValues: request.siblingValues ?? [:]
        )
        let updated = try SwiftSourceEditor.apply(edit, to: original)

        guard updated != original else {
            // Nothing to write, and writing anyway would touch the file's
            // timestamp and trigger a rebuild for no reason.
            return SourceEditResult(ok: true, file: url.lastPathComponent, line: request.line)
        }

        try updated.write(to: url, atomically: true, encoding: .utf8)
        awaitingRebuild = true

        // Every applied edit is recorded with what it replaced, so an unwanted
        // one is recoverable from the event stream rather than only from
        // whatever the developer remembers.
        events.append(
            kind: "edit",
            message: """
                \(url.lastPathComponent):\(request.line) \(request.property) \
                \(request.expectedCurrentValue ?? "(unwritten)") -> \(request.value)
                """
        )
        return SourceEditResult(ok: true, file: url.lastPathComponent, line: request.line)
    }

    /// Where the console is willing to write.
    ///
    /// The path arrives from the snapshot, which the *application* wrote, and
    /// is then relayed by the browser. It is untrusted at both hops and gets
    /// the full check regardless of which one it came from. This extends the
    /// escape guard `SandboxBrowser.resolve` already establishes with a symlink
    /// step, because a source tree may legitimately contain symlinks and a
    /// hostile one could point out of the project.
    func resolveEditableSource(_ recorded: String) throws -> URL {
        func refuse(_ reason: String) -> Diagnostic {
            Diagnostic(
                code: "CID0632",
                summary: "that file is not one this project may edit",
                location: DiagnosticLocation(file: recorded),
                reason: reason,
                remedy: "Only Swift sources inside the project can be edited from the console."
            )
        }

        guard !recorded.isEmpty else { throw refuse("No path was recorded for this view.") }

        let resolved = URL(fileURLWithPath: recorded).standardizedFileURL.resolvingSymlinksInPath()
        let root = project.root.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.path.hasPrefix(root.path + "/") else {
            throw refuse("\(resolved.path) is outside \(root.path).")
        }
        guard resolved.pathExtension == "swift" else {
            throw refuse("Only Swift sources are edited.")
        }
        let components = resolved.pathComponents
        for excluded in [".build", ".cider", ".git"] where components.contains(excluded) {
            throw refuse("\(excluded) holds generated or version-control files, not sources.")
        }
        // An edit the watcher would not notice would never rebuild, which looks
        // exactly like an edit that did nothing.
        guard ProjectFileWatcher.isWatched(resolved) else {
            throw refuse("`cider dev` does not watch this file, so an edit to it would never rebuild.")
        }
        guard FileManager.default.isWritableFile(atPath: resolved.path) else {
            throw Diagnostic(
                code: "CID0633",
                summary: "that file is not writable",
                location: DiagnosticLocation(file: resolved.path),
                reason: "The console can read this source but not write to it.",
                remedy: "Check the file's permissions."
            )
        }
        return resolved
    }
}
