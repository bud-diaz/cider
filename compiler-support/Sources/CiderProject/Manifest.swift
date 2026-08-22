//  The Cider project manifest.
//
//  Cider owns this file so that a project's runtime metadata does not depend on
//  a proprietary project format (docs/03-technical-architecture.md section 5,
//  docs/07-legal-distribution-boundaries.md section 2).
//
//  Validation is aggressive and reports every problem at once. A developer
//  fixing a manifest should not have to run the command five times to discover
//  five mistakes.

import CiderCore
import CiderDeviceProfiles

public struct Manifest: Equatable, Sendable {
    /// The manifest schema version this parser implements. A manifest may
    /// declare `manifestVersion` to pin it; omitting it means "current".
    public static let currentSchemaVersion = 1

    public var appID: String
    public var appName: String
    public var appEntry: String
    public var minimumCompatibility: String
    public var deviceProfileName: String
    public var permissions: AppPermissions

    public init(
        appID: String,
        appName: String,
        appEntry: String,
        minimumCompatibility: String,
        deviceProfileName: String,
        permissions: AppPermissions
    ) {
        self.appID = appID
        self.appName = appName
        self.appEntry = appEntry
        self.minimumCompatibility = minimumCompatibility
        self.deviceProfileName = deviceProfileName
        self.permissions = permissions
    }

    /// Builds a launch descriptor, applying command-line overrides.
    public func launchDescriptor(
        deviceOverride: String? = nil,
        logLevel: LogLevel = .info,
        inspectorEnabled: Bool = false,
        sandboxDataRoot: String = ""
    ) -> LaunchDescriptor {
        LaunchDescriptor(
            appID: appID,
            appName: appName,
            appEntry: appEntry,
            minimumCompatibility: minimumCompatibility,
            deviceProfileName: deviceOverride ?? deviceProfileName,
            permissions: permissions,
            logLevel: logLevel,
            inspectorEnabled: inspectorEnabled,
            sandboxDataRoot: sandboxDataRoot
        )
    }
}

public enum ManifestParser {

    /// The recognised schema. Anything else in the file is an error, because a
    /// silently ignored key is a setting the developer believes is in effect.
    private static let knownTopLevelKeys: Set<String> = ["app", "runtime", "permissions", "manifestVersion"]
    private static let knownAppKeys: Set<String> = ["id", "name", "entry"]
    private static let knownRuntimeKeys: Set<String> = ["minimumCompatibility", "device"]
    private static let knownPermissionKeys: Set<String> = ["network", "localStorage"]

    public static func parse(_ text: String, file: String) throws -> Manifest {
        let nodes = try YAMLSubset.parse(text, file: file)
        var problems: [Diagnostic] = []

        for node in nodes where !knownTopLevelKeys.contains(node.key) {
            problems.append(unknownKey(node, in: "the manifest", known: knownTopLevelKeys, file: file))
        }

        if let version = nodes.first(where: { $0.key == "manifestVersion" }) {
            let declared = version.scalar.flatMap(Int.init)
            if declared != Manifest.currentSchemaVersion {
                problems.append(
                    Diagnostic(
                        code: "CID0410",
                        summary: "unsupported manifestVersion \(version.scalar ?? "(none)")",
                        location: DiagnosticLocation(file: file, line: version.line),
                        reason: "This toolchain implements manifest schema \(Manifest.currentSchemaVersion).",
                        remedy: "Set `manifestVersion: \(Manifest.currentSchemaVersion)` or remove the line."
                    )
                )
            }
        }

        // MARK: app

        guard let app = nodes.first(where: { $0.key == "app" }) else {
            problems.append(
                Diagnostic(
                    code: "CID0411",
                    summary: "the manifest has no `app` section",
                    location: DiagnosticLocation(file: file),
                    reason: "Cider needs the application's identifier, name and entry type to launch it.",
                    remedy: """
                        Add an app section:

                            app:
                              id: dev.example.myapp
                              name: My App
                              entry: MyApp
                        """
                )
            )
            throw DiagnosticBundle(problems)
        }

        for node in app.children where !knownAppKeys.contains(node.key) {
            problems.append(unknownKey(node, in: "`app`", known: knownAppKeys, file: file))
        }

        let appID = requiredScalar(app, "id", file: file, into: &problems)
        let appName = requiredScalar(app, "name", file: file, into: &problems)
        let appEntry = requiredScalar(app, "entry", file: file, into: &problems)

        if let appID, let node = app.child("id"), !isValidAppID(appID) {
            problems.append(
                Diagnostic(
                    code: "CID0412",
                    summary: "`\(appID)` is not a valid application identifier",
                    location: DiagnosticLocation(file: file, line: node.line),
                    reason: """
                        An application identifier is reverse-DNS: two or more dot-separated \
                        segments of letters, digits and hyphens, each starting with a letter.
                        """,
                    remedy: "Use something like `dev.example.myapp`."
                )
            )
        }

        if let appEntry, let node = app.child("entry"), !isValidSwiftTypeName(appEntry) {
            problems.append(
                Diagnostic(
                    code: "CID0413",
                    summary: "`\(appEntry)` is not a valid Swift type name",
                    location: DiagnosticLocation(file: file, line: node.line),
                    reason: "`entry` names the Swift type marked @main in the application's sources.",
                    remedy: "Use the type's name, for example `HelloCiderApp`."
                )
            )
        }

        // MARK: runtime

        var minimumCompatibility = "0.1"
        var deviceProfileName = DeviceProfileRegistry.defaultProfileName

        if let runtime = nodes.first(where: { $0.key == "runtime" }) {
            for node in runtime.children where !knownRuntimeKeys.contains(node.key) {
                problems.append(unknownKey(node, in: "`runtime`", known: knownRuntimeKeys, file: file))
            }

            if let node = runtime.child("minimumCompatibility") {
                let value = node.scalar ?? ""
                if isValidCompatibilityVersion(value) {
                    minimumCompatibility = value
                } else {
                    problems.append(
                        Diagnostic(
                            code: "CID0414",
                            summary: "`\(value)` is not a compatibility version",
                            location: DiagnosticLocation(file: file, line: node.line),
                            reason: "A compatibility version is MAJOR.MINOR, such as `0.1`.",
                            remedy: "Quote the value so YAML keeps it a string: `minimumCompatibility: \"0.1\"`."
                        )
                    )
                }
            }

            if let node = runtime.child("device") {
                let value = node.scalar ?? ""
                if DeviceProfileRegistry.profile(named: value) != nil {
                    deviceProfileName = value
                } else {
                    let available = DeviceProfileRegistry.all.map(\.name).sorted().joined(separator: "\n    ")
                    problems.append(
                        Diagnostic(
                            code: "CID0415",
                            summary: "unknown device profile `\(value)`",
                            location: DiagnosticLocation(file: file, line: node.line),
                            reason: "Cider has no device profile by that name.",
                            remedy: "Available profiles:\n\n    \(available)"
                        )
                    )
                }
            }
        }

        // MARK: permissions
        //
        // Absent means denied. A capability a developer did not ask for is not
        // one Cider should grant, and Stage 3's services will enforce these.

        var permissions = AppPermissions.none

        if let block = nodes.first(where: { $0.key == "permissions" }) {
            for node in block.children where !knownPermissionKeys.contains(node.key) {
                problems.append(unknownKey(node, in: "`permissions`", known: knownPermissionKeys, file: file))
            }
            permissions.network = boolean(block.child("network"), file: file, into: &problems) ?? false
            permissions.localStorage = boolean(block.child("localStorage"), file: file, into: &problems) ?? false
        }

        guard problems.isEmpty, let appID, let appName, let appEntry else {
            throw DiagnosticBundle(problems)
        }

        return Manifest(
            appID: appID,
            appName: appName,
            appEntry: appEntry,
            minimumCompatibility: minimumCompatibility,
            deviceProfileName: deviceProfileName,
            permissions: permissions
        )
    }

    // MARK: - Helpers

    private static func requiredScalar(
        _ parent: YAMLNode,
        _ key: String,
        file: String,
        into problems: inout [Diagnostic]
    ) -> String? {
        guard let node = parent.child(key) else {
            problems.append(
                Diagnostic(
                    code: "CID0416",
                    summary: "`\(parent.key).\(key)` is missing",
                    location: DiagnosticLocation(file: file, line: parent.line),
                    reason: "Cider needs `\(key)` to launch the application.",
                    remedy: "Add `\(key): <value>` under `\(parent.key):`."
                )
            )
            return nil
        }
        guard let scalar = node.scalar, !scalar.isEmpty else {
            problems.append(
                Diagnostic(
                    code: "CID0417",
                    summary: "`\(parent.key).\(key)` has no value",
                    location: DiagnosticLocation(file: file, line: node.line),
                    reason: "The key is present but empty.",
                    remedy: "Give `\(key)` a value."
                )
            )
            return nil
        }
        return scalar
    }

    private static func boolean(
        _ node: YAMLNode?,
        file: String,
        into problems: inout [Diagnostic]
    ) -> Bool? {
        guard let node else { return nil }
        switch node.scalar {
        case "true": return true
        case "false": return false
        default:
            problems.append(
                Diagnostic(
                    code: "CID0418",
                    summary: "`\(node.key)` must be true or false",
                    location: DiagnosticLocation(file: file, line: node.line),
                    reason: "Cider reads permissions strictly: `\(node.scalar ?? "(empty)")` is not a boolean.",
                    remedy: "Write `\(node.key): true` or `\(node.key): false`."
                )
            )
            return nil
        }
    }

    private static func unknownKey(
        _ node: YAMLNode,
        in section: String,
        known: Set<String>,
        file: String
    ) -> Diagnostic {
        let suggestions = known.sorted().joined(separator: ", ")
        return Diagnostic(
            code: "CID0419",
            summary: "unknown key `\(node.key)` in \(section)",
            location: DiagnosticLocation(file: file, line: node.line),
            reason: """
                Cider rejects keys it does not recognise, because a setting that is silently \
                ignored is one a developer believes is in effect.
                """,
            remedy: "Recognised keys here: \(suggestions)."
        )
    }

    // MARK: - Validation predicates

    static func isValidAppID(_ value: String) -> Bool {
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        for segment in segments {
            guard let first = segment.first, first.isLetter else { return false }
            let valid = segment.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
            guard valid, !segment.hasSuffix("-") else { return false }
        }
        return true
    }

    static func isValidSwiftTypeName(_ value: String) -> Bool {
        guard let first = value.first, first.isLetter || first == "_" else { return false }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    static func isValidCompatibilityVersion(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }
}
