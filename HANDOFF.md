# Handoff

Persistent state for the "Close Stage 1, ship Stage 2" implementation plan
(saved at plan time as `/root/.claude/plans/creat-a-plan-to-parallel-castle.md`
in the planning session; the milestone IDs below refer to that plan's
sections). Read this in full before starting a milestone. Update it —
Status, Done, Deviations, Open issues, Conformance IDs — before ending a
session, whether or not the milestone finished.

## Status

Part A (Stage 1 close-out), **B1** (Image node) and **B2** (layout &
rendering foundations) are done. Next up: **B3** (host keyboard/scroll
event plumbing — X11 C shim changes). B2 and B3 are both prerequisites
for B4–B6 — do not start those out of order.

Note: `swift` is not installed in the container this work was done in, so
none of this has been build/test-verified locally beyond what CI reports.
CI came back green on Part A (159f987) and B1 (1d20d63) — real signal the
toolchain setup and both are sound. B2 has been pushed for the same
verification; check its result before starting B3.

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
    `tests/unit/LayoutTests.swift`. **No visual-regression baseline yet**
    — see Open issues; a `VisualRegressionTests.swift` case was written
    and then deliberately reverted rather than committed, see Deviations.

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
  test `UI-IMAGE-001`". Only the conformance test landed. Recording a
  baseline requires actually running the renderer (`CIDER_UPDATE_BASELINES=1
  swift test`), which needs a Swift toolchain this session did not have;
  committing the test without running that step would mean committing a
  guessed `.ppm` file or a test that fails on every future CI run for an
  unrelated reason. Left for a session with a real toolchain instead of
  guessing. See Open issues.

## Open issues

- **B1 (Image) has no visual-regression baseline.** A candidate test
  (`testImageScreen`, exercising `Rasterizer.draw(image:...)`'s
  nearest-neighbour sampler through a real scene) was written, then
  reverted before committing: `assertMatchesBaseline` fails hard with no
  baseline file present, and I had no Swift toolchain in this session to
  run `CIDER_UPDATE_BASELINES=1 swift test --filter CiderVisualTests` and
  record one — committing the test without its baseline would have
  turned CI red for every push after it, for a reason unrelated to
  whatever that push actually changed. Whoever has a real toolchain next
  should re-add a case like it, record the baseline, eyeball the `.ppm`,
  and commit both together in one change.

## Conformance IDs assigned so far

Existing, before this plan started (see
`tests/conformance/ConformanceTests.swift` header comment for the
authoritative list):
- `APP-LAUNCH-001`, `UI-TEXT-001`, `UI-VSTACK-001`, `UI-BUTTON-001`,
  `INPUT-POINTER-001`, `STATE-UPDATE-001`

Reserved by this plan, not yet implemented:
- `UI-IMAGE-001` (B1)
- `UI-SCROLL-001` (B4)
- `UI-TEXTFIELD-001` (B5)
- `UI-LIST-001` (B6)
- `NAV-PUSH-001`, `NAV-POP-001` (B7)
- `UI-MODAL-001` (B8)
