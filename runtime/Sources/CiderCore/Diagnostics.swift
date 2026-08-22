//  Structured diagnostics.
//
//  docs/02-product-requirements.md FR-007 requires diagnostics to be
//  machine-readable rather than prose. Every failure Cider reports to a
//  developer is built from this type, so the four questions a developer
//  actually has -- what failed, where, why, and how to fix it -- are fields
//  rather than a formatting convention someone might forget.

/// How severe a diagnostic is. Only `.error` is fatal to the operation that
/// produced it.
public enum DiagnosticSeverity: String, Sendable, CaseIterable {
    case note
    case warning
    case error
}

/// Where a diagnostic originated, when that is known.
public struct DiagnosticLocation: Equatable, Sendable {
    public var file: String
    public var line: Int?
    public var column: Int?

    public init(file: String, line: Int? = nil, column: Int? = nil) {
        self.file = file
        self.line = line
        self.column = column
    }

    public var description: String {
        var text = file
        if let line { text += ":\(line)" }
        if let line, let column { _ = line; text += ":\(column)" }
        return text
    }
}

/// A single actionable problem.
public struct Diagnostic: Error, Equatable, Sendable {
    /// A stable identifier such as `CID0001`. Stable codes let documentation,
    /// tests and search engines refer to a specific failure.
    public var code: String
    public var severity: DiagnosticSeverity

    /// One line, lower case, no trailing period: *what* failed.
    public var summary: String

    /// *Where* it failed, when a file is involved.
    public var location: DiagnosticLocation?

    /// *Why* it failed, in the developer's terms rather than the runtime's.
    public var reason: String?

    /// *How* to fix it. Concrete steps or a command, not "check your setup".
    public var remedy: String?

    public init(
        code: String,
        severity: DiagnosticSeverity = .error,
        summary: String,
        location: DiagnosticLocation? = nil,
        reason: String? = nil,
        remedy: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.summary = summary
        self.location = location
        self.reason = reason
        self.remedy = remedy
    }

    /// Renders the diagnostic the way the CLI prints it.
    public func formatted() -> String {
        var lines: [String] = []
        if let location {
            lines.append("\(severity.rawValue): \(summary) [\(code)]")
            lines.append("  --> \(location.description)")
        } else {
            lines.append("\(severity.rawValue): \(summary) [\(code)]")
        }
        if let reason {
            lines.append("")
            lines.append(reason)
        }
        if let remedy {
            lines.append("")
            for line in remedy.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append(String(line))
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// Thrown when an operation produced more than one problem worth reporting.
/// Reporting every manifest error at once beats making a developer rerun the
/// command to discover the next one.
public struct DiagnosticBundle: Error, Sendable {
    public var diagnostics: [Diagnostic]

    public init(_ diagnostics: [Diagnostic]) {
        self.diagnostics = diagnostics
    }

    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }

    public func formatted() -> String {
        diagnostics.map { $0.formatted() }.joined(separator: "\n\n")
    }
}
