# 0005. Swift toolchain and runtime integration

## Status

Accepted — 2026-08-22.

## Context

`docs/05-implementation-roadmap.md` Stage 0 spike 5 asks for "a minimal
application compiled through the proposed CLI path." That raises three questions
that have to be answered together:

1. How is an application compiled?
2. How does application code become an application the runtime can drive?
3. How does an application start?

The third is subtler than it sounds. Swift's `@main` entry point is a static
method on a type. A developer writes a `struct` with a `body`; something has to
turn that into a running event loop with a window, without the developer writing
any of it and without the runtime knowing what a `struct` with a `body` is.

## Decision

**SwiftPM is the build system.** A Cider application is an ordinary SwiftPM
executable that depends on `CiderUI`. `cider build` runs `swift build`; the
compiler's diagnostics pass through untouched, because a Swift error message is
already better than anything Cider would produce by reformatting it. Cider adds
what surrounds the compile: the manifest, the device profile, the launch
descriptor and the runtime.

**Exactly one executable product.** `cider build` reads `swift package describe
--type json`, requires exactly one executable, and produces a specific diagnostic
for none and for several. Guessing which of two to launch would be implicit
behaviour that is fine until the day it picks wrong.

**`CiderApp` supplies `main()` in a protocol extension**, so a developer writes:

```swift
@main
struct HelloCiderApp: CiderApp {
    @CiderState private var count = 0
    var body: some CiderView { ... }
}
```

`main()` resolves the launch descriptor, asks `HostBootstrap` for the platform's
backend, wraps the application value in `CiderAppAdapter`, and runs the runtime.

**`CiderAppAdapter` is the only bridge.** It implements the runtime's
`RuntimeApplication` protocol. The runtime never learns that an application is a
Swift struct with property wrappers in it.

**State is a class-backed property wrapper wired up by reflection.** `@CiderState`
is a `final class`, so its setter is non-mutating and every copy of the app value
shares one box. At launch the adapter walks `Mirror(reflecting: app).children`
and attaches an invalidation closure to each `CiderStateStorage` it finds.

**Applications run as a separate process.** `cider run` spawns the built
artifact with `--cider-launch <path>`, inherits its output, and waits.

## Alternatives Considered

**A Cider-specific build system or a wrapper that generates a `Package.swift`.**
More control over flags and layout. Rejected because SwiftPM already does
incremental builds, dependency resolution, and pkg-config integration for
Cider's C shims — reimplementing that is a large project whose only output is a
different set of bugs. Generating `Package.swift` was rejected separately: a
generated file the developer cannot edit is worse than one they own.

**Requiring the developer to write `main.swift` and call the runtime by hand.**
No reflection, no protocol magic, and the entry point is explicit. Rejected
because it puts boilerplate in every project and makes the runtime's construction
part of the public API — which then cannot change.

**A macro (`@CiderMain`) instead of a protocol extension.** Swift macros could
generate the entry point and, more importantly, could *enumerate* state
properties at compile time instead of reflecting at runtime. Genuinely better in
the long run. Rejected for this milestone on cost: a macro target adds
swift-syntax as a build-time dependency, roughly doubles clean build time, and
would need its own diagnostics story. Worth revisiting once the state model is
settled — the reflection is confined to one function, `attachState(of:)`.

**Explicit state registration, e.g. `context.register($count)`.** No reflection,
fully typed. Rejected because it is a step a developer can forget, and the
symptom of forgetting is a UI that silently stops updating — the worst kind of
bug to diagnose.

**Running the application in-process, inside the `cider` binary.** One process,
simpler launch, and the CLI could inspect runtime state directly. Rejected
because it would mean the CLI links the runtime and every host library, which
ADR 0001 rules out for `cider doctor`'s sake, and because a crash in developer
code would take the toolchain's error reporting with it.

**A value-type `@CiderState`.** Rejected outright: a button's action closure
captures the application value, so a value wrapper would have the action
incrementing a copy that is discarded.

## Consequences

- A Cider project is a normal Swift package. It opens in any editor with SwiftPM
  support, and `swift build` works without Cider installed.
- Running the built binary directly — without `cider run` — works and uses
  documented defaults, so a debugger session is not a different code path.
- Reflection over `Mirror` costs one walk at launch and is confined to
  `CiderAppAdapter.attachState(of:)`. It currently visits only the application's
  own stored properties; when nested views hold state, that walk has to grow.
- The state model has no diffing: any write to any `@CiderState` invalidates the
  whole tree.
- Because the application is a subprocess, the future inspector will need a
  channel between the two processes rather than a direct call.
- Cider's own sources build in Swift 6 language mode with strict concurrency
  checking, which is why `EnvironmentProbe` requires Swift 6.0 rather than
  preferring it.
