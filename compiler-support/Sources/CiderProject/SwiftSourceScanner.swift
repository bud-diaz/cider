//  A token scanner for Swift source, for the developer console's editor.
//
//  Not a parser. The editor never needs to understand a program -- it needs to
//  find one expression, prove one argument is a single literal, and splice. A
//  scanner that knows where comments and string literals begin and end is
//  enough for that, and a parser would mean a swift-syntax dependency, which
//  CONTRIBUTING.md rightly makes an ADR-level decision on its own.
//
//  `CompatibilityScanner.scrubCommentsAndStringLiterals` is not reusable here:
//  it works a line at a time and handles neither block comments, raw strings,
//  multiline strings, nor interpolation. Getting any of those wrong means
//  mistaking part of a string for code and rewriting the wrong bytes, so this
//  handles all four and refuses when it cannot finish.
//
//  Positions are tracked in both characters and UTF-8 bytes. `#column` is
//  1-based, and matching it exactly matters -- but which unit the compiler
//  counts is not something this can verify without a toolchain, so a caller may
//  match on either and be right under both readings.

import Foundation

import CiderCore

struct SwiftToken: Equatable {
    enum Kind: Equatable {
        case identifier
        case number
        /// `interpolated` is what makes a string unrewritable: its value is
        /// computed at run time, so there is no literal to replace.
        case string(interpolated: Bool, raw: Bool, multiline: Bool)
        case comment
        /// One character of `(){}[],:;.` -- the structure the locator walks.
        case punctuation
        case operatorRun
    }

    var kind: Kind

    /// Offsets into the scanned character array; `end` is exclusive.
    var start: Int
    var end: Int

    /// 1-based line, and 1-based column in characters and in UTF-8 bytes.
    var line: Int
    var column: Int
    var utf8Column: Int
}

/// A scanned file: the characters, and the tokens over them.
///
/// Characters rather than `String.Index` throughout. Index arithmetic across a
/// splice is the kind of thing that is subtly wrong for months; integer offsets
/// into an array are not.
struct SwiftSource {
    let characters: [Character]
    let tokens: [SwiftToken]

    init(_ text: String) throws {
        characters = Array(text)
        tokens = try SwiftSourceScanner.scan(characters)
    }

    func text(of token: SwiftToken) -> String {
        String(characters[token.start..<token.end])
    }

    func text(from start: Int, to end: Int) -> String {
        guard start < end, start >= 0, end <= characters.count else { return "" }
        return String(characters[start..<end])
    }

    /// Tokens that are not comments, which is what the locator walks. Comments
    /// are scanned rather than dropped so a caller can still refuse to touch a
    /// span that contains one.
    var code: [SwiftToken] {
        tokens.filter { $0.kind != .comment }
    }

    /// The leading whitespace of the line `offset` falls on, verbatim, so an
    /// inserted line can match the indentation around it including tabs.
    func indent(ofLineContaining offset: Int) -> String {
        guard !characters.isEmpty else { return "" }
        var start = min(max(0, offset), characters.count - 1)
        while start > 0 && characters[start - 1] != "\n" { start -= 1 }
        var end = start
        while end < characters.count, characters[end] == " " || characters[end] == "\t" { end += 1 }
        return String(characters[start..<end])
    }

    /// The 1-based column `offset` sits at, in characters.
    func column(at offset: Int) -> Int {
        var start = offset
        while start > 0 && characters[start - 1] != "\n" { start -= 1 }
        return offset - start + 1
    }
}

enum SwiftSourceScanner {

    static func scan(_ characters: [Character]) throws -> [SwiftToken] {
        var tokens: [SwiftToken] = []
        var index = 0
        var line = 1
        var column = 1
        var utf8Column = 1

        func advance(to target: Int) {
            var cursor = index
            while cursor < target && cursor < characters.count {
                if characters[cursor] == "\n" {
                    line += 1
                    column = 1
                    utf8Column = 1
                } else {
                    column += 1
                    utf8Column += String(characters[cursor]).utf8.count
                }
                cursor += 1
            }
            index = target
        }

        func append(_ kind: SwiftToken.Kind, to end: Int) {
            tokens.append(
                SwiftToken(kind: kind, start: index, end: end, line: line, column: column, utf8Column: utf8Column)
            )
            advance(to: end)
        }

        while index < characters.count {
            let character = characters[index]

            if character.isWhitespace {
                advance(to: index + 1)
                continue
            }

            if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                var end = index + 2
                while end < characters.count, characters[end] != "\n" { end += 1 }
                append(.comment, to: end)
                continue
            }

            if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                // Swift nests block comments, so a depth counter is required --
                // stopping at the first `*/` would end the comment early and
                // treat its tail as code.
                var end = index + 2
                var depth = 1
                while end < characters.count, depth > 0 {
                    if end + 1 < characters.count, characters[end] == "/", characters[end + 1] == "*" {
                        depth += 1
                        end += 2
                    } else if end + 1 < characters.count, characters[end] == "*", characters[end + 1] == "/" {
                        depth -= 1
                        end += 2
                    } else {
                        end += 1
                    }
                }
                guard depth == 0 else { throw unterminated("block comment", line: line) }
                append(.comment, to: end)
                continue
            }

            if character == "#" || character == "\"" {
                if let literal = try scanStringLiteral(characters, from: index, line: line) {
                    append(literal.kind, to: literal.end)
                    continue
                }
            }

            if character.isLetter || character == "_" {
                var end = index
                while end < characters.count, characters[end].isLetter || characters[end].isNumber || characters[end] == "_" {
                    end += 1
                }
                append(.identifier, to: end)
                continue
            }

            if character.isNumber {
                var end = index
                while end < characters.count, isNumberBody(characters[end]) { end += 1 }
                // A trailing '.' belongs to member access, not to the number:
                // `1.foo` is not a float. Only keep it when a digit follows.
                if end > index, characters[end - 1] == "." { end -= 1 }
                append(.number, to: end)
                continue
            }

            if "(){}[],:;.".contains(character) {
                append(.punctuation, to: index + 1)
                continue
            }

            var end = index
            while end < characters.count, isOperatorCharacter(characters[end]) { end += 1 }
            append(.operatorRun, to: max(end, index + 1))
        }

        return tokens
    }

    // MARK: - String literals

    private struct ScannedString {
        var kind: SwiftToken.Kind
        var end: Int
    }

    /// Scans a (possibly raw, possibly multiline) string literal starting at
    /// `start`, or returns nil if what is there is not one.
    ///
    /// The delimiter level is the run of `#` before the quote, and it changes
    /// what counts as an escape and what counts as the end: inside `#"..."#`,
    /// `\"` is two ordinary characters and only `"#` terminates.
    private static func scanStringLiteral(_ characters: [Character], from start: Int, line: Int) throws -> ScannedString? {
        var index = start
        var hashes = 0
        while index < characters.count, characters[index] == "#" {
            hashes += 1
            index += 1
        }
        guard index < characters.count, characters[index] == "\"" else {
            // A `#` run that is not a raw string is something else entirely --
            // `#if`, `#line`, `#filePath`. Let the caller scan it as an
            // operator and move on.
            return nil
        }

        let multiline = index + 2 < characters.count
            && characters[index + 1] == "\""
            && characters[index + 2] == "\""
        let quoteCount = multiline ? 3 : 1
        index += quoteCount

        var interpolated = false

        func matchesTerminator(at position: Int) -> Bool {
            guard position + quoteCount + hashes <= characters.count else { return false }
            for offset in 0..<quoteCount where characters[position + offset] != "\"" { return false }
            for offset in 0..<hashes where characters[position + quoteCount + offset] != "#" { return false }
            return true
        }

        func matchesEscape(at position: Int) -> Bool {
            guard characters[position] == "\\" else { return false }
            guard position + hashes < characters.count else { return false }
            for offset in 0..<hashes where characters[position + 1 + offset] != "#" { return false }
            return true
        }

        while index < characters.count {
            if matchesTerminator(at: index) {
                let end = index + quoteCount + hashes
                return ScannedString(
                    kind: .string(interpolated: interpolated, raw: hashes > 0, multiline: multiline),
                    end: end
                )
            }
            if matchesEscape(at: index) {
                let afterEscape = index + 1 + hashes
                if afterEscape < characters.count, characters[afterEscape] == "(" {
                    interpolated = true
                    index = try skipInterpolation(characters, from: afterEscape, line: line)
                    continue
                }
                index = afterEscape + 1
                continue
            }
            if !multiline && characters[index] == "\n" {
                throw unterminated("string literal", line: line)
            }
            index += 1
        }

        throw unterminated("string literal", line: line)
    }

    /// Skips `( ... )` inside a string interpolation, which can itself contain
    /// strings containing parentheses.
    private static func skipInterpolation(_ characters: [Character], from open: Int, line: Int) throws -> Int {
        var index = open + 1
        var depth = 1
        while index < characters.count {
            let character = characters[index]
            if character == "\"" || character == "#" {
                if let nested = try scanStringLiteral(characters, from: index, line: line) {
                    index = nested.end
                    continue
                }
            }
            if character == "(" { depth += 1 }
            if character == ")" {
                depth -= 1
                if depth == 0 { return index + 1 }
            }
            index += 1
        }
        throw unterminated("string interpolation", line: line)
    }

    // MARK: - Character classes

    private static func isNumberBody(_ character: Character) -> Bool {
        character.isHexDigit
            || character == "_"
            || character == "."
            || character == "x"
            || character == "o"
            || character == "b"
            || character == "X"
            || character == "O"
            || character == "B"
    }

    private static func isOperatorCharacter(_ character: Character) -> Bool {
        "/=-+!*%<>&|^~?".contains(character)
    }

    private static func unterminated(_ what: String, line: Int) -> Diagnostic {
        Diagnostic(
            code: "CID0639",
            summary: "could not read the source safely",
            location: DiagnosticLocation(file: "<source>", line: line),
            reason: "An unterminated \(what) starts here, so the editor cannot tell code from text.",
            remedy: "Fix the source so it compiles, then try the edit again."
        )
    }
}
