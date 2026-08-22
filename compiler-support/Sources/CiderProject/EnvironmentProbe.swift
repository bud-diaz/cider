//  Everything `cider doctor` inspects.
//
//  The rule for this file is that a check either verifies something or says it
//  could not. Nothing reports success on the basis of a plausible assumption:
//  a doctor that clears a broken machine is worse than no doctor, because the
//  developer then goes looking for the fault somewhere else.
//
//  Note what is checked and what is not. The CLI does not link the Linux
//  backend, so it cannot open an X connection to prove the display works --
//  and it must not, because a CLI that links libX11 cannot start on a machine
//  where libX11 is the thing that is missing. So the checks here are the ones a
//  build system can make: development packages, shared libraries, a display
//  address. The live connection is verified by the runtime, at `cider run`.

import Foundation

import CiderCore

public enum CheckStatus: Sendable, Equatable {
    case ok(String)
    case warning(String)
    case failed(Diagnostic)

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    public var isWarning: Bool {
        if case .warning = self { return true }
        return false
    }
}

public struct Check: Sendable {
    public var label: String
    public var status: CheckStatus

    public init(label: String, status: CheckStatus) {
        self.label = label
        self.status = status
    }
}

public enum EnvironmentProbe {

    /// The lowest Swift version Cider is known to build with.
    ///
    /// Cider's own sources use Swift 6 language mode, so this is a hard
    /// requirement rather than a preference.
    public static let minimumSwift = (major: 6, minor: 0)

    /// Runs every check, in the order `cider doctor` prints them.
    public static func runAll() -> [Check] {
        [
            hostCheck(),
            architectureCheck(),
            swiftCheck(),
            cCompilerCheck(),
            pkgConfigCheck(),
            graphicsLibrariesCheck(),
            displayCheck(),
        ]
    }

    // MARK: - Individual checks

    static func hostCheck() -> Check {
        let name = osReleaseField("PRETTY_NAME") ?? osReleaseField("NAME") ?? "unknown"
        #if os(Linux)
        return Check(label: "Host", status: .ok(name))
        #else
        return Check(
            label: "Host",
            status: .failed(
                Diagnostic(
                    code: "CID0500",
                    summary: "unsupported host operating system",
                    reason: "Cider's only backend today targets Linux. This host reports \(name).",
                    remedy: "Run Cider on Linux. Windows support is planned; see docs/05-implementation-roadmap.md."
                )
            )
        )
        #endif
    }

    static func architectureCheck() -> Check {
        #if arch(x86_64)
        return Check(label: "Architecture", status: .ok("x86_64"))
        #elseif arch(arm64)
        return Check(label: "Architecture", status: .ok("arm64"))
        #else
        return Check(
            label: "Architecture",
            status: .warning("unrecognised; Cider is tested on x86_64 and arm64")
        )
        #endif
    }

    static func swiftCheck() -> Check {
        guard let version = SwiftToolchain.swiftVersion() else {
            return Check(
                label: "Swift",
                status: .failed(
                    Diagnostic(
                        code: "CID0501",
                        summary: "Swift compiler not found",
                        reason: """
                            Cider builds applications with the Swift toolchain and requires \
                            Swift \(minimumSwift.major).\(minimumSwift.minor) or later.
                            """,
                        remedy: """
                            Install Swift from https://www.swift.org/install/ and verify:

                                swift --version
                            """
                    )
                )
            )
        }

        guard let parsed = SwiftToolchain.parseSwiftVersion(version) else {
            return Check(label: "Swift", status: .warning("\(version) (version could not be parsed)"))
        }

        let short = "\(parsed.major).\(parsed.minor)"
        if parsed.major < minimumSwift.major
            || (parsed.major == minimumSwift.major && parsed.minor < minimumSwift.minor) {
            return Check(
                label: "Swift",
                status: .failed(
                    Diagnostic(
                        code: "CID0502",
                        summary: "Swift \(short) is too old",
                        reason: """
                            Cider's sources use the Swift 6 language mode and need Swift \
                            \(minimumSwift.major).\(minimumSwift.minor) or later.
                            """,
                        remedy: """
                            Upgrade the toolchain from https://www.swift.org/install/ and verify:

                                swift --version
                            """
                    )
                )
            )
        }

        return Check(label: "Swift", status: .ok(short))
    }

    static func cCompilerCheck() -> Check {
        // Cider's host backends are partly C, so a C compiler is required even
        // for a project that contains none.
        for compiler in ["cc", "clang", "gcc"] {
            if which(compiler) != nil {
                return Check(label: "C compiler", status: .ok(compiler))
            }
        }
        return Check(
            label: "C compiler",
            status: .failed(
                Diagnostic(
                    code: "CID0503",
                    summary: "no C compiler found",
                    reason: "Cider's Linux backend includes C sources that need a C compiler to build.",
                    remedy: """
                        Install one:

                            sudo apt install build-essential
                        """
                )
            )
        )
    }

    static func pkgConfigCheck() -> Check {
        guard let path = which("pkg-config") else {
            return Check(
                label: "pkg-config",
                status: .failed(
                    Diagnostic(
                        code: "CID0504",
                        summary: "pkg-config not found",
                        reason: """
                            Cider's Linux backend finds X11 and FreeType through pkg-config. \
                            Without it, SwiftPM cannot work out the compile and link flags.
                            """,
                        remedy: """
                            Install it:

                                sudo apt install pkg-config
                            """
                    )
                )
            )
        }
        return Check(label: "pkg-config", status: .ok(path))
    }

    /// The development packages the Linux backend links against.
    public static let requiredPackages = [
        (module: "x11", package: "libx11-dev"),
        (module: "freetype2", package: "libfreetype-dev"),
        (module: "fontconfig", package: "libfontconfig-dev"),
    ]

    static func graphicsLibrariesCheck() -> Check {
        guard which("pkg-config") != nil else {
            return Check(
                label: "Graphics backend",
                status: .warning("not checked; pkg-config is missing")
            )
        }

        var missing: [(module: String, package: String)] = []
        var found: [String] = []

        for entry in requiredPackages {
            let result = try? SwiftToolchain.run("pkg-config", ["--modversion", entry.module])
            if let result, result.succeeded {
                found.append("\(entry.module) \(result.standardOutput.trimmingASCIIWhitespace())")
            } else {
                missing.append(entry)
            }
        }

        guard missing.isEmpty else {
            let packages = missing.map(\.package).joined(separator: " ")
            let modules = missing.map(\.module).joined(separator: ", ")
            return Check(
                label: "Graphics backend",
                status: .failed(
                    Diagnostic(
                        code: "CID0505",
                        summary: "missing development libraries: \(modules)",
                        reason: """
                            Cider's Linux backend presents its window through X11 and rasterizes \
                            text with FreeType. These development packages are how it finds them.
                            """,
                        remedy: """
                            Install them:

                                sudo apt install \(packages)
                            """
                    )
                )
            )
        }

        return Check(label: "Graphics backend", status: .ok(found.joined(separator: ", ")))
    }

    static func displayCheck() -> Check {
        guard let display = ProcessInfo.processInfo.environment["DISPLAY"], !display.isEmpty else {
            return Check(
                label: "Display",
                status: .warning(
                    """
                    DISPLAY is not set. Building works; `cider run` needs a display.
                        Start one with:  Xvfb :99 -screen 0 1280x1024x24 & export DISPLAY=:99
                    """
                )
            )
        }
        // Whether the connection actually succeeds is verified by the runtime,
        // which links X11; the CLI deliberately does not.
        return Check(label: "Display", status: .ok(display))
    }

    // MARK: - Helpers

    static func which(_ command: String) -> String? {
        guard
            let result = try? SwiftToolchain.run("which", [command]),
            result.succeeded
        else { return nil }
        let path = result.standardOutput.trimmingASCIIWhitespace()
        return path.isEmpty ? nil : path
    }

    static func osReleaseField(_ name: String) -> String? {
        guard let data = FileManager.default.contents(atPath: "/etc/os-release") else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, parts[0] == name else { continue }
            var value = String(parts[1])
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            return value
        }
        return nil
    }
}
