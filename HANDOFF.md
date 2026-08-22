# Handoff

Persistent state for the "Close Stage 1, ship Stage 2" implementation plan
(saved at plan time as `/root/.claude/plans/creat-a-plan-to-parallel-castle.md`
in the planning session; the milestone IDs below refer to that plan's
sections). Read this in full before starting a milestone. Update it —
Status, Done, Deviations, Open issues, Conformance IDs — before ending a
session, whether or not the milestone finished.

## Status

Part A (Stage 1 close-out), **B1** (Image), **B2** (layout/rendering
foundations), **B3** (host input plumbing), **B4** (ScrollView), **B5**
(TextField) and **B6** (List) are done. Next up: **B7** (navigation
stack), which needs a real replacement for `layoutCentered`'s
placeholder root-layout behavior -- read that function's doc comment in
`ui/Sources/CiderUITree/Layout.swift` before starting; B4 and B5 both
explicitly deferred "fill parent" layout to this milestone.

Note: `swift` is not installed in the container this work was done in, so
none of this has been build/test-verified locally beyond what CI reports.
CI came back green on Part A (159f987), B1 (1d20d63), B2 (c272a26), B3
(8676a50), B4 (52590ca) and B5 (a91f40f). B6's first push (db2a5df)
**failed CI** — the first real test failure this plan has hit. Root
cause and fix below in Done/B6; check the fix commit's CI result before
starting B7.

**Caveat carried from B3, still true, now more relevant**: CI's `swift
build`/`swift test` compile the X11 C shim but never execute it — every
test uses the headless `TestingHostBackend`. A green CI run is not
evidence that scrolling or key events actually work when `cider run`
opens a real X11 window. **B5 specifically depends on this being true for
typing to work at all**: it reads raw keysyms straight from `XLookupKeysym`
(no Xutf8LookupString), on the premise that X11's printable-ASCII keysyms
equal their Unicode code points. That premise is standard, documented
X11 behavior, not a guess particular to this codebase — but it has only
been exercised through synthetic `TestingHostBackend` events with
hand-picked keyCode values, never a real keyboard. Someone with real
display access should run `examples/hello-cider`, focus a text field, and
confirm actual typing works before this is trusted end-to-end.

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
  - **Deliberately NOT implemented**: `Xutf8LookupString`/XIM/XIC
    composed-text input in the X11 shim, so the Linux backend does not
    yet actually produce `.textInput` events (only `TestingHostBackend`
    can, by construction — it queues whatever `HostEvent` it's handed).
    See Deviations.
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

- **B3's `HostEvent.textInput` is not implemented by the Linux backend.**
  The plan called for `Xutf8LookupString` in the X11 shim. That needs an
  `XOpenIM`/`XCreateIC` input-method setup this session judged too risky
  to add blind: it's new C code with real failure modes (locale/IM
  availability varies by environment, including under Xvfb), touching
  the same window-open path all of Stage 0/1 depends on, with zero
  ability in this session to compile-test the C changes behaviorally
  (see the CI caveat under Status) let alone run them interactively.
  `keyDown`/`keyUp` (via `XLookupKeysym`, no new X resources) and
  `scroll` (reusing the already-selected `ButtonPressMask`) were judged
  low-risk enough to implement for real; composed text input was not.
  `HostEvent.textInput` exists and is fully wired through the runtime
  regardless, because `TestingHostBackend` can synthesize it for tests
  with no dependency on the X11 shim — so B5 (TextField) can be built
  and conformance-tested against it even before the Linux backend
  actually produces one. Whoever picks up B5 needs to either implement
  Xutf8LookupString/XIM/XIC in the C shim then (with real display access
  to test it), or explicitly scope B5 to keyDown-driven text entry
  (backspace, printable ASCII via keysym) without full IME composition
  and note that as a known limitation.

- B3 shipped `HostEvent.scroll` without a `location`, which B4 then had
  to add back in. In hindsight this should have been obvious in B3
  itself (a scroll event needs to say *where*, the same way a click
  does) — flagging the miss here rather than quietly folding it in, since
  the plan's review process should catch this kind of thing earlier next
  time a session designs a new `HostEvent` case.

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

Implemented by this plan:
- `UI-IMAGE-001` (B1)
- `UI-SCROLL-001` (B4)
- `UI-TEXTFIELD-001` (B5)
- `UI-LIST-001` (B6)

Reserved, not yet implemented:
- `NAV-PUSH-001`, `NAV-POP-001` (B7)
- `UI-MODAL-001` (B8)
