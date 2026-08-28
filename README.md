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

> **Status: pre-alpha.** Stages 0-4 of the roadmap now have an implemented and
> smoke-verified MVP: a Swift application launches through the Cider CLI into a
> sandboxed, CI-verified runtime; its UI can use text, buttons, stacks, images,
> scrolling, text input, lists, navigation and modals; and project-owned service
> APIs cover HTTP, preferences, sandboxed files, timers, environment values,
> clipboard and lifecycle simulation. Stage 4 developer-experience work includes
> the text commands plus `cider dev`, a loopback-only graphical developer console
> with structured runtime inspector snapshots, file-watching rebuild/relaunch,
> request capture for `CiderHTTP`, and a sandbox browser. Stage 5 alpha-readiness
> work has started with contract/policy/docs inventory via `cider alpha-readiness`;
> public alpha is not complete yet.

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
- **`cider scan`** — scans project Swift sources against the compatibility
  registry and reports recognized unsupported APIs with actionable diagnostics.
- **`cider compatibility-docs`** — generates the published compatibility-registry
  markdown table from the same registry the scanner uses.
- **`cider inspect`** — prints a project manifest, sandbox, permission and
  compatibility-scan summary.
- **`cider network`** — shows network permission state and literal `CiderHTTP`
  URL call sites.
- **`cider storage`** — lists files currently present in the app sandbox data
  root.
- **`cider init`** — creates a minimal Cider app template.
- **`cider dev-loop`** — prints the optimized `swift build` plus
  `cider run --no-build` iteration loop.
- **`cider alpha-readiness`** — reports Stage 5 public-alpha gate status against
  the current checkout.
- **`cider dev`** — starts the local Stage 4 developer console on
  `127.0.0.1`: graphical inspector, file-watching rebuild/relaunch,
  `CiderHTTP` request capture, sandbox browser and event timeline.
- **`cider build`** — locates the project, validates its manifest, compiles
  through SwiftPM, and reports the runnable artifact.
- **`cider run`** — builds if needed, resolves a device profile, opens a
  virtual-device window, runs the application, and shuts down cleanly.
- **A declarative Swift API** — `CiderApp`, `CiderView`, `Text`, `Button`,
  `VStack`, `Image`, `ScrollView`, `TextField`, `List`, `NavigationView`,
  `Modal`, `@CiderState`.
- **A normalized UI tree** with stable identity, a two-pass layout engine,
  clipping, and a portable software rasterizer with antialiased rounded
  rectangles.
- **A locked Cider visual direction** applied to Stage 2 defaults: near-black
  surfaces, warm-white text, and amber accents from `docs/Cider_DESIGN.md`.
- **A Linux backend** over X11 and FreeType, behind abstract host
  interfaces — pointer, scroll and keyboard input.
- **A headless backend** used by the test suites, so conformance and visual tests
  need no display.
- **Stage 3 application services**: permission-checked HTTP, preferences,
  documents/cache/temp text storage, one-shot timers, environment values,
  process-local clipboard, and foreground/background lifecycle simulation.
- **A sandboxed, per-app data root** and redacted logging, and CI that
  builds and tests every push on the Ubuntu/Swift matrix
  `docs/06-testing-strategy.md` specifies.
- **219 tests** across unit, conformance, integration and visual-regression
  suites, plus `scripts/validate-stages3-4.sh` for Xvfb-backed Stage 3/4 smoke
  validation.

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

Useful commands and flags:

```sh
cider run --log-level debug   # trace what the runtime is doing
cider run --inspect           # print the UI tree on every rebuild
cider run --no-build          # launch what is already built
cider build --configuration release
cider alpha-readiness         # inspect Stage 5 public-alpha gates
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
| `UI-IMAGE-001` | An image lowers to an `ImageNode` and draws at its intrinsic size. |
| `UI-SCROLL-001` | A scroll view clips its content, and scrolling moves it, clamped. |
| `UI-TEXTFIELD-001` | A text field gains focus on tap and edits its bound state. |
| `UI-LIST-001` | A list's rows keep source order and scroll like a scroll view. |
| `NAV-PUSH-001` | A navigation view lowers to a nav stack and pushes screens. |
| `NAV-POP-001` | Popping a navigation stack returns to the screen underneath. |
| `UI-MODAL-001` | A modal dims and overlays base content, and blocks taps to it. |
| `ENV-VALUES-001` | Runtime environment values are visible to application code. |
| `STORE-PREF-001` | Preferences persist values inside the app sandbox. |
| `STORE-FILE-001` | Documents/cache/temp text files are scoped to the sandbox. |
| `CLIPBOARD-001` | The development clipboard stores text for the running app. |
| `TIMER-001` | One-shot timers run application code after their interval. |
| `LIFE-BG-001` | Foreground/background lifecycle transitions can be simulated. |
| `NET-HTTP-001` | HTTP requests enforce manifest network permission. |

Visual baselines are re-recorded deliberately:

```sh
CIDER_UPDATE_BASELINES=1 swift test --filter CiderVisualTests
```

A recording run fails on purpose. Read the diff before committing it.

## Current limitations

This is a Stage 4 MVP. The list is still long and honest:

- **UI**: `Text`, `Button`, `VStack`, `Image`, `ScrollView`, `TextField`,
  `List`, `NavigationView` and `Modal`. No image decoding (an `Image` is
  already-decoded pixels — see `ImageSource`'s doc comment — not a PNG/JPEG
  loaded from a file), no list virtualization, no partial-height modal
  sheets (a presented `Modal` is always full-screen), and no full XIM/IME
  composed text on the real X11 backend. Basic keymap text now flows through
  XLookupString-backed `HostEvent.textInput`; Backspace remains raw-key handling.
- **Layout**: no constraints, no text wrapping, no frame or padding
  modifiers. The root either centres one node in the safe area (most node
  kinds) or fills it (`NavigationView`, `Modal`) — see
  `LayoutEngine.layoutCentered`'s doc comment.
- **Text**: one line, left to right, with kerning. No bidirectional reordering
  and no complex-script shaping — Arabic, Devanagari and Thai render
  incorrectly.
- **Services**: the Stage 3 APIs are intentionally small and project-owned, not
  Foundation/UIKit-compatible facades. Storage is UTF-8 text only, preferences
  are string values, clipboard is process-local, timers are one-shot, and the
  REST-client example currently uses a blocking GET path because Cider does not
  yet have an event-loop-friendly async task API. HTTP permission enforcement,
  async GET, and the blocking demo GET path all have deterministic loopback
  conformance coverage.
- **Lifecycle**: launch, foreground, simulated background and termination. There
  are no OS-driven background deadlines or suspension semantics.
- **Rendering**: full redraw on every change, CPU only. No animation, no dirty
  rectangles.
- **Device profiles**: one, `phone-standard`, portrait, scale 1.
- **Platform**: Linux and X11 only. No Wayland backend, no Windows backend.
- **Compatibility tooling / DX**: a first compatibility registry powers
  `cider scan`, `cider compatibility-docs`, `cider inspect`, `cider network`,
  `cider storage`, `cider init`, and `cider dev-loop`; `cider dev` adds the
  graphical local console, file-watching rebuild/relaunch, request capture and
  rich sandbox browser. The scanner is token-based, not a Swift parser, so it is
  useful early warning machinery rather than a complete source-compatibility
  analyzer.

## Roadmap

Full detail in
[`docs/05-implementation-roadmap.md`](docs/05-implementation-roadmap.md).

| Stage | Goal | State |
| --- | --- | --- |
| 0 | Prove the architecture end to end | **done** |
| 1 | Runtime skeleton: CLI, manifest, lifecycle, profiles, logging, sandbox, CI | **done** |
| 2 | UI MVP: images, scrolling, text input, lists, navigation, modals | **done** |
| 3 | Services: HTTP, preferences, storage, timers, clipboard | **MVP done** |
| 4 | Developer experience: scanner, graphical inspector, hot reload, request capture, sandbox browser | **closed** |
| 5 | Alpha: packaging, versioned compatibility contract, 10+ reference apps | next |
| 6 | Windows backend | |

Explicitly deferred: App Store binaries, iOS firmware, hardware-faithful
emulation, DRM, signing bypass, Secure Enclave.

## Contributing

Cider is pre-alpha but licensed under [Apache-2.0](LICENSE) (third-party
attribution in [`NOTICE`](NOTICE)). [`CONTRIBUTING.md`](CONTRIBUTING.md)
describes the standards that apply, and is worth reading before proposing
anything.

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
