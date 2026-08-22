# Handoff

Persistent state for the "Close Stage 1, ship Stage 2" implementation plan
(saved at plan time as `/root/.claude/plans/creat-a-plan-to-parallel-castle.md`
in the planning session; the milestone IDs below refer to that plan's
sections). Read this in full before starting a milestone. Update it —
Status, Done, Deviations, Open issues, Conformance IDs — before ending a
session, whether or not the milestone finished.

## Status

Every milestone in this plan (Part A, B1-B9) is implemented. **B9** is
pushed but this session had not confirmed its CI result as of this
writing — check it (and B8's, see below) before treating the plan as
closed. If both are green, this plan is done: what's left is genuinely
Stage 3+ work, not anything this plan scoped.

Note: `swift` is not installed in the container this work was done in, so
none of this has been build/test-verified locally beyond what CI reports.
CI came back green on Part A (159f987), B1 (1d20d63), B2 (c272a26), B3
(8676a50), B4 (52590ca), B5 (a91f40f) and B7 (0ec9d66). B6's first push
(db2a5df) **failed CI** — the first real test failure this plan has hit;
the fix (31c3f79) came back green (run 32581743172). B8's and B9's pushes
have not been checked yet by this session — check both before treating
this plan as fully closed.

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
    recorded, the same reason B1's Image baseline wasn't: no Swift
    toolchain in this session to run `CIDER_UPDATE_BASELINES=1 swift
    test`. Every new primitive does have conformance coverage
    (`UI-IMAGE-001`/`UI-SCROLL-001`/`UI-TEXTFIELD-001`/`UI-LIST-001`/
    `NAV-PUSH-001`/`NAV-POP-001`/`UI-MODAL-001`), which is real,
    CI-enforced test coverage — just not the pixel-level visual
    regression the plan's Verification section also asked for. Carried
    into Open issues below alongside B1's.
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
- **No Stage 2 primitive after B1 has a visual-regression baseline
  either**, same root cause: `ScrollView`, `TextField`, `List`,
  `NavigationView` and `Modal` all have conformance coverage but no
  pixel-level baseline. `tests/visual/VisualRegressionTests.swift`'s
  harness is unchanged and generalizes to all of them (confirmed by
  inspection, same as B9's HANDOFF entry notes) — this is purely "needs a
  session with a real Swift toolchain to record and eyeball each one,"
  not a design gap.
- **B9's reference app (`examples/ui-showcase`) has never actually been
  run.** CI now *builds* it (see B9's Done entry), which is real signal
  that the compatibility API is reachable and the app type-checks, but
  nobody has run it under `cider run`/Xvfb and looked at it, tapped
  through it, or confirmed the modal/navigation/list interaction actually
  feels right end-to-end. Do that before calling Stage 2 "done" in any
  stronger sense than "the pipeline compiles and the conformance suite
  passes."
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
