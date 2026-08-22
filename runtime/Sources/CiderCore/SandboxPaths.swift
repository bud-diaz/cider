//  The layout of an application's isolated data area.
//
//  docs/03-technical-architecture.md section 8 asks for per-app data roots.
//  This type only names the subdirectories inside one -- resolving where the
//  root lives on disk and creating it is `SandboxPathResolver`'s job, in
//  CiderProject, which is the toolchain module already doing filesystem work.
//  CiderCore stays Foundation-free, so this is plain string joining.

public struct SandboxPaths: Equatable, Sendable {
    /// The application's isolated data root. Empty when none was prepared
    /// (the binary was started without going through `cider run`).
    public var root: String

    public init(root: String) {
        self.root = root
    }

    public var documents: String { root + "/Documents" }
    public var cache: String { root + "/Cache" }
    public var temporary: String { root + "/tmp" }
}
