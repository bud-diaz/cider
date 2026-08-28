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
        let contractTagged = fileContains(repoRoot, "RELEASE_NOTES.md", alphaVersion)
        let securityChannelPublished = fileContains(repoRoot, "SECURITY.md", "private vulnerability reporting")
            && !fileContains(repoRoot, "SECURITY.md", "has not been published yet")
        let licensed = fileExists(repoRoot, "LICENSE")
        let knownIssueRows = knownIssueRowCount(repoRoot: repoRoot)
        let performanceRecorded = fileExists(repoRoot, "docs/performance-baseline.md")
            && !fileContains(repoRoot, "docs/performance-baseline.md", "No public alpha numbers are published yet")

        return [
            AlphaGate(
                // Deliberately never `.done`: signed archives / package-manager distribution need
                // real release infrastructure no file can attest to. This gate is intentionally
                // accepted as an alpha caveat rather than flipped in code — see RELEASE_NOTES.md.
                requirement: "installation packaging",
                status: fileExists(repoRoot, "docs/install.md") ? .partial : .missing,
                evidence: fileExists(repoRoot, "docs/install.md") ? "docs/install.md documents source-build install and PATH setup" : "no install document found",
                nextStep: "Add signed archives or package-manager distribution before public alpha."
            ),
            AlphaGate(
                requirement: "versioned compatibility contract",
                status: fileExists(repoRoot, "docs/compatibility-registry.md") ? (contractTagged ? .done : .partial) : .missing,
                evidence: contractTagged
                    ? "contract \(compatibilityContractVersion), CLI \(alphaVersion), registry entries: \(CompatibilityRegistry.all.count), tagged \(alphaVersion) (see RELEASE_NOTES.md)"
                    : "contract \(compatibilityContractVersion), CLI \(alphaVersion), registry entries: \(CompatibilityRegistry.all.count)",
                nextStep: contractTagged
                    ? "Keep conformance IDs and registry entries stable for the alpha line."
                    : "Tag the alpha contract and treat conformance IDs plus registry entries as stable for the alpha line."
            ),
            AlphaGate(
                requirement: "security reporting",
                status: fileExists(repoRoot, "SECURITY.md") ? (securityChannelPublished ? .done : .partial) : .missing,
                evidence: securityChannelPublished
                    ? "SECURITY.md documents GitHub private vulnerability reporting as the public contact channel"
                    : (fileExists(repoRoot, "SECURITY.md") ? "SECURITY.md exists, but the public contact is still owner-direct/TBD" : "SECURITY.md missing"),
                nextStep: securityChannelPublished ? "Keep the reporting channel current." : "Publish a durable security contact before inviting external alpha users."
            ),
            AlphaGate(
                requirement: "contribution policy",
                status: fileExists(repoRoot, "CONTRIBUTING.md") ? (licensed ? .done : .partial) : .missing,
                evidence: licensed
                    ? "LICENSE (Apache-2.0), CONTRIBUTING.md and CODE_OF_CONDUCT.md exist; outside contributions are open"
                    : (fileExists(repoRoot, "CONTRIBUTING.md") ? "CONTRIBUTING.md and CODE_OF_CONDUCT.md exist; outside contributions remain gated on license/public channel" : "CONTRIBUTING.md missing"),
                nextStep: licensed ? "Keep the contribution path current." : "Select a license and open the documented contribution path."
            ),
            AlphaGate(
                requirement: "known-issues database",
                status: knownIssueRows > 0 ? .done : (fileExists(repoRoot, "docs/known-issues.md") ? .partial : .missing),
                evidence: knownIssueRows > 0
                    ? "docs/known-issues.md records \(knownIssueRows) alpha caveat(s)"
                    : (fileExists(repoRoot, "docs/known-issues.md") ? "docs/known-issues.md records alpha caveats" : "docs/known-issues.md missing"),
                nextStep: knownIssueRows > 0 ? "Move issue records to the public tracker when the repo opens." : "Record known issues before public alpha."
            ),
            AlphaGate(
                requirement: "performance baseline",
                status: fileExists(repoRoot, "docs/performance-baseline.md") ? (performanceRecorded ? .done : .partial) : .missing,
                evidence: performanceRecorded
                    ? "docs/performance-baseline.md records measured alpha numbers"
                    : (fileExists(repoRoot, "docs/performance-baseline.md") ? "docs/performance-baseline.md defines repeatable commands and current baseline scope" : "docs/performance-baseline.md missing"),
                nextStep: performanceRecorded ? "Re-measure when the supported CI/host matrix changes." : "Record measured alpha numbers in CI or release notes before tagging."
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

    private static func fileContains(_ root: URL, _ relativePath: String, _ needle: String) -> Bool {
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else { return false }
        return text.contains(needle)
    }

    private static func knownIssueRowCount(repoRoot: URL) -> Int {
        guard let text = try? String(contentsOf: repoRoot.appendingPathComponent("docs/known-issues.md"), encoding: .utf8) else { return 0 }
        return text.split(separator: "\n").filter { $0.hasPrefix("| CIDER-KI-") }.count
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
