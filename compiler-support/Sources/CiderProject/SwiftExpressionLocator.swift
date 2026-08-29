//  Finding the view expression a recorded source position points at.
//
//  A node's origin is an *anchor*, not a locator. `#column` for a chained call
//  resolves to the start of the whole expression, so `.font(size: 28)` and the
//  `Text(...)` it hangs off can report the same position. The editor therefore
//  finds the chain head at the anchor and then walks the chain by selector
//  name, which is also what the runtime does: the last `.font` in a chain is
//  the one whose value the node ends up carrying.
//
//  What lets a scanner stand in for a parser here is that the walk never has to
//  guess. A `{` is consumed as a trailing closure only after a call this file
//  knows takes one; anything else ends the chain rather than being interpreted.

import Foundation

import CiderCore

struct SwiftArgument {
    /// Nil for a positional argument.
    var label: String?

    /// The value's span, trimmed of surrounding whitespace.
    var valueStart: Int
    var valueEnd: Int

    /// The value's own tokens, comments included, so a caller can prove the
    /// value is a single literal before replacing it.
    var valueTokens: [SwiftToken]

    /// Where this argument begins, including its label. Used when inserting a
    /// new argument before it.
    var start: Int
}

struct SwiftArgumentList {
    var openParen: Int
    /// Offset of the `)` itself.
    var closeParen: Int
    var arguments: [SwiftArgument]
    var isSingleLine: Bool

    func argument(labelled label: String?) -> SwiftArgument? {
        arguments.first { $0.label == label }
    }

    func positional(_ index: Int) -> SwiftArgument? {
        let positionals = arguments.filter { $0.label == nil }
        return index < positionals.count ? positionals[index] : nil
    }
}

struct SwiftChainSegment {
    var name: String
    var dot: Int
    var arguments: SwiftArgumentList?
    var end: Int
}

struct LocatedChain {
    var head: String
    var headStart: Int
    var initializerArguments: SwiftArgumentList?
    var segments: [SwiftChainSegment]

    /// One past the last character of the whole postfix expression. This is the
    /// only insertion point that is always type-correct, because every editable
    /// modifier returns `Self`.
    var end: Int

    var indent: String
    var isSingleLine: Bool

    /// The last segment with this name. Last wins, matching the runtime: the
    /// modifiers copy-and-overwrite, so a second `.font` replaces the first.
    func lastSegment(named name: String) -> SwiftChainSegment? {
        segments.last { $0.name == name }
    }
}

enum SwiftExpressionLocator {

    /// Calls known to take a trailing closure, and the labels of any further
    /// ones. Everything not listed here ends a chain at its `{` rather than
    /// consuming it, which is what keeps a scanner honest about where an
    /// expression stops.
    static let trailingClosureCalls: [String: [String]] = [
        "VStack": [],
        "ScrollView": [],
        "List": [],
        "NavigationView": [],
        "Modal": ["presenting"],
        "Button": [],
    ]

    /// Finds the postfix chain whose head sits at `line`/`column`.
    ///
    /// The head identifier must actually be `expectedHead`. That check is the
    /// cheap guard that turns any surprise -- a stale snapshot, a different
    /// `#column` convention, an edited file -- into a refusal instead of a
    /// splice at the wrong offset.
    static func locate(
        head expectedHead: String,
        line: Int,
        column: Int,
        in source: SwiftSource
    ) throws -> LocatedChain {
        let code = source.code
        guard let headIndex = code.firstIndex(where: { token in
            token.line == line
                && (token.column == column || token.utf8Column == column)
                && token.kind == .identifier
                && source.text(of: token) == expectedHead
        }) else {
            throw Diagnostic(
                code: "CID0635",
                summary: "the recorded source location no longer names a \(expectedHead)",
                location: DiagnosticLocation(file: "<source>", line: line, column: column),
                reason: """
                    The editor expected a `\(expectedHead)` expression to start here. \
                    The file has changed since the running application was built.
                    """,
                remedy: "Let `cider dev` rebuild, then select the view again."
            )
        }

        var cursor = headIndex + 1
        let headToken = code[headIndex]
        var initializerArguments: SwiftArgumentList?
        var segments: [SwiftChainSegment] = []
        var end = headToken.end

        func text(_ token: SwiftToken) -> String { source.text(of: token) }

        // The initializer's own argument list, if it has one.
        if cursor < code.count, text(code[cursor]) == "(" {
            let list = try argumentList(from: cursor, code: code, source: source)
            initializerArguments = list.list
            cursor = list.nextIndex
            end = list.list.closeParen + 1
        }
        if let closures = try trailingClosures(for: expectedHead, from: cursor, code: code, source: source) {
            cursor = closures.nextIndex
            end = closures.end
        }

        // Then any number of `.member(...)` segments, which may sit on
        // following lines.
        while cursor + 1 < code.count, text(code[cursor]) == ".", code[cursor + 1].kind == .identifier {
            let dot = code[cursor].start
            let name = text(code[cursor + 1])
            var segmentEnd = code[cursor + 1].end
            var arguments: SwiftArgumentList?
            cursor += 2

            if cursor < code.count, text(code[cursor]) == "(" {
                let list = try argumentList(from: cursor, code: code, source: source)
                arguments = list.list
                cursor = list.nextIndex
                segmentEnd = list.list.closeParen + 1
            }
            segments.append(SwiftChainSegment(name: name, dot: dot, arguments: arguments, end: segmentEnd))
            end = segmentEnd
        }

        // Anything still attached that the walk did not understand means the
        // expression does not end where it looks like it does.
        if cursor < code.count, code[cursor].start == end, text(code[cursor]) == "{" {
            throw cannotDelimit(line: line)
        }

        let isSingleLine = !source.text(from: headToken.start, to: end).contains("\n")

        return LocatedChain(
            head: expectedHead,
            headStart: headToken.start,
            initializerArguments: initializerArguments,
            segments: segments,
            end: end,
            indent: source.indent(ofLineContaining: headToken.start),
            isSingleLine: isSingleLine
        )
    }

    // MARK: - Argument lists

    private struct LocatedArgumentList {
        var list: SwiftArgumentList
        var nextIndex: Int
    }

    /// Walks a balanced `( ... )` beginning at `code[open]`, splitting it into
    /// top-level arguments.
    private static func argumentList(
        from open: Int,
        code: [SwiftToken],
        source: SwiftSource
    ) throws -> LocatedArgumentList {
        let openToken = code[open]
        var depth = 0
        var index = open
        var closeIndex: Int?

        while index < code.count {
            let text = source.text(of: code[index])
            if text == "(" || text == "[" || text == "{" { depth += 1 }
            if text == ")" || text == "]" || text == "}" {
                depth -= 1
                if depth == 0 {
                    closeIndex = index
                    break
                }
            }
            index += 1
        }
        guard let close = closeIndex, source.text(of: code[close]) == ")" else {
            throw cannotDelimit(line: openToken.line)
        }

        var arguments: [SwiftArgument] = []
        var pieceStart = open + 1
        var pieceDepth = 0

        func finish(_ pieceEnd: Int) {
            guard pieceEnd > pieceStart else { return }
            let tokens = Array(code[pieceStart..<pieceEnd])
            guard let first = tokens.first else { return }

            var label: String?
            var valueTokens = tokens
            if tokens.count >= 2,
               first.kind == .identifier,
               source.text(of: tokens[1]) == ":" {
                label = source.text(of: first)
                valueTokens = Array(tokens.dropFirst(2))
            }
            guard let valueFirst = valueTokens.first, let valueLast = valueTokens.last else { return }
            arguments.append(
                SwiftArgument(
                    label: label,
                    valueStart: valueFirst.start,
                    valueEnd: valueLast.end,
                    valueTokens: valueTokens,
                    start: first.start
                )
            )
        }

        index = open + 1
        while index < close {
            let text = source.text(of: code[index])
            if text == "(" || text == "[" || text == "{" { pieceDepth += 1 }
            if text == ")" || text == "]" || text == "}" { pieceDepth -= 1 }
            if text == ",", pieceDepth == 0 {
                finish(index)
                pieceStart = index + 1
            }
            index += 1
        }
        finish(close)

        let list = SwiftArgumentList(
            openParen: openToken.start,
            closeParen: code[close].start,
            arguments: arguments,
            isSingleLine: !source.text(from: openToken.start, to: code[close].start).contains("\n")
        )
        return LocatedArgumentList(list: list, nextIndex: close + 1)
    }

    // MARK: - Trailing closures

    private struct LocatedClosures {
        var nextIndex: Int
        var end: Int
    }

    private static func trailingClosures(
        for head: String,
        from start: Int,
        code: [SwiftToken],
        source: SwiftSource
    ) throws -> LocatedClosures? {
        guard let extraLabels = trailingClosureCalls[head] else { return nil }
        guard start < code.count, source.text(of: code[start]) == "{" else { return nil }

        var cursor = try skipBraces(from: start, code: code, source: source)
        var end = code[cursor - 1].end

        for label in extraLabels {
            guard cursor + 1 < code.count,
                  code[cursor].kind == .identifier,
                  source.text(of: code[cursor]) == label,
                  source.text(of: code[cursor + 1]) == ":",
                  cursor + 2 < code.count,
                  source.text(of: code[cursor + 2]) == "{" else { break }
            cursor = try skipBraces(from: cursor + 2, code: code, source: source)
            end = code[cursor - 1].end
        }
        return LocatedClosures(nextIndex: cursor, end: end)
    }

    /// Returns the index just past the token that closes the brace at `open`.
    private static func skipBraces(from open: Int, code: [SwiftToken], source: SwiftSource) throws -> Int {
        var depth = 0
        var index = open
        while index < code.count {
            let text = source.text(of: code[index])
            if text == "{" || text == "(" || text == "[" { depth += 1 }
            if text == "}" || text == ")" || text == "]" {
                depth -= 1
                if depth == 0 { return index + 1 }
            }
            index += 1
        }
        throw cannotDelimit(line: code[open].line)
    }

    static func cannotDelimit(line: Int) -> Diagnostic {
        Diagnostic(
            code: "CID0639",
            summary: "could not delimit the expression safely",
            location: DiagnosticLocation(file: "<source>", line: line),
            reason: "The editor could not tell where this expression ends, so it will not write to it.",
            remedy: "Edit this value by hand, or simplify the expression so its extent is unambiguous."
        )
    }
}
