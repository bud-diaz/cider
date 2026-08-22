//  Argument parsing.
//
//  Hand-rolled rather than pulled from a package. Cider has three commands and
//  four options; a dependency would be more code than it replaces, and
//  docs/07-legal-distribution-boundaries.md section 8 asks that every dependency
//  carry a recorded justification. This one could not earn its entry.

import CiderCore

struct ParsedCommand {
    var name: String
    var options: [String: String]
    var flags: Set<String>
    var positional: [String]

    func option(_ name: String) -> String? { options[name] }
    func has(_ flag: String) -> Bool { flags.contains(flag) }
}

enum CommandLineParser {
    /// Options that take a value.
    static let valueOptions: Set<String> = ["--path", "--device", "--log-level", "--configuration"]

    /// Options that stand alone.
    static let booleanFlags: Set<String> = ["--inspect", "--help", "-h", "--version", "--no-build"]

    static func parse(_ arguments: [String]) throws -> ParsedCommand {
        var options: [String: String] = [:]
        var flags: Set<String> = []
        var positional: [String] = []

        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]

            if valueOptions.contains(argument) {
                let next = arguments.index(after: index)
                guard next < arguments.endIndex else {
                    throw Diagnostic(
                        code: "CID0510",
                        summary: "`\(argument)` needs a value",
                        reason: "The option was the last thing on the command line.",
                        remedy: "Write `\(argument) <value>`."
                    )
                }
                options[argument] = arguments[next]
                index = arguments.index(after: next)
                continue
            }

            if let separator = argument.firstIndex(of: "="),
               valueOptions.contains(String(argument[argument.startIndex..<separator])) {
                let name = String(argument[argument.startIndex..<separator])
                options[name] = String(argument[argument.index(after: separator)...])
                index = arguments.index(after: index)
                continue
            }

            if booleanFlags.contains(argument) {
                flags.insert(argument)
                index = arguments.index(after: index)
                continue
            }

            if argument.hasPrefix("-") {
                throw Diagnostic(
                    code: "CID0511",
                    summary: "unknown option `\(argument)`",
                    reason: "Cider does not recognise that option.",
                    remedy: "Run `cider --help` to see the supported options."
                )
            }

            positional.append(argument)
            index = arguments.index(after: index)
        }

        let name = positional.first ?? ""
        return ParsedCommand(
            name: name,
            options: options,
            flags: flags,
            positional: Array(positional.dropFirst())
        )
    }
}
