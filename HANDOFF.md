# Handoff

Persistent state for the "Close Stage 1, ship Stage 2" implementation plan
(saved at plan time as `/root/.claude/plans/creat-a-plan-to-parallel-castle.md`
in the planning session; the milestone IDs below refer to that plan's
sections). Read this in full before starting a milestone. Update it —
Status, Done, Deviations, Open issues, Conformance IDs — before ending a
session, whether or not the milestone finished.

## Status

**This original Stage 1/2 plan is complete; Stage 3 services and Stage 4
developer-experience are closed at MVP scope; Stage 5 alpha-readiness is now
closed at tag `v0.1.0-alpha.0`, with installation packaging explicitly
accepted as an alpha caveat rather than closed in code — see
`RELEASE_NOTES.md`.** Every original milestone (Part A, B1-B9) is
implemented, pushed, and confirmed green on CI — Stage 1 is closed and Stage 2
(UI MVP) is done. The Stage 3/4 continuation closed the verification
gap: Notes and REST-client reference apps are built and smoke-run under `cider
run`/Xvfb through the real X11 backend, the Stage 4 contributor flow is covered
end to end, and `scripts/validate-stages3-4.sh` records that repeatable
validation path.

**Correction to a stale note:** the previous version of this section said the
Stage 5 alpha-readiness slice (commit `d59548c`, "feat: start Stage 5 alpha
readiness") was "not yet pushed or CI-confirmed." That was wrong by the time
this continuation started — `d59548c` was already on `origin/main` and CI run
`33131811903` had already passed. Flagging the miss here rather than quietly
fixing it, per this file's own stated practice of recording deviations.

Note: `swift` is not installed on the host, so local verification for these
continuations used the same Swift 6.0 Noble Docker path as CI. Older Done entries
that cite CI still rest on GitHub Actions results; the latest local entries rest
on the Docker commands recorded below until they are pushed and CI runs.

**Latest continuation (Stage 5 closure):** Closed every Stage 5 gate the
project's own completion rule (`docs/stage5-alpha-readiness.md`) allows to
close in code, and explicitly accepted the one that can't (installation
packaging — signed archives / package-manager distribution need real release
infrastructure this session can't stand up). Concretely:

- `compiler-support/Sources/CiderProject/AlphaReadiness.swift`: gates 2-6
  (compatibility contract, security reporting, contribution policy,
  known-issues database, performance baseline) gained real `.done` branches
  — content checks against `RELEASE_NOTES.md`, `SECURITY.md`,
  `LICENSE`/`CONTRIBUTING.md`, `docs/known-issues.md`, and
  `docs/performance-baseline.md` respectively. Gate 1 (packaging) is
  deliberately left with no `.done` path — see the comment on it in the
  source. `tests/unit/AlphaReadinessTests.swift` gained a new test
  (`testAlphaReadinessGatesReachDoneWhenEvidenceIsRecordedButPackagingStaysPartial`)
  asserting gates 2-6 reach `.done` while gate 1 stays `.partial` even in a
  maximally-complete fixture.
- Licensed the repository under Apache-2.0 (`LICENSE`, `NOTICE` for the
  FreeType/libX11/fontconfig attribution `LICENSE-TODO.md` had flagged),
  removed `LICENSE-TODO.md`, and opened `CONTRIBUTING.md`/`README.md`
  accordingly.
- Enabled GitHub private vulnerability reporting on `bud-diaz/cider`
  (`gh api -X PUT /repos/bud-diaz/cider/private-vulnerability-reporting`)
  and documented it as the `SECURITY.md` contact channel.
- Added six new narrow-scope reference apps under `examples/`, bringing the
  total to 10: `nav-list-cider`, `form-input-cider`, `image-loading-cider`,
  `modal-presentation-cider`, `timer-clipboard-cider`, `lifecycle-cider`.
  Each reuses existing conformance coverage rather than adding new node
  kinds, matching how `notes-cider`/`rest-client-cider` didn't need new IDs
  either. `docs/02-product-requirements.md` §5 now names all 10.
- **Added real application-facing lifecycle hooks**, not just examples:
  `RuntimeApplication.didEnterBackground()`/`didEnterForeground()`
  (`runtime/Sources/CiderRuntime/Application.swift`, called from
  `ApplicationRuntime.enterBackground()`/`enterForeground()`) and matching
  `CiderApp` protocol requirements with no-op defaults
  (`compatibility/Sources/CiderUI/CiderApp.swift`), forwarded through
  `CiderAppAdapter`. Before this, `ApplicationRuntime.enterBackground()`/
  `enterForeground()` (Stage 3) changed runtime state but nothing called
  into application code when they fired. New conformance test `LIFE-BG-002`
  in `tests/conformance/Stage3ServiceTests.swift` proves the hooks actually
  fire, using a new `LifecycleProbeApp`/`LifecycleFlagBox` fixture.
  `examples/lifecycle-cider` demonstrates the hooks, but see Open issues —
  nothing in `cider run` itself drives the transition yet.
- Expanded CI (`.github/workflows/ci.yml`) to matrix over two Ubuntu LTS
  releases: `runs-on`/`container` now vary by a new `ubuntu` matrix
  dimension (`ubuntu-24.04`/`swift:*-noble`, `ubuntu-22.04`/`swift:*-jammy`),
  doubling the job count to 8. Verified both containers build and pass all
  223 tests.
- Measured and recorded real numbers in `docs/performance-baseline.md`
  (build/test times, per-example build times, a coarse `cider run`
  startup-to-first-frame proxy, conformance-suite render/update timings, and
  `scripts/validate-stages3-4.sh`'s wall time), replacing the "not yet
  published" placeholder. Measured on the `noble` container only; `jammy` is
  verified to build/pass but not separately profiled.
- Tagged `v0.1.0-alpha.0` and added `RELEASE_NOTES.md` documenting the final
  gate table and every accepted caveat, plus a short `CHANGELOG.md` entry.
- Added `scripts/validate-stage5.sh`: builds all 6 new apps, interactively
  smoke-tests `form-input-cider` (type + submit), `modal-presentation-cider`
  (present a sheet), and `nav-list-cider` (push a detail screen) via
  `cider run --no-build --inspect` under Xvfb + `xdotool`, then asserts the
  final `cider alpha-readiness` report has no `missing` gates and exactly
  one `partial` gate (installation packaging).
- `docs/known-issues.md`: closed `CIDER-KI-0006` (reference app count) and
  `CIDER-KI-0008` (security contact); added `CIDER-KI-0009` (lifecycle hooks
  have no interactive trigger) and `CIDER-KI-0010` (`CiderTimer` callbacks
  run off the render thread, surfaced while building
  `examples/timer-clipboard-cider` — the closure had to capture
  `nonisolated(unsafe)` to satisfy Swift 6 strict concurrency against
  `CiderState`, which is not `Sendable`).

Verification in Swift 6.0 Noble Docker (mounted at `/home/bud/cider`): root
`swift build`/`swift test` passed (223/223, debug and release); the same
passed in `swift:6.0-jammy`; all 10 `examples/*` packages built individually
(`timer-clipboard-cider` needed the `nonisolated(unsafe)` fix above to
compile under Swift 6 strict concurrency); `swift test --filter
AlphaReadinessTests` passed 3/3; `swift test --filter Stage3ServiceTests`
passed 12/12 including `LIFE_BG_002`; `.build/debug/cider alpha-readiness
--path /home/bud/cider` reported 7 gates `done` and exactly 1 `partial`
(installation packaging); `scripts/validate-stages3-4.sh` and the new
`scripts/validate-stage5.sh` both passed.

**Latest continuation (Stage 5 alpha-readiness slice):** Started Stage 5 without
overclaiming public alpha completion. Added `AlphaReadinessReport` in
`compiler-support/Sources/CiderProject/AlphaReadiness.swift` and the CLI command
`cider alpha-readiness`, which publishes alpha version `0.1.0-alpha.0`,
compatibility contract `0.1`, and a gate-by-gate report for the Stage 5 roadmap
requirements. Added `tests/unit/AlphaReadinessTests.swift` for gate status,
reference-app counting, and Ubuntu CI detection. Added docs for the versioned
alpha contract (`docs/alpha-compatibility-contract.md`), source install and
packaging status (`docs/install.md`), known issues (`docs/known-issues.md`),
performance-baseline commands (`docs/performance-baseline.md`), and readiness
interpretation (`docs/stage5-alpha-readiness.md`), and linked them from
`docs/README.md`/`README.md`. Updated `SECURITY.md` to reflect the current Stage 3
service permission model and the now-existing loopback-only dev console.
Verification in Swift 6.0 Noble Docker: focused `AlphaReadinessTests` passed 2/2;
`swift build` passed; `.build/debug/cider alpha-readiness --path /home/bud/cider`
reported every Stage 5 gate as partial with 4 reference apps and Ubuntu 24.04 CI;
root `swift test` passed 221/221; `scripts/validate-stages3-4.sh` passed.

**X11 backend caveat updated by the Stage 3/4 closure:** CI's `swift build` and
`swift test` compile the X11 C shim but most automated behavior still uses the
headless `TestingHostBackend`. The Stage 3/4 smoke script now also launches real
X11 windows under Xvfb and drives them with `xdotool`, so basic pointer clicks,
keymap text input, save/load interaction, and a REST-client GET have been
exercised through the Linux backend. The backend now emits XLookupString-backed
`HostEvent.textInput` for basic text and keeps raw `keyDown` for controls such as
Backspace. Full XIM/XIC/IME composition is still not implemented.

**Latest continuation (Stage 3/4 MVP closure):** Finished the remaining MVP-scope
Stage 3 and Stage 4 work. The Linux X11 backend now converts basic keymap text
with `XLookupString` into `HostEvent.textInput`, and the runtime consumes
`textInput` by appending to the focused `TextField`; raw key events remain for
Backspace/control handling. `CiderHTTP.getBlocking` now uses `URLSession` so the
REST-client demo preserves real HTTP status codes instead of returning status 0.
`cider init` now writes a package dependency pointing at the active Cider checkout
when invoked from the repo, so newly created templates can actually build and run
as part of the contributor flow. Added `scripts/validate-stages3-4.sh`, which
builds and smoke-runs the Notes and REST-client reference apps under Xvfb with
`xdotool`, then validates the Stage 4 flow: init, clean scan, inspect, network,
storage, dev-loop, compatibility-docs, template build/run/click, `cider dev
--once`, and unsupported-API scanner diagnostics. Verification in Swift 6.0 Noble
Docker: focused Stage 3/TextField/template tests passed; `scripts/validate-stages3-4.sh`
passed.

**Previous continuation (Stage 3 HTTP deterministic coverage):** Closed the Stage 3
HTTP real-I/O verification gap for the service MVP. `tests/conformance/Stage3ServiceTests.swift`
now includes a deterministic one-request loopback HTTP/1.1 fixture that binds to
`127.0.0.1` on an OS-assigned port, records the requested path, and returns a
fixed JSON body. `NET-HTTP-001` now covers both permission denial before network
access and a real local `CiderHTTP.get` response path when `permissions.network`
is granted. Verification was run in the Swift 6.0 Noble Docker environment:
focused `Stage3ServiceTests.testNET_HTTP_001_httpReturnsLoopbackResponseWhenNetworkIsGranted`
passed, root `swift test` passed 217/217, and root `swift build` passed.

**Previous continuation (Stage 4 graphical developer-experience closure):** Added
`cider dev`, a loopback-only browser developer console that prepares `.cider/dev`,
serves dashboard routes from a small local HTTP server, exposes structured
inspector snapshots, file-watching rebuild/relaunch orchestration, request capture
records for `CiderHTTP`, a sandbox browser/reset API, and a dev event log. The
runtime can now persist JSON inspector snapshots when launched with inspector
metadata, and `CiderHTTP` can route through the dev capture proxy when the launch
descriptor supplies one. Added focused unit coverage for inspector snapshots,
dev workspace/server routes, file watching, sandbox browsing, and request-header
redaction, plus `scripts/validate-stage4-dev.sh` for Stage 4 smoke validation.

**Latest continuation (Stage 4 developer-experience MVP completion):** Added
text-first MVP command coverage for the rest of Stage 4. The new
`compiler-support/Sources/CiderProject/DeveloperExperience.swift` helpers produce
project inspection reports, network call-site reports, storage sandbox listings,
project templates, and a fast dev-loop plan. The CLI now exposes these via
`cider inspect`, `cider network`, `cider storage`, `cider init`, and
`cider dev-loop` in `cli/Sources/cider/DevToolsCommands.swift`, alongside the
already-added `cider scan` and `cider compatibility-docs` commands.

Added `tests/unit/DeveloperExperienceTests.swift` for the new helper layer:
inspector summary, network URL discovery, storage file listing, template
creation, and `run --no-build` dev-loop planning. Updated `README.md`,
`docs/04-compatibility-specification.md`, and
`docs/05-implementation-roadmap.md` to mark Stage 4 as text-first MVP done while
being explicit that this is not a graphical inspector or live file-watching IDE
integration. Verification was run in the Swift 6.0 Noble Docker environment:
`swift test` passed 206/206, and the built CLI was smoke-tested for `inspect`,
`network`, `storage`, `dev-loop`, and `init`.

**Previous continuation (Stage 4 compatibility documentation generator):** Extended
the Stage 4 registry slice with `CompatibilityDocumentation.markdown()` and the
CLI command `cider compatibility-docs`, including `--output <file>` support. The
command renders the same `CompatibilityRegistry` data used by `cider scan`, so the
published compatibility table does not drift into a second hand-maintained source
of truth. Generated and checked in `docs/compatibility-registry.md`, linked it
from `docs/README.md`, and updated `README.md` / `docs/04-compatibility-specification.md`
to document the command. Verification was run in the Swift 6.0 Noble Docker
environment: the new documentation-generator unit test passed, full `swift test`
passed 201/201, and `cider compatibility-docs` was verified both to stdout and to
an output file.

**Previous continuation (Stage 4 developer experience scanner slice):** Added a
first explicit compatibility registry and source scanner in
`compiler-support/Sources/CiderProject/Compatibility.swift`. The registry records
supported, supported-with-differences, and recognized-unsupported symbols with
compatibility levels/domains/guidance; the scanner emits structured `CID0605`
warning diagnostics for recognized unsupported APIs such as SwiftUI/UIKit,
URLSession, StoreKit/Product, Camera, and CoreData. It scans `.swift` source
files while skipping comments, string literals, and generated/build directories
such as `.build`, `.git`, `.cider`, and `DerivedData`. This is intentionally a
token-based early-warning scanner, not a full Swift parser.

Added the CLI command `cider scan` in `cli/Sources/cider/ScanCommand.swift`, wired
it into the command dispatcher and help text, and documented it in `README.md`
and `docs/04-compatibility-specification.md`. Added unit coverage in
`tests/unit/CompatibilityScannerTests.swift` for clean supported CiderUI source,
actionable unsupported-API diagnostics, comment/string ignoring, project scanning
outside build artifacts, and stable registry entries. Verification was run in the
Swift 6.0 Noble Docker environment: the new scanner tests passed, root
`swift test` passed 200/200, and `cider scan` passed for `examples/ui-showcase`,
`examples/notes-cider`, and `examples/rest-client-cider`.

**Previous continuation (Stage 3 application services MVP):** Added the first
Stage 3 service surface in `compatibility/Sources/CiderUI/Services.swift`:
`CiderEnvironment`, `CiderPreferences`, `CiderStorage`, `CiderClipboard`,
`CiderTimer`, and `CiderHTTP`. Services are project-owned Cider APIs rather than
Foundation/UIKit facades, and they enforce the existing manifest permissions at
use sites (`CID0601` for local storage, `CID0604` for network). Preferences and
Documents/Cache/tmp storage are sandbox-root scoped; storage paths reject absolute
and parent-traversing names (`CID0603`). `ApplicationRuntime` now exposes
`enterBackground()` / `enterForeground()` for lifecycle simulation, and the
compatibility adapter attaches/detaches the active service context at launch and
termination.

Added conformance coverage in `tests/conformance/Stage3ServiceTests.swift` for
`ENV-VALUES-001`, `STORE-PREF-001`, `STORE-FILE-001`, `CLIPBOARD-001`,
`TIMER-001`, `LIFE-BG-001`, and `NET-HTTP-001`. Added two Stage 3 reference
apps: `examples/notes-cider` (preferences + documents storage + clipboard) and
`examples/rest-client-cider` (permissioned HTTP + cache + clipboard). Updated
`README.md` to mark Stage 3 as MVP done and record the remaining service caveats.
Verification was run in the Swift 6.0 Noble Docker environment: `swift test`
passed 195/195, and `swift build` passed for every `examples/*` package.

**Previous continuation (brand/design Stage 2 update):** Reviewed
`docs/Cider_DESIGN.md` and `docs/Cider Branding.md`, normalized their markdown
formatting, added them to the docs index, and applied the locked brand palette to
Stage 2 defaults. `Theme` now exposes the canonical Cider tokens (`#10100F`,
`#1C1C1A`, `#242421`, `#34342F`, `#8F8D86`, `#F5F1E8`, `#E89A2F`, `#FFB547`)
and uses near-black surfaces, warm-white text, and amber controls instead of the
previous generic light/blue palette. `ApplicationRuntime.backgroundColor` is kept
in sync as a plain `CiderCore.Color` because `CiderRuntime` cannot import
`CiderUI`. Added conformance ID `STYLE-BRAND-001` to lock the MVP brand tokens,
updated the Stage 2 showcase image to amber, and re-recorded visual baselines.

**Previous continuation (visual baselines):** Stage 2 primitive visual baselines
have now been added and verified in `tests/visual/VisualRegressionTests.swift`:
`image-screen`, `scroll-view-screen`, `text-field-focused-screen`,
`list-screen`, `navigation-screen`, and `modal-presented-screen`. Baselines were
recorded in the Swift 6.0 Noble Docker environment and visually spot-checked via
a contact sheet (no obvious blank/garbled renders). Verification run:
`swift test --filter CiderVisualTests` passed 12/12. CI-equivalent root
`swift build`/`swift test` passed for debug and release in the same container
(186 tests in each configuration after the brand-token conformance case was
added). Example app builds also passed for `examples/hello-cider` and
`examples/ui-showcase` in debug and release when the repo was mounted at
`/home/bud/cider` (matching the normal checkout basename;
mounting at `/workspace` makes SwiftPM identify the path dependency as
`workspace`, which breaks examples that name package `Cider`).

**Remaining caveat:** B9's Stage 2 showcase app (`examples/ui-showcase`) remains
outside the Stage 3/4 closure scope. It is build-verified and its primitives are
covered by conformance/visual tests, but it still has not had a full human UX
tap-through pass under `cider run`.

## Done

- **A1** — `.github/workflows/ci.yml`: Ubuntu 24.04 container
  (`swift:6.0-noble`), matrix over debug/release, installs the documented
  apt packages, starts Xvfb, runs `swift build`/`swift test` per
  configuration.
- **A2** — sandbox data roots + log redaction:
  - `SandboxPaths` (`runtime/Sources/CiderCore/SandboxPaths.swift`):
    Foundation-free struct naming `documents`/`cache`/`temporary` under a
    root string.
  - `SandboxPathResolver` (`compiler-support/Sources/CiderProject/SandboxPathResolver.swift`):
    resolves `$XDG_DATA_HOME/cider/apps/<appID>` (falling back to
    `~/.local/share/...`), validates `appID` via
    `ManifestParser.isValidAppID` before touching the filesystem, creates
    `Documents`/`Cache`/`tmp` under it. `dataRoot`/`prepare` both take an
    `environment: [String: String]` override parameter so tests don't
    touch real process environment.
  - `LaunchDescriptor.sandboxDataRoot: String` (default `""`) carries the
    resolved root from `RunCommand` to the app process; `RuntimeContext.sandbox: SandboxPaths?`
    is `nil` when empty (i.e. binary not started through `cider run`).
  - `LogRedaction.redact(_:)` + `RedactingLogSink`
    (`runtime/Sources/CiderCore/LogRedaction.swift`): word-scanning
    (no regex, so CiderCore stays Foundation-free) redaction of
    `key=value`/`key: value` pairs whose key looks like a credential, and
    the token after `Bearer`. Wired into `CiderApp.main()` wrapping
    `StandardOutputLogSink`.
  - Tests: `tests/unit/SandboxPathResolverTests.swift`,
    `tests/unit/LogRedactionTests.swift`, an added round-trip case in
    `tests/unit/LaunchDescriptorTests.swift`, and an end-to-end check in
    `tests/integration/ProjectIntegrationTests.swift`
    (`testTheSandboxRootPreparedByRunReachesTheApplication`).
  - `README.md` roadmap table and "Current limitations" updated to match.

- **B1** — Image node, all five ADR-0003 touchpoints plus the view type:
  - `ImageSource` (`runtime/Sources/CiderCore/ImageSource.swift`): raw
    RGBA8 pixels (width/height/bytes), plus a `.solid(_:width:height:)`
    helper. No decoder exists — this is deliberately the whole story for
    B1, per the plan.
  - `ImageNode` + `UINode.image` case
    (`ui/Sources/CiderUITree/UINode.swift`).
  - `Layout.swift`: `.image` measures to `source.width`/`source.height`
    (points == pixels at scale 1); places like `.text`/`.button` (no
    children, no special sizing logic needed since it's already
    intrinsically sized).
  - `RenderCommand.image(rect:source:)` + builder case
    (`ui/Sources/CiderUITree/RenderTree.swift`).
  - `Rasterizer.draw(image:rect:scale:into:)`
    (`ui/Sources/CiderUITree/Rasterizer.swift`): nearest-neighbour sampling
    from source pixels into canvas device pixels, alpha-composited through
    the existing `Canvas.blend`.
  - `Inspector.swift`: both `describe(node:)` and `describe(renderTree:)`
    switches gained `.image` cases.
  - `Image` view (`compatibility/Sources/CiderUI/Image.swift`): leaf
    `CiderView`, same shape as `Text`.
  - Tests: `UI-IMAGE-001` in `tests/conformance/ConformanceTests.swift`
    (+ `ImageOnlyApp` in `ConformanceHarness.swift`), unit tests in
    `tests/unit/ImageSourceTests.swift` and new cases in
    `tests/unit/LayoutTests.swift`. Visual coverage was added later via
    `VisualRegressionTests.testImageScreen` and the `image-screen.ppm`
    baseline; see the Latest continuation note above.

- **B2** — layout & rendering foundations, both items from the plan:
  - `LayoutEngine.measure` gained `proposedSize: Size? = nil`
    (`ui/Sources/CiderUITree/Layout.swift`). Deliberately inert: no case
    consults it yet (nothing in the current node set shrinks or wraps).
    It's there so B4–B6 are a change confined to the cases that need
    bounded sizing, not a signature change threaded through every call
    site again. Every existing call site compiles unchanged since it's
    defaulted.
  - Clipping: `RenderCommand.pushClip(rect:)` / `.popClip`
    (`ui/Sources/CiderUITree/RenderTree.swift`), a clip stack maintained
    in `Rasterizer.render` (`ui/Sources/CiderUITree/Rasterizer.swift`),
    and `Rect.intersection(_:)` (`runtime/Sources/CiderCore/Geometry.swift`)
    to do the actual intersecting. `fill`/`draw(text:)`/`blit`/`draw(image:)`
    all gained an optional `clip` parameter that clamps their pixel
    bounds. Nothing emits `pushClip`/`popClip` yet — first consumers are
    B4 (scroll viewport) and B8 (modal overlay). `Inspector.describe(renderTree:)`
    got the two new cases.
  - Tests: `tests/unit/GeometryTests.swift` (intersection cases),
    `tests/unit/RasterizerClipTests.swift` (new — exact-pixel assertions
    on push/pop/nesting/unbalanced-pop, no baseline needed since a clip
    rect's effect is small enough to state directly).

- **B3** — host input plumbing:
  - `HostEvent` gained `.scroll(deltaX:deltaY:)`, `.keyDown(keyCode:)`,
    `.keyUp(keyCode:)`, `.textInput(String)`
    (`host/Sources/CiderHost/HostEvent.swift`).
  - `Touch.swift`'s `PointerTranslator.touch(for:)` and
    `ApplicationRuntime.handle(_:HostEvent)`
    (`runtime/Sources/CiderRuntime/`) both gained cases for all four —
    none of them are touches, and none has a consumer yet, so the
    runtime side just traces them and does nothing else (matching B2's
    "inert plumbing ahead of a consumer" pattern).
  - `ApplicationRuntime` gained a `focusedNode: NodeID?` field alongside
    `pressedNode`, with the same "vanished in a rebuild -> cleared"
    safety `pressedNode` already had, and a `currentFocusedNode` public
    accessor. Nothing sets it yet — no node kind accepts focus until B5.
  - X11 shim (`host/linux/Sources/CX11Shim/`): `XSelectInput` now
    requests `KeyPressMask | KeyReleaseMask`; `ButtonPress` for X11
    buttons 4-7 (wheel notches) now emits `CIDER_X11_EVENT_SCROLL`
    instead of being dropped (`ButtonRelease` for 4-7 is still dropped —
    a wheel release carries nothing to report); new `KeyPress`/`KeyRelease`
    cases report the raw keysym via `XLookupKeysym`.
    `X11Window.swift` translates all three into `HostEvent` cases.
  - **Originally deferred, now partially superseded by the Stage 3/4 MVP closure**:
    full `Xutf8LookupString`/XIM/XIC composed text remains deferred, but the X11
    shim now uses `XLookupString` to produce `.textInput` for basic keymap text.
    `TestingHostBackend` can still synthesize arbitrary `.textInput` events for
    tests. See Deviations for the remaining full-IME limitation.
  - Tests: extended `tests/integration/PointerTranslationTests.swift`'s
    non-touch coverage to the four new cases, and added
    `tests/conformance/HostInputPlumbingTests.swift` (unnumbered smoke
    tests, not full `ID-###` conformance cases, since there's no
    application-facing behavior yet to certify) confirming the events
    are accepted without side effects.

- **B4** — ScrollView, all five ADR-0003 touchpoints plus a fix to B3:
  - **Fix to B3**: `HostEvent.scroll` was missing a `location`. Realized
    while designing B4 (routing a wheel notch to the right scroll view
    under the pointer needs a location, the same way a tap does) — X11
    ButtonPress already carries `x`/`y` even for the wheel-notch buttons,
    so this was a small, low-risk addition to the same commit rather than
    amending the already-pushed B3 commit: `HostEvent.scroll(location:deltaX:deltaY:)`,
    the C shim now sets `out->x`/`out->y` in the scroll branch,
    `X11Window.translate` passes them through. See Deviations for why
    this wasn't caught in B3's own review.
  - `ScrollViewNode` (`ui/Sources/CiderUITree/UINode.swift`): explicit
    `viewportSize` + one `content: UINode` child. Explicit size because
    nothing implements "fill the space my parent gives me" yet —
    `layoutCentered`'s own doc comment already flags that as a B7
    problem, not B4's.
  - `Layout.swift`: `.scrollView` measures to `viewportSize` regardless
    of content; places content at its own natural size, at the *same
    origin* as the viewport (the unscrolled reference frame — applying
    an actual scroll offset is a render-tree concern, not layout, same
    reasoning as a button's pressed color).
  - `RenderTree.swift` — the biggest change: `RenderTreeBuilder.append`
    now threads an `offset: Point` (accumulated scroll displacement) and
    a `clip: Rect?` (accumulated viewport intersection) through the
    recursion. `.scrollView` emits `pushClip`/`popClip` around its
    content and offsets the content's subtree by `-scrollOffset`.
    **Important correctness fix caught while writing tests, not part of
    the original plan item**: button hit regions are now intersected
    with the active clip before being added (and skipped entirely if
    fully clipped) — without this, a button scrolled out of view stayed
    tappable at its old, invisible position, because `RenderTree.hitTest`
    doesn't know about the rasterizer's clip stack. Added
    `RenderTree.scrollRegions`/`scrollTarget(at:)`, parallel to
    `hitRegions`/`hitTest` but for "which scroll view is under this
    point" rather than "which button."
  - `ApplicationRuntime.swift`: `scrollOffsets: [NodeID: Point]`
    (pruned on rebuild, same pattern as `pressedNode`/`focusedNode`),
    `scrollNotchDistance` (40pt/notch, analogous to the existing
    `backgroundColor` "hard-coded for the MVP" constants — deliberately
    *not* in `CiderUI.Theme`, since `CiderRuntime` must not depend on
    `CiderUI`), and `handleScroll(at:deltaX:deltaY:)`: hit-tests the
    scroll target, clamps the new offset against the content/viewport
    sizes already sitting in `lastLayout`.
  - `ScrollView` view (`compatibility/Sources/CiderUI/ScrollView.swift`):
    takes an explicit `width`/`height`. Handles the "content builder
    produced 0 or 2+ top-level nodes" case (mirroring what
    `Lowering.scene` already does for an app's body) by wrapping them in
    a synthetic `VStackNode` whose id is `"<id>/wrap"` — a suffix that
    can never collide with a real child's numeric identity — rather than
    reusing the scroll view's own id, which would have made two
    different `UINode`s share one `NodeID`.
  - Tests: `UI-SCROLL-001` (7 cases: lowering, viewport/content sizing,
    clip bracketing, clip-aware hit-testing both ways, clamping at both
    ends) in `tests/conformance/ConformanceTests.swift` +
    `ScrollTestApp` in `ConformanceHarness.swift`; layout measure/place
    cases in `tests/unit/LayoutTests.swift`; the B3 location fix
    propagated into `PointerTranslationTests.swift`.

- **B5** — TextField, all five ADR-0003 touchpoints plus a new
  side-channel and a real editing story:
  - `TextFieldNode` (`ui/Sources/CiderUITree/UINode.swift`): explicit
    `width` (same reasoning as `ScrollViewNode`'s `viewportSize` — no
    "fill parent" layout exists yet). Also added `UINode.find(_:)`, a
    general depth-first lookup by identity — the runtime needs it to
    read a field's *current* text (the tree is the only place that
    value lives, matching the "pure data" model: nothing keeps a
    parallel copy).
  - **New side-channel, parallel to `actions`**: `ApplicationScene`
    (`runtime/Sources/CiderRuntime/Application.swift`) and
    `LoweringContext` (`compatibility/Sources/CiderUI/Lowering.swift`)
    both gained `textInputHandlers: [NodeID: (String) -> Void]` /
    `register(textInputHandler:for:)`, the same shape as
    `actions`/`register(action:for:)`. `CiderState<Value>`'s existing
    `projectedValue` (`$text`) already returns the class instance
    itself, so `TextField($text, width:)` closes over the *same*
    storage the app's `@CiderState` property does — no new binding type
    needed, `CiderState.swift`'s own comment already anticipated this
    ("nothing in the MVP node set takes a two-way binding yet").
  - **Editing is keyDown-only, deliberately, and it actually works on
    real X11 unlike B3's `textInput`.** X11 keysyms for the printable
    ASCII/Latin-1 range are *identical to their Unicode code points* by
    X11's own design — a documented property of the encoding, not
    something specific to this codebase — so `ApplicationRuntime.handleKeyDown`
    maps `keyCode` directly to a `Character` for 0x20...0x7E, handles
    backspace (0xFF08) specially, and ignores everything else. This
    needed no further C shim work: B3's `XLookupKeysym`-based `keyDown`
    is already sufficient. `.textInput` stays unconsumed (see B3's
    Deviations entry) — the doc comment on `handleKeyDown` and on the
    `.textInput` case both flag that a future `Xutf8LookupString`
    implementation must *replace* this path for composed text, not run
    alongside it, or a keystroke could double-insert.
  - Focus: `ApplicationRuntime.handle(_ touch:)`'s `.began` case now
    also sets/clears `focusedNode` based on whether the tapped id is a
    key in `scene.textInputHandlers` — tapping a field focuses it,
    tapping anything else (or empty space) clears focus. Reuses the
    existing `hitRegions`/`hitTest` a button already publishes through,
    rather than adding a third parallel region list the way scroll
    needed its own (`scrollRegions`) — a tap only ever means one of
    "press this" or "focus this", so one hit-test answering "what did
    the tap land on" is enough; the runtime decides which by which
    table the id is in.
  - `RenderTreeBuilder.append` gained a `focusedNode` parameter
    (threaded like `pressedNode`); `.textField` draws a background
    fill, the text (via the same `.text` command everything else
    uses), and — only when focused — a 1pt-wide caret fill after the
    last character. Hit region is clip-aware, same fix as B4's buttons.
  - Tests: `UI-TEXTFIELD-001` (7 cases: lowering, focus follows tap,
    typing, backspace, backspace-on-empty is a no-op, typing while
    unfocused is a no-op, an unmapped key is a no-op) in
    `tests/conformance/ConformanceTests.swift` + `TextFieldTestApp` in
    `ConformanceHarness.swift`; layout measure/place cases and a
    `UINode.find(_:)` case in `tests/unit/LayoutTests.swift`.

- **B6** — List, and it needed *no* UINode/Layout/RenderTree/Inspector
  changes at all, a deliberate deviation from the ADR-0003
  five-touchpoint pattern the plan assumed every node kind would need:
  - `List` (`compatibility/Sources/CiderUI/List.swift`) lowers directly
    to `.scrollView(ScrollViewNode(content: .vstack(rows)))` — a list
    *is* a ScrollView whose content is always a VStack of rows, so
    reusing that machinery outright (rather than a parallel node kind
    with its own clip/scroll/hit-testing logic to keep in sync) is the
    whole implementation. Same "always wrap, `/rows` suffix can't
    collide with numeric row identities" technique `ScrollView` uses
    for its own synthetic wrapper.
  - Row identity is the existing structural index scheme (`id/0`,
    `id/1`, ...) — matches the plan's "index-based identity" and ADR
    0003's explicit note that key-based identity is deferred until
    lists exist; still true now, not addressed here. No virtualization
    either, also per plan: a long list measures and places every row on
    every rebuild, same as a VStack today.
  - A row that wants tap behavior is just a `Button` as that row —
    List adds no new interaction concept, since B4 and B5 already gave
    clip-aware hit-testing and scrolling to whatever's inside a
    ScrollView's content, for free.
  - Tests: `UI-LIST-001` (3 cases: lowering shape, row order,
    scroll-then-tap-the-newly-visible-row reusing B4's clip-aware
    hit-testing) in `tests/conformance/ConformanceTests.swift` +
    `ListTestApp` in `ConformanceHarness.swift`. No unit tests needed
    beyond the conformance suite, since there's no new layout/render
    code path to test in isolation.
  - **CI caught a real test bug (not a production code bug) on the
    first push (db2a5df)**: `testUI_LIST_001_rowsKeepSourceOrder`
    asserted `hitRegions.count == 10` (one per row), but `ListTestApp`'s
    viewport is only 30pt tall against a 36pt row height, so B4's
    clip-aware hit-testing correctly drops every hit region except the
    one row that's actually (partly) visible at launch — the assertion
    itself was wrong, not the code it was testing. Fixed by asserting
    row order via `drawnStrings()` (draw commands aren't clip-filtered,
    only hit regions are) and changing the count assertion to `== 1`
    with an explanation, rather than deleting the coverage. This is the
    first real CI failure this plan has hit — the story for every
    milestone before this was "compiles and passes first try," and it's
    worth flagging that CI is doing real work, not rubber-stamping.
- **B7** — navigation stack, all five ADR-0003 touchpoints plus a real
  root-layout replacement:
  - `NavigationStackNode` (`ui/Sources/CiderUITree/UINode.swift`) holds
    only `content: UINode` — no screen-history array. Which screen is
    active is interaction state, the same reasoning `ButtonNode` carries
    no closure and `TextFieldNode` carries no callback: it lives in
    `CiderState`, on the app, passed down as a `CiderState<[any
    CiderView]>` binding exactly the way `TextField`'s bound text does.
    This sidesteps `CiderAppAdapter.attachState`'s reflection walk only
    covering the app's own stored properties (see its doc comment)
    rather than extending that walk to nested views, which would be a
    bigger, riskier change for no other Stage 2 need.
  - `LayoutEngine.measure`'s `.navigationStack` case is the first
    consumer of B2's `proposedSize` parameter, four milestones after it
    was added inert: `proposedSize ?? measure(content, ...)` — fills
    whatever it's proposed, falls back to the content's intrinsic size
    only if nothing was proposed (e.g. nested inside a non-proposing
    container, not the normal root path). `layoutCentered` now passes
    `proposedSize: bounds.size`, so a navigation-stack root's measured
    size equals `bounds.size` and the existing centring arithmetic
    reduces to placing it flush at the origin — *no* new root-layout
    code path, just feeding the existing one a size that makes it
    degenerate to "fill." Every other node kind still ignores
    `proposedSize` and is unaffected (regression-covered by the
    existing `LayoutTests.swift` cases, unchanged).
  - `RenderTreeBuilder.append`'s `.navigationStack` case is a transparent
    passthrough: no draw command, no clip, just recurses into `content`
    at the same `offset`/`clip` it received. There's nothing to clip
    against — the active screen already fills the whole frame, unlike a
    scroll view's content which can exceed its viewport.
  - `compatibility/Sources/CiderUI/NavigationView.swift` — new view,
    `NavigationView(_ path: CiderState<[any CiderView]>, root:)`, shows
    `path.wrappedValue.last ?? root`. No `NavigationLink` type: push/pop
    are just `path.append(...)`/`path.wrappedValue.removeLast()` inside
    an ordinary `Button` action, the same as any other state mutation.
    Wraps a multi-node screen body the same way `Lowering.scene` wraps
    the app's own top level (a `/screen`-suffixed VStack), for the same
    reason `List`/`ScrollView` wrap their single child.
  - Tests: `NAV-PUSH-001` (3 cases: lowering shape, the active screen
    filling the safe area instead of being centred at its intrinsic
    size, push replaces the screen rather than layering under it) and
    `NAV-POP-001` (2 cases: pop returns to the screen underneath, and a
    push-then-pop cycle returns to the *same structural identity* the
    root had — documented as intentional, matching ADR 0003's existing
    index-based-identity limitation, not a bug) in
    `tests/conformance/ConformanceTests.swift` +
    `NavigationTestApp`/`NavigationDetailScreen` in
    `ConformanceHarness.swift`. Plus `LayoutTests.swift` unit coverage
    for `.navigationStack`'s `measure` (fills a proposed size / falls
    back to intrinsic with none proposed), `place` (content placed at
    the stack's full frame, not its own smaller size) and
    `layoutCentered` (fills bounds for a navigation-stack root instead
    of centring).
- **B8** — modal/presentation surface, reusing B7's "fill via proposedSize"
  and B2's clip primitive rather than adding anything new to either:
  - `ModalPresenterNode` (`ui/Sources/CiderUITree/UINode.swift`) holds
    `content: UINode` (always present) and `presented: UINode?` (nil
    most of the time — the same "no history, just what's-active-right-now"
    shape `NavigationStackNode` uses, `CiderState<Bool>`-backed via a
    binding rather than stored in the tree). It also carries its own
    `overlayColor: Color`, set by the compatibility-layer `Modal` view
    from `Theme.modalOverlayColor` — `RenderTree.swift` lives in the
    `CiderUITree` module, which `CiderUI` (and its `Theme`) *depends on*,
    not the other way around, so the dim colour has to travel on the node
    the same way `ButtonNode.backgroundColor` does, not be looked up by
    name at render time. (First-draft mistake, caught before it was ever
    pushed: tried referencing `Theme.modalOverlayColor` straight from
    `RenderTree.swift` and it doesn't compile — wrong module direction.)
  - `LayoutEngine.measure`'s `.modal` case fills a proposed size exactly
    like `.navigationStack`'s does (`proposedSize ?? measure(content,
    ...)`), for the same reason: without it, an app whose only content is
    a `Modal` would size its base content — and the overlay, which reuses
    that same frame — to the base's own small intrinsic size instead of
    the safe area, and a dim overlay that doesn't cover the screen isn't
    a dim overlay. `presented` never influences the measured size, the
    same reasoning a button's pressed colour doesn't affect its size
    (regression-covered: `testModalMeasureIgnoresPresentedContentEntirely`).
  - `LayoutEngine.place`'s `.modal` case places `content` at the full
    given frame (so a modal-wrapped screen is top-anchored the same way a
    navigation-stack screen is — consistent, not a new inconsistency),
    and, when `presented` exists, places it at that *same* frame — MVP
    scope is a full-screen presentation, not a partial-height sheet,
    which would need bounded-but-smaller-than-container layout this
    pipeline doesn't have.
  - `RenderTreeBuilder.append`'s `.modal` case draws `content` first,
    then — only if presenting — a dim `fillRect` (clip-intersected the
    same way a scroll viewport's frame is) and a `pushClip`/`popClip`
    pair around `presented`, appended after it. Painter's order alone
    gives the right z-order for free, the same way it already does for a
    button's label over its background. The dim overlay also publishes
    an *enabled* `HitRegion` with no registered action — that's what
    stops `hitTest`'s reversed scan from reaching the base content's
    button underneath once something is presented; a `disabled` region
    would have let the scan fall through past it instead.
  - `compatibility/Sources/CiderUI/Modal.swift` — new view,
    `Modal(_ isPresented: CiderState<Bool>, content:, presenting:)`.
    No dismiss action is built in — presented content sets
    `isPresented.wrappedValue = false` itself from an ordinary `Button`,
    the same way `NavigationView`'s pushed screens pop themselves. Base
    and presented content each get their own numbering root
    (`id.child(0)`/`id.child(1)`) rather than sharing `id` the way a
    single-child wrapper like `ScrollView` does — two independent
    `withChildren(of:)` calls against the same parent would otherwise
    hand out colliding paths ("id/0", "id/1", ...) to two different
    views.
  - Plan deviation: the plan's B8 text says "reuses B7's screen-stack
    state shape." Implemented with a plain `CiderState<Bool>` instead —
    a modal has exactly two states (showing or not), not a stack of
    screens, so `[any CiderView]` would carry a stack API for a value
    that's never more than one deep. Simpler, and there is nothing to
    generalize from yet since B9 is the only remaining consumer.
  - Tests: `UI-MODAL-001` (5 cases: lowering shape, nothing-presented
    draws only the base, presenting draws the overlay and presented
    content in the right paint order, a tap on the dimmed area doesn't
    reach the base, dismissing hides the presented content) in
    `tests/conformance/ConformanceTests.swift` +
    `ModalTestApp`/`ModalDetailScreen` in `ConformanceHarness.swift`.
    Plus `LayoutTests.swift` coverage for `.modal`'s `measure` (fills a
    proposed size / falls back to intrinsic / ignores `presented`
    entirely), `place` (content at the full frame, presented at the same
    frame, no second child box when nothing's presented) and
    `layoutCentered` (fills bounds for a modal root instead of
    centring).
- **B9** — reference app + Stage 2 exit criterion:
  - **Found and fixed a real, previously-latent gap while writing the
    reference app, not a test bug**: `CiderCore` (`Color`, `FontRequest`,
    `ImageSource`, ...) was never declared as a library product in the
    root `Package.swift`, and `CiderUI` didn't re-export it either. Every
    prior example (`hello-cider`) only ever used `Text`/`Button`/`VStack`
    with no explicit `Color`/`ImageSource` literal, so nothing had
    exercised this path. The moment B9's reference app tried
    `Image(.solid(Color(hex: ...), ...))` — the first application-level
    use of `Image` anywhere in the repo — it would have failed to
    compile: a downstream SwiftPM package that only depends on the
    `CiderUI` product has no way to `import CiderCore`, since it isn't a
    product at all. Fixed with `@_exported import CiderCore` added to
    `compatibility/Sources/CiderUI/CiderApp.swift`, so `import CiderUI`
    alone brings every CiderCore type its own public API surface
    (`Text.foregroundColor(_:)`, `Image.init(_:)`, ...) already required
    callers to name. `CiderUITree` stays unexported — nothing
    application-facing hands out a `UINode` to name. This would have
    blocked every application author from using `Image` or an explicit
    `Color`, not just this reference app; worth a maintainer's attention
    even though it never leaked into a previously-shipped example.
  - **`examples/ui-showcase/`** — new reference app (Package.swift,
    Cider.yaml, README.md, `UIShowcaseApp.swift`), reusing
    `examples/hello-cider`'s exact shape. One app instead of the four
    separate ones `docs/02-product-requirements.md` §5 lists
    ("navigation/list app", "form/text-input app", "image-loading app",
    "modal/presentation example") — deliberate, matching the plan's own
    phrasing ("reference apps... exercise navigation+list, form/
    text-input, image-loading, and modal/presentation," not "four
    separate apps"), and because each primitive already has isolated
    conformance coverage from B1-B8; the reference app's job is proving
    they compose, which needs one app, not four. Structure: `Modal`
    wraps a `NavigationView` (so "About" can present over *any* pushed
    screen, not just the root); the root is a `List` of items; tapping
    one pushes a detail screen with an `Image` and a `TextField` bound to
    shared state (no per-item storage — that's Stage 3).
  - **CI gap found and fixed alongside it**: `.github/workflows/ci.yml`'s
    `swift build`/`swift test` only ever ran at the repo root — every
    `examples/*` package is an independent SwiftPM package (a path
    dependency on the repo root, the way a real project would use a
    tagged version), so nothing in CI had ever built `hello-cider`
    either, let alone the new app. Added a "Build example apps" step
    that `swift build`s every directory under `examples/`, in both the
    debug and release jobs — the same mechanism that would have caught
    the `@_exported import` gap above automatically, if it had existed
    before this session hit the gap by hand.
  - Visual-regression baselines for the new node kinds were **not**
    recorded during B9, the same reason B1's Image baseline wasn't: no Swift
    toolchain in that session to run `CIDER_UPDATE_BASELINES=1 swift
    test`. Every new primitive did have conformance coverage
    (`UI-IMAGE-001`/`UI-SCROLL-001`/`UI-TEXTFIELD-001`/`UI-LIST-001`/
    `NAV-PUSH-001`/`NAV-POP-001`/`UI-MODAL-001`), which was real,
    CI-enforced test coverage; the pixel-level visual-regression gap was
    closed by the later visual-baselines continuation above.
  - `README.md` — status line, "What works today," "Current
    limitations," the roadmap table (Stage 2 now **done**, Stage 3
    marked **next**) and the conformance-ID table all updated; they had
    drifted since Stage 0 (still read "Text, Button and VStack only" and
    "103 tests" before this).

## Deviations

- The plan suggested putting sandbox path resolution "alongside
  `RuntimeContext`" (CiderCore) or in CiderProject. Went with CiderProject
  for the actual filesystem work (`SandboxPathResolver`, using
  `FileManager`), since CiderCore deliberately has zero Foundation
  dependency (see `StandardStreams.swift`) and CiderRuntime doesn't import
  Foundation either. Only the plain-data `SandboxPaths` struct (root +
  three computed subpaths, no I/O) lives in CiderCore. The resolved root
  crosses the CLI-to-runtime process boundary as a new string field on the
  existing `LaunchDescriptor` wire format, the same way permissions
  already do.
- Log redaction does not use `NSRegularExpression`/Foundation `Regex` —
  implemented as manual word-scanning so it could live in CiderCore next
  to `Logger`. If it turns out to need more sophisticated matching later,
  that's a reason to revisit, not a correctness bug in what's there now.
- `AppPermissions` enforcement itself was explicitly left undone per the
  plan's scoping call — only capability *declaration* + the sandbox root
  exist. This was already true before A2 and remains true; Stage 3's
  services are what will consult `RuntimeContext.permissions`.

- B1's plan item called for "visual regression baseline + conformance
  test `UI-IMAGE-001`". Only the conformance test landed in the original B1
  session because recording a baseline required actually running the renderer
  (`CIDER_UPDATE_BASELINES=1 swift test`), which needed a Swift toolchain that
  session did not have. The missing image baseline has since been recorded in
  the visual-baselines continuation above.

- B3 originally deferred full composed text. The Stage 3/4 MVP closure added
  basic X11 keymap text by using `XLookupString` on `KeyPress` and routing the
  resulting bytes through `HostEvent.textInput`; `ApplicationRuntime` now appends
  `.textInput` to the focused text field. This deliberately stops short of full
  XIM/XIC setup and `Xutf8LookupString`, so dead keys and IME composition are
  still future work. Raw `keyDown` remains the path for Backspace and other
  control keys.

- B3 shipped `HostEvent.scroll` without a `location`, which B4 then had
  to add back in. In hindsight this should have been obvious in B3
  itself (a scroll event needs to say *where*, the same way a click
  does) — flagging the miss here rather than quietly folding it in, since
  the plan's review process should catch this kind of thing earlier next
  time a session designs a new `HostEvent` case.

## Open issues

- **Stage 5 is closed at `v0.1.0-alpha.0`, with one accepted caveat.**
  `cider alpha-readiness` reports 7 gates `done`; **installation packaging
  stays `partial` by design** — signed binary archives and package-manager
  distribution need real release infrastructure (signing keys, a package
  repository) this project doesn't have. Build from source per
  `docs/install.md` until that lands. See `RELEASE_NOTES.md` for the full
  gate table.
- **`examples/lifecycle-cider` has no interactive trigger.**
  `CiderApp.didEnterBackground()`/`didEnterForeground()` are real and
  conformance-tested (`LIFE-BG-002`), but nothing in `cider run` itself
  drives a background/foreground transition — there's no OS app-switcher
  signal on Linux and no CLI/dev-console control to simulate one. Only
  test/harness code can trigger it today (`docs/known-issues.md`
  `CIDER-KI-0009`).
- **`CiderTimer` callbacks run off the render thread, and `CiderState` isn't
  `Sendable`.** Building `examples/timer-clipboard-cider` (`CiderTimer`'s
  first reference-app use) needed `nonisolated(unsafe)` to capture the bound
  state in the timer's `@Sendable` closure under Swift 6 strict concurrency
  — an honest opt-out of a real, undocumented-until-now race, not a fix for
  it (`docs/known-issues.md` `CIDER-KI-0010`).
- **`jammy` (Ubuntu 22.04) performance is not separately measured.** CI now
  builds and tests both `noble` and `jammy` containers, but
  `docs/performance-baseline.md`'s recorded numbers are `noble`-only;
  `jammy` is assumed comparable, not independently profiled.
- **B9's Stage 2 UI-showcase reference app (`examples/ui-showcase`) remains a
  separate Stage 2 manual-polish caveat.** Stage 3/4 closure did not broaden
  scope to a full UI-showcase walkthrough; the app is still build-verified and
  covered by primitive conformance/visual tests, but not exhaustively tapped
  through as a human UX pass.
- **The Stage 3 reference apps now have Xvfb-backed smoke coverage.**
  `scripts/validate-stages3-4.sh` builds `examples/notes-cider` and
  `examples/rest-client-cider`, launches both through `cider run --no-build
  --inspect` against the real X11 backend, types/saves in Notes, and clicks the
  REST-client GET path through to an HTTP 200 response. This is smoke coverage,
  not a substitute for a human UX pass or a broader service matrix.
- **HTTP real I/O now has deterministic conformance coverage.** `NET-HTTP-001`
  uses a loopback one-request HTTP fixture to prove `CiderHTTP.get` can receive a
  real response when network permission is granted, while keeping the test suite
  independent of the public internet. This is still an MVP client surface; broader
  methods/headers/body streaming/error-shaping remain future service work.
- **Stage 4 graphical DX is now implemented as a local dev console.** `cider dev`
  adds the graphical inspector, polling file watcher with rebuild/relaunch,
  CiderHTTP request capture, sandbox browser/reset and event timeline. This is
  still a development loop, not an IDE extension or in-process Swift hot-swap.
- **The new Stage 4 scanner is intentionally shallow.** `cider scan` is useful
  early-warning tooling for the first compatibility registry, but it is not a
  Swift parser. It can miss dynamic/aliased usage and only knows the symbols
  explicitly listed in `CompatibilityRegistry`. The next Stage 4 slice should
  either expand the registry with generated docs or move toward SwiftSyntax-style
  parsing if deeper source analysis is needed.
- **Stage 4 dev console boundaries:** the request capture proxy is loopback-only
  and scoped to `CiderHTTP`; it is not a system-wide proxy. The file watcher uses
  polling and relaunches the app after rebuild rather than patching code in
  process.
- **The `@_exported import CiderCore` fix (see B9) was found by hand,
  reading code, not by a failing build** — CI had never built any example
  app before this session added that step, so there was no automated
  signal that would have caught it. Now that the build step exists,
  future gaps like it should surface directly as a CI failure instead.

## Conformance IDs assigned so far

Existing, before this plan started (see
`tests/conformance/ConformanceTests.swift` header comment for the
authoritative list):
- `APP-LAUNCH-001`, `UI-TEXT-001`, `UI-VSTACK-001`, `UI-BUTTON-001`,
  `INPUT-POINTER-001`, `STATE-UPDATE-001`

Implemented by this plan:
- `UI-IMAGE-001` (B1)
- `UI-SCROLL-001` (B4)
- `UI-TEXTFIELD-001` (B5)
- `UI-LIST-001` (B6)
- `NAV-PUSH-001`, `NAV-POP-001` (B7)
- `UI-MODAL-001` (B8)
- `STYLE-BRAND-001` (brand/design Stage 2 update)
- `ENV-VALUES-001`, `STORE-PREF-001`, `STORE-FILE-001`, `CLIPBOARD-001`,
  `TIMER-001`, `LIFE-BG-001`, `NET-HTTP-001` (Stage 3 services MVP)
- `LIFE-BG-002` (Stage 5 closure — app-level lifecycle hooks)
