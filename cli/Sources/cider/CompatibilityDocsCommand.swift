//  `cider compatibility-docs`
//
//  Generates markdown from the compatibility registry. Keeping this as a command
//  means published docs can be refreshed from the same data the scanner uses,
//  rather than drifting into a hand-maintained second source of truth.

import CiderCore
import CiderProject

enum CompatibilityDocsCommand {
    static func run(_ command: ParsedCommand) throws -> Int32 {
        let markdown = CompatibilityDocumentation.markdown()
        if let outputPath = command.option("--output") {
            do {
                try markdown.write(toFile: outputPath, atomically: true, encoding: .utf8)
            } catch {
                throw Diagnostic(
                    code: "CID0607",
                    summary: "could not write compatibility documentation",
                    location: DiagnosticLocation(file: outputPath),
                    reason: "Cider could not write the generated registry markdown: \(error.localizedDescription)",
                    remedy: "Check that the output directory exists and is writable."
                )
            }
        } else {
            StandardStreams.out(markdown)
        }
        return 0
    }
}
