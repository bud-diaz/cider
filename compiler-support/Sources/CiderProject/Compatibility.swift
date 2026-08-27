//  Compatibility registry and source scanner.
//
//  Stage 4 starts with a deliberately small, explicit registry. It is not a
//  claim that Cider understands all Swift source; it is the place where known
//  supported, supported-with-differences and recognized-unsupported API surfaces
//  get recorded so developer tools can produce stable diagnostics.

import Foundation
import CiderCore

public enum CompatibilityLevel: String, Equatable, Sendable {
    case compatible = "A"
    case compatibleWithDifferences = "B"
    case developmentStub = "C"
    case recognizedUnsupported = "D"
}

public struct CompatibilityEntry: Equatable, Sendable {
    public var symbol: String
    public var domain: String
    public var level: CompatibilityLevel
    public var summary: String
    public var guidance: String

    public init(
        symbol: String,
        domain: String,
        level: CompatibilityLevel,
        summary: String,
        guidance: String
    ) {
        self.symbol = symbol
        self.domain = domain
        self.level = level
        self.summary = summary
        self.guidance = guidance
    }
}

public enum CompatibilityRegistry {
    public static let all: [CompatibilityEntry] = [
        CompatibilityEntry(
            symbol: "CiderApp",
            domain: "Application lifecycle",
            level: .compatible,
            summary: "Cider application entry point",
            guidance: "Use CiderApp for Stage 0-3 reference applications."
        ),
        CompatibilityEntry(
            symbol: "CiderView",
            domain: "Declarative UI",
            level: .compatible,
            summary: "Cider view protocol",
            guidance: "Use CiderView with the Stage 2 CiderUI primitives."
        ),
        CompatibilityEntry(
            symbol: "Text",
            domain: "Declarative UI",
            level: .compatible,
            summary: "single-line text view",
            guidance: "Cider Text supports one-line left-to-right text."
        ),
        CompatibilityEntry(
            symbol: "Button",
            domain: "Declarative UI",
            level: .compatible,
            summary: "button view",
            guidance: "Cider Button runs an action and redraws after state changes."
        ),
        CompatibilityEntry(
            symbol: "VStack",
            domain: "Declarative UI",
            level: .compatible,
            summary: "vertical stack view",
            guidance: "Use VStack for simple vertical layout."
        ),
        CompatibilityEntry(
            symbol: "Image",
            domain: "Declarative UI",
            level: .compatibleWithDifferences,
            summary: "raw-pixel image view",
            guidance: "Cider Image uses already-decoded ImageSource pixels; PNG/JPEG decoding is not implemented."
        ),
        CompatibilityEntry(
            symbol: "ScrollView",
            domain: "Declarative UI",
            level: .compatibleWithDifferences,
            summary: "explicit-size scroll view",
            guidance: "Cider ScrollView requires explicit width and height and has no automatic fill layout."
        ),
        CompatibilityEntry(
            symbol: "TextField",
            domain: "Declarative UI",
            level: .compatibleWithDifferences,
            summary: "ASCII text field",
            guidance: "Cider TextField edits printable ASCII via keysyms; composed/IME input is not implemented on X11."
        ),
        CompatibilityEntry(
            symbol: "List",
            domain: "Declarative UI",
            level: .compatibleWithDifferences,
            summary: "non-virtualized list",
            guidance: "Cider List preserves row order and scrolls, but has no virtualization or keyed identity."
        ),
        CompatibilityEntry(
            symbol: "NavigationView",
            domain: "Navigation",
            level: .compatibleWithDifferences,
            summary: "Cider navigation stack",
            guidance: "Use CiderState-backed NavigationView push/pop for the supported navigation subset."
        ),
        CompatibilityEntry(
            symbol: "Modal",
            domain: "Presentation",
            level: .compatibleWithDifferences,
            summary: "full-screen modal presenter",
            guidance: "Cider Modal presents full-screen only; partial sheets are not implemented."
        ),
        CompatibilityEntry(
            symbol: "CiderHTTP",
            domain: "HTTP networking",
            level: .compatibleWithDifferences,
            summary: "permission-checked blocking HTTP helper",
            guidance: "Use CiderHTTP for Stage 3 REST calls; async task integration is not implemented yet."
        ),
        CompatibilityEntry(
            symbol: "CiderPreferences",
            domain: "Preferences",
            level: .compatible,
            summary: "sandboxed string preferences",
            guidance: "Use CiderPreferences for small string values scoped to the app sandbox."
        ),
        CompatibilityEntry(
            symbol: "CiderStorage",
            domain: "Local files",
            level: .compatibleWithDifferences,
            summary: "sandboxed UTF-8 text storage",
            guidance: "Use CiderStorage for Documents, Cache and tmp text files."
        ),
        CompatibilityEntry(
            symbol: "SwiftUI",
            domain: "Declarative UI",
            level: .recognizedUnsupported,
            summary: "SwiftUI is not implemented by Cider",
            guidance: "Use CiderUI primitives for the supported Stage 2 surface."
        ),
        CompatibilityEntry(
            symbol: "View",
            domain: "Declarative UI",
            level: .recognizedUnsupported,
            summary: "SwiftUI View is not implemented by Cider",
            guidance: "Use CiderView and import CiderUI instead of SwiftUI."
        ),
        CompatibilityEntry(
            symbol: "UIKit",
            domain: "Declarative UI",
            level: .recognizedUnsupported,
            summary: "UIKit is not implemented by Cider",
            guidance: "Use CiderUI primitives for the supported Stage 2 surface."
        ),
        CompatibilityEntry(
            symbol: "URLSession",
            domain: "HTTP networking",
            level: .recognizedUnsupported,
            summary: "URLSession is not implemented by Cider",
            guidance: "Use CiderHTTP for the current permission-checked HTTP subset."
        ),
        CompatibilityEntry(
            symbol: "StoreKit",
            domain: "Purchases",
            level: .recognizedUnsupported,
            summary: "StoreKit purchases are unsupported",
            guidance: "Remove purchase flows or guard them out while running under Cider."
        ),
        CompatibilityEntry(
            symbol: "Product",
            domain: "Purchases",
            level: .recognizedUnsupported,
            summary: "StoreKit Product purchases are unsupported",
            guidance: "Cider does not simulate purchases; replace this path with a development stub owned by the app."
        ),
        CompatibilityEntry(
            symbol: "Camera",
            domain: "Device services",
            level: .recognizedUnsupported,
            summary: "camera access is unsupported",
            guidance: "Use an app-owned fixture or mock image source when running under Cider."
        ),
        CompatibilityEntry(
            symbol: "CoreData",
            domain: "Persistence",
            level: .recognizedUnsupported,
            summary: "Core Data is unsupported",
            guidance: "Use CiderStorage or an app-owned persistence abstraction for Cider runs."
        ),
    ]

    public static func entry(named symbol: String) -> CompatibilityEntry? {
        all.first { $0.symbol == symbol }
    }

    public static var unsupportedEntries: [CompatibilityEntry] {
        all.filter { $0.level == .recognizedUnsupported }
    }
}

public enum CompatibilityDocumentation {
    public static func markdown(entries: [CompatibilityEntry] = CompatibilityRegistry.all) -> String {
        var lines: [String] = [
            "# Cider Compatibility Registry",
            "",
            "Generated from `CompatibilityRegistry`.",
            "",
            "| Symbol | Domain | Level | Summary | Guidance |",
            "| --- | --- | --- | --- | --- |",
        ]

        for entry in entries.sorted(by: sortForDocumentation) {
            lines.append(
                "| `\(escape(entry.symbol))` | \(escape(entry.domain)) | \(entry.level.rawValue) | \(escape(entry.summary)) | \(escape(entry.guidance)) |"
            )
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func sortForDocumentation(_ lhs: CompatibilityEntry, _ rhs: CompatibilityEntry) -> Bool {
        if lhs.domain != rhs.domain { return lhs.domain < rhs.domain }
        if lhs.level.rawValue != rhs.level.rawValue { return lhs.level.rawValue < rhs.level.rawValue }
        return lhs.symbol < rhs.symbol
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

public enum CompatibilityScanner {
    public static func scan(project: Project) throws -> [Diagnostic] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: project.root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            throw Diagnostic(
                code: "CID0606",
                summary: "could not scan project sources",
                location: DiagnosticLocation(file: project.root.path),
                reason: "Cider could not enumerate the project directory.",
                remedy: "Check that the project directory is readable."
            )
        }

        var diagnostics: [Diagnostic] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            if values.isDirectory == true, ignoredDirectoryNames.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true, url.pathExtension == "swift" else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            diagnostics.append(contentsOf: scan(source, file: url.path))
        }
        return diagnostics.sorted { lhs, rhs in
            let left = lhs.location?.description ?? ""
            let right = rhs.location?.description ?? ""
            return left < right
        }
    }

    public static func scan(_ source: String, file: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        var reportedSymbols: Set<String> = []
        let entries = CompatibilityRegistry.unsupportedEntries

        for (index, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = scrubCommentsAndStringLiterals(String(rawLine))
            for entry in entries where !reportedSymbols.contains(entry.symbol) && containsIdentifier(entry.symbol, in: line) {
                diagnostics.append(diagnostic(for: entry, file: file, line: index + 1))
                reportedSymbols.insert(entry.symbol)
            }
        }

        return diagnostics
    }

    private static let ignoredDirectoryNames: Set<String> = [
        ".build",
        ".git",
        ".cider",
        "DerivedData",
    ]

    private static func diagnostic(for entry: CompatibilityEntry, file: String, line: Int) -> Diagnostic {
        Diagnostic(
            code: "CID0605",
            severity: .warning,
            summary: "`\(entry.symbol)` is recognized but unsupported by Cider",
            location: DiagnosticLocation(file: file, line: line),
            reason: "\(entry.summary). Domain: \(entry.domain). Compatibility level: \(entry.level.rawValue).",
            remedy: entry.guidance
        )
    }

    private static func containsIdentifier(_ identifier: String, in line: String) -> Bool {
        var searchStart = line.startIndex
        while let range = line.range(of: identifier, range: searchStart..<line.endIndex) {
            let beforeOK = range.lowerBound == line.startIndex || !isIdentifierCharacter(line[line.index(before: range.lowerBound)])
            let afterOK = range.upperBound == line.endIndex || !isIdentifierCharacter(line[range.upperBound])
            if beforeOK && afterOK { return true }
            searchStart = range.upperBound
        }
        return false
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber
    }

    private static func scrubCommentsAndStringLiterals(_ line: String) -> String {
        var result = ""
        var iterator = line.makeIterator()
        var escaped = false
        var inString = false
        var previous: Character?

        while let character = iterator.next() {
            if inString {
                if escaped {
                    escaped = false
                    result.append(" ")
                    previous = character
                    continue
                }
                if character == "\\" {
                    escaped = true
                    result.append(" ")
                    previous = character
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                result.append(" ")
                previous = character
                continue
            }

            if previous == "/", character == "/" {
                _ = result.popLast()
                result.append(" ")
                break
            }

            if character == "\"" {
                inString = true
                result.append(" ")
            } else {
                result.append(character)
            }
            previous = character
        }

        return result
    }
}
