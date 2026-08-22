# Cider

**Cider is an open-source compatibility runtime for developing and testing
iOS-style applications on Linux and, later, Windows.**

Cider does not emulate iPhone hardware and does not distribute iOS. It is an
independently written development runtime implementing a growing subset of
application behaviour that is useful while you are building something — so that
the edit-run-inspect loop can stay on the machine you already work on.

Apple's toolchain remains the authority for iOS compilation, code signing,
physical-device validation, TestFlight and App Store distribution. Cider does
not replace any of those and does not try to.

> **Status: pre-alpha.** Stage 0 of the roadmap is complete: a Swift application
> launches through the Cider CLI and displays an interactive button in a Linux
> window. That is the whole of it. Everything else on this page is either a
> non-goal or future work.

---

## What works today

```
cd examples/hello-cider
cider doctor
cider run
```

```
┌───────────────────────────┐
│                           │
│        Cider Demo         │
│                           │
│      [  Press Me  ]       │
│                           │
│         Count: 0          │
│                           │
└───────────────────────────┘
```

Clicking **Press Me** runs Swift application code, changes application state, and
redraws:

```
Count: 1
```

Concretely:

- **`cider doctor`** — inspects the host and reports what is missing, with the
  command to fix it.
- **`cider build`** — locates the project, validates its manifest, compiles
  through SwiftPM, and reports the runnable artifact.
- **`cider run`** — builds if needed, resolves a device profile, opens a
  virtual-device window, runs the application, and shuts down cleanly.
- **A declarative Swift API** — `CiderApp`, `CiderView`, `Text`, `Button`,
  `VStack`, `@CiderState`.
- **A normalized UI tree** with stable identity, a two-pass layout engine, and a
  portable software rasterizer with antialiased rounded rectangles.
- **A Linux backend** over X11 and FreeType, behind abstract host interfaces.
- **A headless backend** used by the test suites, so conformance and visual tests
  need no display.
- **103 tests** across unit, conformance, integration and visual-regression
  suites.

## Goals

- Shorten the iOS development loop for people whose workstation is Linux.
- Make a documented, tested subset of application behaviour executable and
  inspectable off macOS.
- Keep the architecture host-neutral, so Windows is a second backend rather than
  a rewrite.
- Fail loudly and usefully. An unsupported call should produce a diagnostic that
  says what failed, where, why, and how to fix it.

## Non-goals

Cider will not:

- boot, bundle, or redistribute iOS;
- emulate iPhone hardware;
- run App Store binaries, or bypass DRM or code signing;
- emulate the Secure Enclave, or impersonate Apple services;
- require an Apple ID;
- claim exact iOS compatibility, or replace Xcode for shipping an app.

See [`docs/07-legal-distribution-boundaries.md`](docs/07-legal-distribution-boundaries.md).

## Requirements

- Linux x86-64 (developed and tested on Ubuntu 24.04)
- Swift 6.0 or later
- A C compiler and `pkg-config`
- `libx11-dev`, `libfreetype-dev`, `libfontconfig-dev`
- An X display for `cider run` (`Xvfb` is fine)

```sh
sudo apt install build-essential pkg-config libx11-dev libfreetype-dev libfontconfig-dev
```

`cider doctor` checks every one of these and names the package to install if one
is missing.

## Building Cider

```sh
git clone <this repository>
cd cider
swift build
swift test
```

The CLI lands at `.build/debug/cider`. To use it as `cider`:

```sh
export PATH="$PWD/.build/debug:$PATH"
```

## Hello world

```sh
cd examples/hello-cider
cider doctor
cider run
```

With no graphical session:

```sh
Xvfb :99 -screen 0 1280x1024x24 &
export DISPLAY=:99
cider run
```

The application is twenty lines:

```swift
import CiderUI

@main
struct HelloCiderApp: CiderApp {
    @CiderState private var count = 0

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Cider Demo")
                .font(size: 28, weight: .bold)

            Button("Press Me") {
                count += 1
            }

            Text("Count: \(count)")
        }
    }
}
```

Useful flags:

```sh
cider run --log-level debug   # trace what the runtime is doing
cider run --inspect           # print the UI tree on every rebuild
cider run --no-build          # launch what is already built
cider build --configuration release
```

## Architecture

The dependency direction is enforced by the target graph in `Package.swift`:

```
Application  (examples/hello-cider)
     ↓
Compatibility layer  (compatibility/  →  CiderUI)
     ↓
Runtime core  (runtime/  →  CiderRuntime)
     ↓
Abstract host interfaces  (host/  →  CiderHost)
     ↓
     ├── Linux backend    (host/linux/    →  CiderHostLinux)
     ├── Testing backend  (host/testing/  →  CiderHostTesting)
     └── Windows backend  (host/windows/  →  not yet written)
```

Rendering runs entirely in shared code:

```
Swift view values  →  UI tree  →  layout  →  render tree  →  Canvas  →  host window
```

A backend supplies a window, a place to put pixels, an event queue, and glyph
coverage masks. It never draws. That is what keeps output identical across hosts
and makes visual baselines reviewable.

Exactly one module — `CiderHostBootstrap` — is allowed to name a concrete
backend.

Decisions and their alternatives are recorded in
[`docs/adr/`](docs/adr/README.md).

## Repository layout

| Path | Contents |
| --- | --- |
| `cli/` | The `cider` executable. Links no backend, by design. |
| `compiler-support/` | Project discovery, manifest parsing, build orchestration. |
| `compatibility/` | `CiderUI` — the API applications are written against. |
| `runtime/` | `CiderCore` (shared primitives) and `CiderRuntime` (lifecycle, event loop, invalidation). |
| `ui/` | Normalized UI tree, layout engine, render tree, rasterizer. |
| `host/` | Abstract host interfaces, backend selection, and per-platform backends. |
| `device-profiles/` | Deterministic virtual-device descriptions. |
| `inspector/` | Textual dumps of runtime state. |
| `examples/` | Reference applications. |
| `tests/` | `unit/`, `conformance/`, `integration/`, `visual/`. |
| `docs/` | Charter, requirements, architecture, compatibility spec, roadmap, testing, legal boundaries, ADRs. |

## Testing

```sh
swift test                                  # everything
swift test --filter CiderConformanceTests   # the compatibility contract
```

Conformance tests carry stable identifiers. Those identifiers are what a
compatibility claim will eventually cite, so they are not renamed once
published:

| ID | Behaviour |
| --- | --- |
| `APP-LAUNCH-001` | An application launches and presents a first frame. |
| `UI-TEXT-001` | Text renders with the right content, in the right place. |
| `UI-VSTACK-001` | A stack stacks and aligns its children. |
| `UI-BUTTON-001` | A button draws a background, a label and a hit region. |
| `INPUT-POINTER-001` | A pointer becomes a touch, and a touch hit-tests. |
| `STATE-UPDATE-001` | A button action changes state, and the next frame shows it. |

Visual baselines are re-recorded deliberately:

```sh
CIDER_UPDATE_BASELINES=1 swift test --filter CiderVisualTests
```

A recording run fails on purpose. Read the diff before committing it.

## Current limitations

This is Stage 0. The list is long and honest:

- **UI**: `Text`, `Button` and `VStack` only. No images, scrolling, text input,
  lists, navigation or modals.
- **Layout**: no constraints, no text wrapping, no frame or padding modifiers.
  The root centres one node in the safe area.
- **Text**: one line, left to right, with kerning. No bidirectional reordering
  and no complex-script shaping — Arabic, Devanagari and Thai render
  incorrectly.
- **Services**: no networking, storage, timers or clipboard. The manifest's
  permissions are parsed and carried, and nothing enforces them yet because
  nothing uses them. Each application does get an isolated, per-app data root
  on disk (`cider run` creates it before launch), but nothing reads or writes
  into it until storage lands in Stage 3.
- **Lifecycle**: launch, foreground and termination. Backgrounding is modelled in
  the type but has no transitions into it.
- **Rendering**: full redraw on every change, CPU only. No animation, no dirty
  rectangles.
- **Device profiles**: one, `phone-standard`, portrait, scale 1.
- **Platform**: Linux and X11 only. No Wayland backend, no Windows backend.
- **Compatibility registry**: not built. No API in Cider currently carries a
  compatibility level.

## Roadmap

Full detail in
[`docs/05-implementation-roadmap.md`](docs/05-implementation-roadmap.md).

| Stage | Goal | State |
| --- | --- | --- |
| 0 | Prove the architecture end to end | **done** |
| 1 | Runtime skeleton: CLI, manifest, lifecycle, profiles, logging, sandbox, CI | **done** |
| 2 | UI MVP: images, scrolling, text input, lists, navigation, modals | next |
| 3 | Services: HTTP, preferences, storage, timers, clipboard | |
| 4 | Developer experience: compatibility scanner, inspector, hot loop | |
| 5 | Alpha: packaging, versioned compatibility contract, 10+ reference apps | |
| 6 | Windows backend | |

Explicitly deferred: App Store binaries, iOS firmware, hardware-faithful
emulation, DRM, signing bypass, Secure Enclave.

## Contributing

Cider is pre-alpha and **not yet open for outside contributions** — the
repository has no license selected, so there is nothing for a contributor to
agree to. See [`LICENSE-TODO.md`](LICENSE-TODO.md).

[`CONTRIBUTING.md`](CONTRIBUTING.md) describes the standards that will apply, and
is worth reading before proposing anything.

## Security

Report vulnerabilities as described in [`SECURITY.md`](SECURITY.md). Please do
not open a public issue for a security problem.

## Disclaimer

Cider is an independent project. It is **not affiliated with, endorsed by, or
sponsored by Apple Inc.**

*Apple, iOS, iPhone, iPad, UIKit, SwiftUI, Xcode and App Store are trademarks of
Apple Inc.* They are used here only descriptively, to say what Cider is
compatible with and what it is not. Cider ships no Apple code, frameworks,
firmware, fonts or assets, and requires none.

Passing Cider's conformance suite means an application matches Cider's own
documented behaviour. It certifies nothing about Apple hardware or Apple's
simulator.
