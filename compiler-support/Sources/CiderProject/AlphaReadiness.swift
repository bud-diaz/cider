//  Stage 5 alpha-readiness inventory.
//
//  Stage 5 is broader than code: a public alpha needs a versioned compatibility
//  contract, explicit operational policies, known issues, a performance baseline,
//  enough reference applications, and CI coverage for supported Ubuntu releases.
//  This report keeps those gates visible from the CLI instead of scattering them
//  across hand-written status prose.

import Foundation

public enum AlphaGateStatus: String, Equatable, Sendable {
    case done = "done"
    case partial = "partial"
    case missing = "missing"
}

public struct AlphaGate: Equatable, Sendable {
    public var requirement: String
    public var status: AlphaGateStatus
    public var evidence: String
    public var nextStep: String

    public init(requirement: String, status: AlphaGateStatus, evidence: String, nextStep: String) {
        self.requirement = requirement
        self.status = status
        self.evidence = evidence
        self.nextStep = nextStep
    }
}

public enum AlphaReadinessReport {
    public static let alphaVersion = "0.1.0-alpha.0"
    public static let compatibilityContractVersion = "0.1"

    public static func markdown(repoRoot: URL) -> String {
        let gates = evaluate(repoRoot: repoRoot)
        var lines: [String] = [
            "# Cider Alpha Readiness",
            "",
            "alpha version: \(alphaVersion)",
            "compatibility contract: \(compatibilityContractVersion)",
            "repo: \(repoRoot.path)",
            "",
            "| Requirement | Status | Evidence | Next step |",
            "| --- | --- | --- | --- |",
        ]
        for gate in gates {
            lines.append("| \(escape(gate.requirement)) | \(gate.status.rawValue) | \(escape(gate.evidence)) | \(escape(gate.nextStep)) |")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    public static func evaluate(repoRoot: URL) -> [AlphaGate] {
        let referenceAppCount = countReferenceApps(repoRoot: repoRoot)
        let ciUbuntuVersions = supportedUbuntuVersions(repoRoot: repoRoot)

        return [
            AlphaGate(
                requirement: "installation packaging",
                status: fileExists(repoRoot, "docs/install.md") ? .partial : .missing,
                evidence: fileExists(repoRoot, "docs/install.md") ? "docs/install.md documents source-build install and PATH setup" : "no install document found",
                nextStep: "Add signed archives or package-manager distribution before public alpha."
            ),
            AlphaGate(
                requirement: "versioned compatibility contract",
                status: fileExists(repoRoot, "docs/compatibility-registry.md") ? .partial : .missing,
                evidence: "contract \(compatibilityContractVersion), CLI \(alphaVersion), registry entries: \(CompatibilityRegistry.all.count)",
                nextStep: "Tag the alpha contract and treat conformance IDs plus registry entries as stable for the alpha line."
            ),
            AlphaGate(
                requirement: "security reporting",
                status: fileExists(repoRoot, "SECURITY.md") ? .partial : .missing,
                evidence: fileExists(repoRoot, "SECURITY.md") ? "SECURITY.md exists, but the public contact is still owner-direct/TBD" : "SECURITY.md missing",
                nextStep: "Publish a durable security contact before inviting external alpha users."
            ),
            AlphaGate(
                requirement: "contribution policy",
                status: fileExists(repoRoot, "CONTRIBUTING.md") ? .partial : .missing,
                evidence: fileExists(repoRoot, "CONTRIBUTING.md") ? "CONTRIBUTING.md and CODE_OF_CONDUCT.md exist; outside contributions remain gated on license/public channel" : "CONTRIBUTING.md missing",
                nextStep: "Select a license and open the documented contribution path."
            ),
            AlphaGate(
                requirement: "known-issues database",
                status: fileExists(repoRoot, "docs/known-issues.md") ? .partial : .missing,
                evidence: fileExists(repoRoot, "docs/known-issues.md") ? "docs/known-issues.md records alpha caveats" : "docs/known-issues.md missing",
                nextStep: "Move issue records to the public tracker when the repo opens."
            ),
            AlphaGate(
                requirement: "performance baseline",
                status: fileExists(repoRoot, "docs/performance-baseline.md") ? .partial : .missing,
                evidence: fileExists(repoRoot, "docs/performance-baseline.md") ? "docs/performance-baseline.md defines repeatable commands and current baseline scope" : "docs/performance-baseline.md missing",
                nextStep: "Record measured alpha numbers in CI or release notes before tagging."
            ),
            AlphaGate(
                requirement: "at least 10 reference applications",
                status: referenceAppCount >= 10 ? .done : .partial,
                evidence: "\(referenceAppCount) example app(s) with Cider.yaml under examples/",
                nextStep: referenceAppCount >= 10 ? "Keep examples building in CI." : "Add \(10 - referenceAppCount) more reference apps that cover distinct app patterns."
            ),
            AlphaGate(
                requirement: "CI on supported Ubuntu versions",
                status: ciUbuntuVersions.count >= 2 ? .done : (ciUbuntuVersions.isEmpty ? .missing : .partial),
                evidence: ciUbuntuVersions.isEmpty ? "no ubuntu-* runners found in CI" : "CI runners: \(ciUbuntuVersions.joined(separator: ", "))",
                nextStep: ciUbuntuVersions.count >= 2 ? "Keep the supported-version matrix aligned with docs/06-testing-strategy.md." : "Expand CI to every Ubuntu version Cider claims to support."
            ),
        ]
    }

    private static func fileExists(_ root: URL, _ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    private static func countReferenceApps(repoRoot: URL) -> Int {
        let examples = repoRoot.appendingPathComponent("examples", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: examples, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return 0
        }
        return entries.filter { entry in
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
            return FileManager.default.fileExists(atPath: entry.appendingPathComponent("Cider.yaml").path)
        }.count
    }

    private static func supportedUbuntuVersions(repoRoot: URL) -> [String] {
        let workflow = repoRoot.appendingPathComponent(".github/workflows/ci.yml")
        guard let text = try? String(contentsOf: workflow, encoding: .utf8) else { return [] }
        var versions: Set<String> = []
        for token in text.split(whereSeparator: { $0.isWhitespace || ["[", "]", ",", "\"", "'"].contains($0) }) {
            let value = String(token)
            if value.hasPrefix("ubuntu-") {
                versions.insert(value)
            }
        }
        return versions.sorted()
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
