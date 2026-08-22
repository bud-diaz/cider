# 0001. Language boundaries

## Status

Accepted — 2026-08-22. Applies from the first milestone.

## Context

Cider spans an application-facing API, a runtime, a renderer, platform backends
and a command-line toolchain. Each layer has different constraints, and the
question of which language each is written in has to be settled before the
module graph is, because it decides where the seams can go.

Three constraints shape the answer.

The application-facing layer must be Swift. The project's whole premise is that
developers write Swift application code and run it on Linux; anything else is a
different product.

The platform backends have to talk to C libraries. X11 and FreeType are C APIs,
and on Windows the equivalents will be Win32 and DirectWrite. Swift can import C
directly, but Xlib and FreeType are macro-heavy in ways that make the imported
surface awkward and fragile across versions.

The CLI has a failure mode the other layers do not. `cider doctor` exists to
diagnose a machine that cannot run Cider — a missing Swift toolchain, an absent
libX11. A CLI that requires the things it diagnoses is useless in exactly the
case that matters.

## Decision

**Swift** for everything from the host abstraction upward: `CiderCore`,
`CiderUITree`, `CiderHost`, `CiderRuntime`, `CiderDeviceProfiles`,
`CiderInspector`, `CiderUI`, `CiderProject`, and the `cider` executable.

**C99** for the thin shims over platform C libraries, and only for those:
`CX11Shim` and `CTextShim` today. A shim exposes a flat C surface that maps
one-to-one onto the abstract host interfaces and holds no policy — every
decision about what an event *means* is made in Swift.

The `cider` executable is Swift but **links neither the runtime nor any host
backend**. It depends on `CiderCore`, `CiderProject` and `CiderDeviceProfiles`.
It checks the environment the way a build system does — pkg-config, `which`,
`DISPLAY` — and reports what it could not verify rather than assuming.

`cider run` launches the application as a **separate process**.

## Alternatives Considered

**Swift everywhere, importing Xlib and FreeType directly.** One language, no
shims. Rejected because Xlib's API is largely macros (`DefaultScreen`,
`RootWindow`, `BlackPixel`) and FreeType's headers use an include-macro
convention that Swift's importer handles inconsistently across versions. The
Swift that resulted would be C written in Swift syntax, without the readability
of either.

**A C or C++ core with Swift only at the application layer.** Would make the
backends natural and the runtime portable in the traditional sense. Rejected
because it puts a language boundary in the middle of the hot path — every view
rebuild would cross it — and because the runtime's most intricate logic
(identity, invalidation, lowering) is exactly what Swift's type system helps
with most.

**Rust for the backends, with a C ABI between.** Genuinely attractive: memory
safety where the raw pointers are. Rejected for this milestone on
contributor-cost grounds. It would make Cider a three-language project before it
has any contributors, and `docs/07-legal-distribution-boundaries.md` section 8
asks that every dependency — a toolchain included — carry a recorded
justification. Worth revisiting if the backends grow beyond a few hundred lines
each.

**A CLI in C or a shell script, so `doctor` never needs Swift.** Removes the
last dependency from the diagnostic path: a prebuilt `cider` binary would run
anywhere. Rejected because the CLI also parses and validates the manifest, and
that parser would then either be duplicated in two languages or live in the
weaker one. The chosen split — CLI in Swift, but linking no backend — keeps the
parser in one place while still letting `doctor` run on a machine with no X11.

## Consequences

- Contributors need a Swift toolchain and a C compiler. `cider doctor` checks
  for both.
- The C shims are a permanent maintenance surface. They are kept deliberately
  small and are compiled with `-Wall -Wextra` clean.
- Each new backend adds a shim, so the shim API is a real interface and changes
  to it are breaking changes for every platform.
- The CLI cannot verify that an X connection actually succeeds, only that the
  libraries and `DISPLAY` are present. `cider doctor` says so rather than
  claiming more; the live check happens at `cider run`.
- Because `cider run` spawns the application, a crash in developer code cannot
  take the toolchain's error reporting down with it — but the CLI also cannot
  inspect runtime state directly. When the inspector grows, it will need a
  channel between the two processes.
