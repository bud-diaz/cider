# Project Charter

## 1. Mission

Build an open, host-native development runtime that shortens the
feedback loop for developers creating iOS applications while working on
Linux and, later, Windows.

The project should make it possible to execute a useful subset of
application logic and UI locally without booting iOS or requiring macOS
for every edit-run-debug cycle.

## 2. Problem Statement

Apple's production iOS SDK, simulator, signing workflow, and platform UI
frameworks are coupled to Apple's development environment. Developers
who prefer Linux or Windows can write cross-platform code there, but
validation of iOS-specific behavior generally pulls the workflow back to
macOS.

The project addresses the **development-loop problem**, not the App
Store distribution problem.

## 3. Product Thesis

A compatibility runtime can provide substantial developer value before
achieving complete iOS compatibility.

Success does not require emulating an iPhone. Success requires making
common application code sufficiently executable, inspectable, testable,
and predictable on a non-macOS host.

## 4. Scope

### In Scope for MVP

-   Ubuntu Linux x86-64 host.
-   Swift compilation and execution.
-   Project-defined application lifecycle.
-   Windowed virtual-device shell.
-   Basic UI primitives.
-   Navigation.
-   Text and images.
-   Pointer-to-touch translation.
-   Keyboard input.
-   HTTP networking.
-   Local application storage.
-   Logging and developer console.
-   Deterministic device profiles.
-   Compatibility/conformance test suite.
-   CLI for building and launching supported projects.

### Explicitly Out of Scope for MVP

-   Booting or redistributing iOS.
-   Full iPhone hardware emulation.
-   App Store DRM or arbitrary App Store binaries.
-   Apple account authentication.
-   Apple code-signing circumvention.
-   Secure Enclave emulation.
-   Cellular/baseband emulation.
-   Exact UIKit or SwiftUI parity.
-   App Store submission from Linux.
-   Claims of certification or endorsement by Apple.

## 5. Users

Primary users are Swift/iOS developers who use Linux as a primary
workstation or CI environment.

Secondary users include educators, open-source maintainers,
cross-platform framework authors, automated test systems, and Windows
developers after the second host target ships.

## 6. Principles

1.  **Compatibility over imitation.** Reproduce useful behavior, not
    Apple's branding.
2.  **No proprietary runtime dependency.** A normal installation must
    not require copied Apple binaries or firmware.
3.  **Incremental compatibility.** Every supported API must have
    documented behavior and tests.
4.  **Fail loudly.** Unsupported APIs should produce actionable
    diagnostics rather than silently behaving incorrectly.
5.  **Host-native where practical.** Use Linux/Windows facilities
    instead of emulating hardware unnecessarily.
6.  **Developer-owned code first.** MVP optimizes for source projects
    the developer controls.
7.  **Xcode remains the production authority.** Compatibility results
    are useful development signals, not guarantees of identical behavior
    on iOS.

## 7. Success Criteria

MVP is successful when a clean Ubuntu machine can install the toolchain,
build the reference applications, launch them in the virtual-device
shell, interact with their supported UI, perform network/storage
operations, and pass the published compatibility suite without Apple
proprietary runtime files.

## 8. Governance Before Public Launch

The project should establish:

-   project name and trademark review;
-   license;
-   contribution agreement or DCO policy;
-   code of conduct;
-   security reporting process;
-   compatibility-versioning policy;
-   release process;
-   maintainer decision process.
