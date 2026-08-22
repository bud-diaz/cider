//  Backend selection.
//
//  This file is the single place in Cider allowed to name a concrete platform
//  backend. Everything above it -- the runtime, the UI tree, the compatibility
//  layer -- talks only to `CiderHost` protocols.
//
//  Adding the Windows backend means adding one branch here and one target in
//  Package.swift. If a second file ever needs a `#if os(...)` around a backend
//  type, the abstraction has sprung a leak and that is the bug to fix.

import CiderCore
import CiderHost

#if os(Linux)
import CiderHostLinux
#endif

public enum HostBootstrap {
    /// Returns the backend for the platform Cider was built for.
    public static func makeDefaultBackend() throws -> HostBackend {
        #if os(Linux)
        return LinuxHostBackend()
        #else
        throw Diagnostic(
            code: "CID0001",
            summary: "no Cider backend for this platform",
            reason: """
                Cider currently ships a Linux backend only. Windows support is planned; \
                see docs/05-implementation-roadmap.md.
                """,
            remedy: "Run Cider on Linux, or build with a backend for this platform."
        )
        #endif
    }

    /// Environment checks the backend can make without opening a window.
    /// An empty result means the platform looks usable.
    public static func probeDefaultBackend() -> [Diagnostic] {
        #if os(Linux)
        return LinuxHostBackend.probe()
        #else
        return [
            Diagnostic(
                code: "CID0001",
                summary: "no Cider backend for this platform",
                reason: "Cider currently ships a Linux backend only.",
                remedy: "Run Cider on Linux."
            )
        ]
        #endif
    }
}
