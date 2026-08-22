//  `cider doctor`

import CiderCore
import CiderDeviceProfiles
import CiderProject

enum DoctorCommand {

    /// Returns the process exit code.
    static func run(_ command: ParsedCommand) -> Int32 {
        StandardStreams.out("")
        StandardStreams.out("Cider Doctor")
        StandardStreams.out("")

        let checks = EnvironmentProbe.runAll()
        let width = checks.map(\.label.count).max() ?? 0

        var failures: [Diagnostic] = []
        var warnings = 0

        for check in checks {
            let label = check.label.padding(toLength: width, withPad: " ", startingAt: 0)
            switch check.status {
            case .ok(let detail):
                StandardStreams.out("  \(label)  \(Symbols.ok)  \(detail)")
            case .warning(let detail):
                warnings += 1
                StandardStreams.out("  \(label)  \(Symbols.warning)  \(detail)")
            case .failed(let diagnostic):
                failures.append(diagnostic)
                StandardStreams.out("  \(label)  \(Symbols.failed)  \(diagnostic.summary)")
            }
        }

        StandardStreams.out("")
        StandardStreams.out("  Device profiles: \(DeviceProfileRegistry.all.map(\.name).sorted().joined(separator: ", "))")
        StandardStreams.out("")

        guard failures.isEmpty else {
            for diagnostic in failures {
                StandardStreams.error(diagnostic.formatted())
                StandardStreams.error("")
            }
            let count = failures.count == 1 ? "1 problem" : "\(failures.count) problems"
            StandardStreams.out("Cider is not ready: \(count) must be fixed.")
            StandardStreams.out("")
            return 1
        }

        if warnings > 0 {
            let count = warnings == 1 ? "1 warning" : "\(warnings) warnings"
            StandardStreams.out("Cider can build projects. \(count) may prevent `cider run`.")
        } else {
            StandardStreams.out("Cider is ready.")
        }
        StandardStreams.out("")
        return 0
    }
}

enum Symbols {
    // Plain ASCII alternatives are used when the terminal cannot be trusted to
    // render marks; for now the marks are unconditional and legible in every
    // UTF-8 terminal Cider targets.
    static let ok = "\u{2713}"
    static let warning = "!"
    static let failed = "\u{2717}"
}
