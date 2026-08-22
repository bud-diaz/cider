//  A parser for the small YAML subset Cider manifests use.
//
//  Cider deliberately does not take a YAML dependency. A manifest is a handful
//  of nested key/value pairs, and a full YAML implementation brings anchors,
//  aliases, multiple documents, tags, flow collections and a type-coercion table
//  that has caused real bugs in other tools -- none of which a manifest needs,
//  all of which would become part of Cider's compatibility surface the moment a
//  developer used them.
//
//  What is supported:
//
//      key:              # a mapping
//        child: value    # nested by indentation, spaces only
//        quoted: "0.1"   # double or single quotes
//      # comments to end of line
//
//  What is not supported is *rejected with a line number*, never guessed at.
//  See docs/adr/0004-project-manifest-format.md.

import CiderCore

/// One parsed line of a manifest, with enough context to point at it later.
public struct YAMLNode {
    public var key: String

    /// The scalar on the same line, if there was one.
    public var scalar: String?

    public var children: [YAMLNode]

    /// 1-based line in the source file.
    public var line: Int

    public init(key: String, scalar: String?, children: [YAMLNode], line: Int) {
        self.key = key
        self.scalar = scalar
        self.children = children
        self.line = line
    }

    public func child(_ name: String) -> YAMLNode? {
        children.first { $0.key == name }
    }
}

public enum YAMLSubset {

    public static func parse(_ text: String, file: String) throws -> [YAMLNode] {
        var entries: [(indent: Int, key: String, scalar: String?, line: Int)] = []

        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = index + 1
            let stripped = stripComment(String(rawLine))
            if stripped.trimmingASCIIWhitespace().isEmpty { continue }

            if stripped.contains("\t") {
                throw Diagnostic(
                    code: "CID0401",
                    summary: "tab used for indentation",
                    location: DiagnosticLocation(file: file, line: lineNumber),
                    reason: "Cider manifests are indented with spaces. A tab makes nesting ambiguous.",
                    remedy: "Replace the tab with two spaces per level."
                )
            }

            let indent = stripped.prefix { $0 == " " }.count
            if indent % 2 != 0 {
                throw Diagnostic(
                    code: "CID0402",
                    summary: "indentation of \(indent) spaces is not a multiple of two",
                    location: DiagnosticLocation(file: file, line: lineNumber),
                    reason: "Cider manifests nest two spaces per level.",
                    remedy: "Indent this line by an even number of spaces."
                )
            }

            let content = String(stripped.dropFirst(indent))
            if content.hasPrefix("-") {
                throw Diagnostic(
                    code: "CID0403",
                    summary: "sequences are not supported in Cider manifests",
                    location: DiagnosticLocation(file: file, line: lineNumber),
                    reason: "No field in the manifest schema takes a list.",
                    remedy: "Remove the list, or check the field name against docs/adr/0004-project-manifest-format.md."
                )
            }

            guard let separator = content.firstIndex(of: ":") else {
                throw Diagnostic(
                    code: "CID0404",
                    summary: "expected a `key: value` pair",
                    location: DiagnosticLocation(file: file, line: lineNumber),
                    reason: "The line `\(content)` has no colon, so Cider cannot tell what it declares.",
                    remedy: "Write the line as `key: value`, or `key:` followed by an indented block."
                )
            }

            let key = String(content[content.startIndex..<separator]).trimmingASCIIWhitespace()
            guard !key.isEmpty else {
                throw Diagnostic(
                    code: "CID0405",
                    summary: "empty key",
                    location: DiagnosticLocation(file: file, line: lineNumber),
                    reason: "A manifest entry must have a name before the colon.",
                    remedy: "Give the entry a name, or delete the line."
                )
            }

            let rest = String(content[content.index(after: separator)...]).trimmingASCIIWhitespace()
            entries.append((indent, key, rest.isEmpty ? nil : unquote(rest), lineNumber))
        }

        var index = 0
        return try build(&index, entries: entries, indent: 0, file: file)
    }

    /// Recursively collects entries at `indent` and deeper.
    private static func build(
        _ index: inout Int,
        entries: [(indent: Int, key: String, scalar: String?, line: Int)],
        indent: Int,
        file: String
    ) throws -> [YAMLNode] {
        var nodes: [YAMLNode] = []

        while index < entries.count {
            let entry = entries[index]
            if entry.indent < indent { break }

            if entry.indent > indent {
                throw Diagnostic(
                    code: "CID0406",
                    summary: "unexpected indentation",
                    location: DiagnosticLocation(file: file, line: entry.line),
                    reason: """
                        `\(entry.key)` is indented \(entry.indent) spaces, but the block it is in \
                        starts at \(indent).
                        """,
                    remedy: "Align this line with its siblings."
                )
            }

            index += 1
            var children: [YAMLNode] = []
            if index < entries.count, entries[index].indent > indent {
                children = try build(&index, entries: entries, indent: entries[index].indent, file: file)
            }

            if entry.scalar != nil && !children.isEmpty {
                throw Diagnostic(
                    code: "CID0407",
                    summary: "`\(entry.key)` has both a value and nested entries",
                    location: DiagnosticLocation(file: file, line: entry.line),
                    reason: "A manifest entry is either a value or a block, not both.",
                    remedy: "Remove the value after the colon, or remove the indented block."
                )
            }

            nodes.append(
                YAMLNode(key: entry.key, scalar: entry.scalar, children: children, line: entry.line)
            )
        }

        return nodes
    }

    /// Removes a trailing comment, respecting quotes so a `#` inside a string
    /// survives.
    private static func stripComment(_ line: String) -> String {
        var result = ""
        var quote: Character?

        for character in line {
            if let open = quote {
                result.append(character)
                if character == open { quote = nil }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                result.append(character)
                continue
            }
            if character == "#" { break }
            result.append(character)
        }
        return result
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, let last = value.last else {
            return value
        }
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
