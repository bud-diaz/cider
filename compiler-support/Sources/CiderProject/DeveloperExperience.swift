//  Stage 4 developer-experience helpers.
//
//  These are intentionally text-first tools. They provide useful project
//  inspection, network/storage visibility, templates and a documented fast
//  rebuild/relaunch loop without pulling runtime/backend dependencies into the
//  CLI.

import Foundation
import CiderCore

public enum ProjectInspector {
    public static func report(
        for project: Project,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> String {
        let sandbox = SandboxPathResolver.dataRoot(for: project.manifest.appID, environment: environment)
        let diagnostics = try CompatibilityScanner.scan(project: project)
        var lines: [String] = [
            "# Cider Project Inspector",
            "",
            "project: \(project.root.path)",
            "manifest: \(project.manifestURL.path)",
            "app id: \(project.manifest.appID)",
            "app name: \(project.manifest.appName)",
            "entry: \(project.manifest.appEntry)",
            "device: \(project.manifest.deviceProfileName)",
            "minimum compatibility: \(project.manifest.minimumCompatibility)",
            "network: \(project.manifest.permissions.network)",
            "localStorage: \(project.manifest.permissions.localStorage)",
            "sandbox: \(sandbox.path)",
            "",
            "## Compatibility scan",
        ]
        if diagnostics.isEmpty {
            lines.append("no recognized unsupported APIs found")
        } else {
            for diagnostic in diagnostics {
                lines.append("- \(diagnostic.code) \(diagnostic.location?.description ?? project.root.path): \(diagnostic.summary)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

public enum NetworkViewer {
    public static func report(for project: Project) throws -> String {
        let urls = try findCiderHTTPURLs(in: project.root)
        var lines: [String] = [
            "# Cider Network Viewer",
            "",
            "project: \(project.root.path)",
            "network permission: \(project.manifest.permissions.network)",
            "",
            "## CiderHTTP call sites",
        ]
        if urls.isEmpty {
            lines.append("none found")
        } else {
            for item in urls {
                lines.append("- \(item.url) (\(item.file):\(item.line))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func findCiderHTTPURLs(in root: URL) throws -> [(url: String, file: String, line: Int)] {
        var results: [(String, String, Int)] = []
        for file in try swiftSourceFiles(under: root) {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard line.contains("CiderHTTP") else { continue }
                results.append(contentsOf: quotedURLs(in: String(line)).map { ($0, file.path, index + 1) })
            }
        }
        return results
    }

    private static func quotedURLs(in line: String) -> [String] {
        var urls: [String] = []
        var remainder = line[...]
        while let quote = remainder.firstIndex(of: "\"") {
            let after = remainder.index(after: quote)
            guard let end = remainder[after...].firstIndex(of: "\"") else { break }
            let value = String(remainder[after..<end])
            if value.hasPrefix("http://") || value.hasPrefix("https://") {
                urls.append(value)
            }
            remainder = remainder[remainder.index(after: end)...]
        }
        return urls
    }
}

public enum StorageViewer {
    public static func report(
        for project: Project,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> String {
        let root = SandboxPathResolver.dataRoot(for: project.manifest.appID, environment: environment)
        var lines: [String] = [
            "# Cider Storage Viewer",
            "",
            "app id: \(project.manifest.appID)",
            "sandbox: \(root.path)",
            "localStorage permission: \(project.manifest.permissions.localStorage)",
            "",
            "## Files",
        ]
        let files = try storageFiles(under: root)
        if files.isEmpty {
            lines.append("none found")
        } else {
            for file in files {
                let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
                let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
                lines.append("- \(relative) — \(size) bytes")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func storageFiles(under root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true { files.append(url) }
        }
        return files.sorted { $0.path < $1.path }
    }
}

public enum TemplateGenerator {
    public static func createApp(named name: String, appID: String, at destination: URL) throws {
        guard ManifestParser.isValidAppID(appID) else {
            throw Diagnostic(code: "CID0610", summary: "`\(appID)` is not a valid application identifier")
        }
        guard ManifestParser.isValidSwiftTypeName(name) else {
            throw Diagnostic(code: "CID0611", summary: "`\(name)` is not a valid Swift type name")
        }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw Diagnostic(
                code: "CID0612",
                summary: "template destination already exists",
                location: DiagnosticLocation(file: destination.path),
                remedy: "Choose an empty path for the new Cider project."
            )
        }

        let sourceDirectory = destination.appendingPathComponent("Sources/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try packageSwift(name: name).write(to: destination.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try manifest(name: name, appID: appID).write(to: destination.appendingPathComponent("Cider.yaml"), atomically: true, encoding: .utf8)
        try appSource(name: name).write(to: sourceDirectory.appendingPathComponent("\(name).swift"), atomically: true, encoding: .utf8)
        try readme(name: name).write(to: destination.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    }

    private static func packageSwift(name: String) -> String {
        """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(name)",
            products: [.executable(name: "\(name)", targets: ["\(name)"])],
            dependencies: [.package(path: "../..")],
            targets: [.executableTarget(name: "\(name)", dependencies: [.product(name: "CiderUI", package: "Cider")])]
        )
        """
    }

    private static func manifest(name: String, appID: String) -> String {
        """
        app:
          id: \(appID)
          name: \(name)
          entry: \(name)
        runtime:
          minimumCompatibility: "0.1"
          device: phone-standard
        permissions:
          network: false
          localStorage: true
        """
    }

    private static func appSource(name: String) -> String {
        """
        import CiderUI

        @main
        struct \(name): CiderApp {
            @CiderState private var count = 0

            var body: some CiderView {
                VStack(spacing: 24) {
                    Text("\(name)")
                        .font(size: 28, weight: .bold)
                    Button("Tap") { count += 1 }
                    Text("Count: \\(count)")
                }
            }
        }
        """
    }

    private static func readme(name: String) -> String {
        """
        # \(name)

        ```sh
        cider scan
        cider run
        ```
        """
    }
}

public enum DevLoopPlanner {
    public static func plan(for project: Project, configuration: String) -> String {
        """
        # Cider Dev Loop

        project: \(project.root.path)
        configuration: \(configuration)

        1. Build once after source changes:
           swift build --package-path \(project.root.path) -c \(configuration)

        2. Relaunch without rebuilding when only runtime inputs changed:
           cider run --no-build --path \(project.root.path) --configuration \(configuration)

        3. Use inspection while iterating:
           cider run --no-build --inspect --path \(project.root.path) --configuration \(configuration)
        """
    }
}

private func swiftSourceFiles(under root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }
    var files: [URL] = []
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values.isDirectory == true, [".build", ".git", ".cider", "DerivedData"].contains(url.lastPathComponent) {
            enumerator.skipDescendants()
            continue
        }
        if values.isRegularFile == true, url.pathExtension == "swift" { files.append(url) }
    }
    return files.sorted { $0.path < $1.path }
}
