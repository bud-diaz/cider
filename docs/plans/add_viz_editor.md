# Visual editor for `cider dev`

## Context

Cider's `cider dev` console (Stage 4) already mirrors a running app's state into
a loopback browser dashboard: a structured inspector snapshot, a network capture
pane, a sandbox browser and an event timeline. But it is strictly read-only, and
it is not *visual* — the inspector renders the UI tree as an indented text list
while the actual pixels only exist in an X11 window somewhere else.

The gap this closes: adjust a view's appearance by clicking it and typing a
number, instead of finding the right line in a Swift file, editing it, and
waiting to see what happened. Concretely — select a node in a mirrored render of
the running screen, edit its properties in a panel, and have Cider **write the
change back into the project's Swift source**. The existing `ProjectFileWatcher`
then rebuilds and relaunches, so the loop closes with no new machinery pointed
at the running process.

Two decisions were made up front and shape everything below:

- **Source-only edit path.** An edit rewrites Swift and lets the existing
  watcher rebuild. The source stays the single source of truth and there is no
  drift to reconcile. The cost — a rebuild's latency per tweak, and app state
  resetting on relaunch — is accepted.
- **Add the missing DSL modifiers first.** Most `UINode` properties (button and
  text-field colors, corner radius, padding) are hard-wired from `Theme` and
  cannot be set from Swift at all. They become settable, so they are genuinely
  editable rather than shown read-only.

Constraints from `CONTRIBUTING.md` that this must not break: the UI tree stays
pure data (no closures, no origins inside `UINode`); the CLI links neither the
runtime nor a backend; no new package dependency; every application-visible
behaviour gets a stable conformance ID; diagnostics get stable `CID` codes.

**Scope boundary: v1 edits properties, never structure.** No adding, deleting,
reordering or reparenting nodes. `NodeID` is a structural path
(`ui/Sources/CiderUITree/UINode.swift:21-37`), so inserting a sibling re-keys
every following node and all of its descendants — selection and any in-flight
edit would silently re-target. Structural editing needs developer-supplied keys
first, exactly as `docs/adr/0003-ui-tree-model.md` predicted under "Identity
from an explicit developer-supplied key". Say so in the docs rather than
half-supporting it.

---

## Architecture

Four pieces, in the direction data already flows:

```
CiderUI (lowering)         records where each view and modifier was written
   │  ApplicationScene.origins   ← new side table, beside .actions
   ▼
CiderRuntime               writes snapshot JSON + a raw-RGBA frame per N ms
   │  .cider/dev/inspector/{latest.json, frame.bin}
   ▼
CiderProject (console)     serves them; rewrites Swift on POST
   │  GET /api/inspector/frame, POST /api/editor/apply
   ▼
browser                    <canvas> + frame overlay + property panel
   │
   └─ writes Swift ─▶ ProjectFileWatcher (500ms) ─▶ rebuild + relaunch ─▶ new frame
```

### 1. Source origins — captured at the call site, stored beside the tree

Add defaulted location parameters to every view initializer and every modifier:

```swift
public init(_ content: String, file: String = #filePath, line: Int = #line, column: Int = #column)
public func font(size: Double, weight: FontWeight = .regular,
                 file: String = #filePath, line: Int = #line, column: Int = #column) -> Text
```

Each view value then carries `origin: SourceOrigin` (its initializer's call site)
and `propertyOrigins: [String: SourceOrigin]` (one entry per modifier actually
called). A property with no entry was never written in source — that is exactly
the signal the rewriter needs to know whether to *rewrite* an argument or
*insert* a modifier.

`SourceOrigin` goes in `runtime/Sources/CiderCore/` (a plain
`Codable, Equatable, Sendable` struct of `file`/`line`/`column`) so
`CiderProject` can consume it without depending on `CiderUITree`.

**Origins do not go into `UINode`.** They travel in a new side table, exactly
like `actions` and `textInputHandlers` already do:

- `LoweringContext.register(origins:for:)` — mirrors the existing
  `register(action:for:)` at `compatibility/Sources/CiderUI/Lowering.swift:56-58`.
- `ApplicationScene.origins: [NodeID: NodeOrigins]`, defaulted to `[:]` in the
  memberwise init at `runtime/Sources/CiderRuntime/Application.swift:30-38`, so
  every existing construction site still compiles.

This keeps `UINode` byte-identical and `Equatable`-stable, which matters: the
whole conformance and visual suite compares `UINode` values, and adding a field
would churn all of it for no benefit.

`#filePath` rather than `#fileID`: `#fileID` is `Module/File.swift` and does not
survive duplicate filenames across directories. `#filePath` is absolute and
resolvable, and the console validates it lies inside `project.root` before
touching it — reusing the path-escape shape already proven at
`compiler-support/Sources/CiderProject/SandboxBrowser.swift:68-80`.

> **The one empirical unknown.** What `#line`/`#column` report for a *chained*
> call (`.font(size: 28)` on the line below its receiver) has to be measured,
> not assumed. Milestone 3 lands a test that pins it against a fixture with
> known positions, and the rewriter's callee sanity-check (below) refuses rather
> than corrupts if the assumption is ever wrong.

### 2. Typed properties in the snapshot

`InspectorNodeSnapshot` (`inspector/Sources/CiderInspector/Inspector.swift:32-46`)
today carries `id`, `kind`, `label`, `frame`, `depth` — `label(for:)` (:219-230)
collapses everything into one display string, so fonts, colors, insets and
`isEnabled` are lost. Add one field:

```swift
public var properties: [InspectorPropertySnapshot]   // new, defaults to []

public struct InspectorPropertySnapshot: Codable, Equatable, Sendable {
    public var name: String          // "fontSize", "backgroundColor", "spacing"
    public var type: String          // "double" | "string" | "color" | "bool" | "enum" | "insets"
    public var value: String         // "28.0", "#E89A2FFF", "bold"
    public var options: [String]?    // enum cases, e.g. ["leading","center","trailing"]
    public var editable: Bool
    public var origin: SourceOrigin? // nil when the property was never written in source
}
```

Keep `label` and every existing field: the current dashboard renderer reads them,
and `properties` defaulting to `[]` keeps `Codable` decoding of older snapshots
working.

**Make the contract compile-checked.** Today `cider` does not link
`CiderInspector`, so the JSON schema is duck-typed between the runtime that
writes it and the browser JS that reads it (`Package.swift:187-189`). Add
`CiderInspector` to `CiderProject`'s dependencies — legal, because
`CiderInspector` depends only on `CiderCore` and `CiderUITree`
(`Package.swift:141-145`), neither of which is the runtime or a backend, so the
"CLI links neither the runtime nor a backend" rule holds. The console can then
decode `InspectorSnapshot` and resolve `nodeId → property → origin` in typed
Swift instead of trusting the browser to send back a location.

### 3. Frame mirror — raw RGBA, no codec

`tests/visual/PPM.swift:1-6` records a deliberate decision: Cider has no image
codec and does not want a zlib dependency. Browsers cannot display PPM — but
they do not need an encoded image at all:

```js
ctx.putImageData(new ImageData(new Uint8ClampedArray(rgba), width, height), 0, 0)
```

So the runtime writes the presented `Canvas` (`runtime/Sources/CiderCore/Canvas.swift:13`,
pixels packed `0xAARRGGBB`) as a 16-byte header (`"CIDR"`, version, width,
height, all little-endian `UInt32`) followed by raw RGBA bytes, atomically, to
a new descriptor-gated path. No encoder, no dependency, and the decision stays
consistent with the PPM one.

Cost is bounded: `phone-standard` is 390×844 at scale 1
(`device-profiles/Sources/CiderDeviceProfiles/…:22-28`) = 1.3 MB per frame.
The run loop pumps every 8 ms, so **throttle writes to at most one per 200 ms**
and only when a frame was actually presented. (A later refinement, not needed
for v1: gate on a marker file the dashboard touches while the editor tab is
open, so the cost disappears entirely when nobody is looking.)

New `LaunchDescriptor` field `inspector.frame-path`, alongside the existing
`inspector.enabled` / `inspector.snapshot-path`
(`runtime/Sources/CiderCore/LaunchDescriptor.swift:83-101, 150-166`). Only
`cider dev` sets it; `cider run --inspect` does not, so nothing changes for
normal runs.

### 4. Selection without touching hit testing

`RenderTree.hitTest` (`ui/Sources/CiderUITree/RenderTree.swift:77-92`) only sees
buttons, text fields and modal overlays — `Text`, `Image` and `VStack` publish no
hit region, by design. Rather than adding editor-only hit regions to
`RenderTreeBuilder`, **select in the browser**: every entry in
`snapshot.nodes` already carries a `frame`, so the deepest node whose frame
contains the click wins (`depth` breaks ties, and the flat pre-order array makes
"deepest" a single pass). Zero runtime change, and it selects node kinds the
runtime deliberately does not hit-test.

### 5. The source rewriter

New file `compiler-support/Sources/CiderProject/SwiftSourceEditor.swift` — pure
string logic, no new dependency, no SwiftSyntax. It handles three edit shapes:

**(a) Rewrite an argument that is present.** From the recorded offset, scan
forward to the call's `(`, then walk to the matching `)` tracking nesting of
`()[]{}`, string literals (including `"""` and `\(…)` interpolation), and `//`
and `/* */` comments. Split top-level arguments on commas, find the one with the
target label (or positional index), replace its value text.

**(b) Insert a defaulted initializer argument.** `VStack { … }` has no
`spacing:` to rewrite (`compatibility/Sources/CiderUI/VStack.swift:14-20`
defaults it), so the argument is inserted in declared parameter order — from a
small static per-view parameter table in the rewriter. When the call has no
parens at all because everything is a trailing closure, synthesize
`(spacing: 24)` before the closure.

**(c) Insert a modifier that was never called.** Walk from the initializer's
start: consume the argument list, then any trailing closure, then repeatedly any
`.identifier(…)` postfix element. The end of the last chain element is the
insertion point. Match the chain's existing style — a new line at the existing
`.` indentation for a multi-line chain (as in `examples/hello-cider`), inline for
a single-line chain (as in `examples/notes-cider`).

**Compare-and-swap, not hashing, for staleness.** The apply request carries the
property's *expected current value* — what the panel displayed. The rewriter
extracts the current literal from source and refuses if it differs. That is a
precise check at exactly the right granularity, with no hash to compute per
frame and no race between fetching a hash and applying an edit.

**Refuse rather than corrupt.** A rewriter that mangles a developer's source is
far worse than one that declines, so the refusal set is deliberately broad. Each
gets a diagnostic in the free `CID0630`–`CID0637` block (existing codes stop at
`CID0621`):

| Refuse when | Why |
| --- | --- |
| The value in source is not a literal — `Text("Count: \(count)")`, a variable, `Theme.bodyFontSize`, an expression | Rewriting it would silently discard the developer's intent |
| The recorded file is outside `project.root` | Path-escape guard |
| The expected current value doesn't match what's in source | Stale snapshot, or a concurrent edit |
| The recorded position doesn't begin the expected callee (`Text`, `.font`, …) | Cheap sanity check that catches any `#column` surprise before writing |
| More than one live node shares that origin | A view built in a loop or `buildArray` — one source site, N nodes, ambiguous target |
| The chain crosses `#if`, a macro, or a comment inside the token being replaced | Out of what string scanning can safely reason about |

### 6. Route and panel

One new route each, added as cases to the exhaustive
`switch (method, path)` at
`compiler-support/Sources/CiderProject/DevDashboardServer.swift:73-105`:

- `GET /api/inspector/frame` → the frame file as `application/octet-stream`,
  `204` when absent (mirroring `/api/inspector/latest` at :84-86).
- `POST /api/editor/apply` → `{nodeId, property, value, expectedCurrentValue}`,
  returns `{ok, file, line}` or a `Diagnostic`. Bodies stay well under the
  server's single 65536-byte read (`DevHTTPServer.swift:86-115`), which cannot
  continue a split body — keep the payload small and never send the source.

The dashboard gains an **Editor** tab beside inspector/network/sandbox/events: a
`<canvas>` drawing the mirrored frame, an absolutely-positioned overlay of node
frames for hover/selection, and a property panel of typed inputs. Editable rows
get an input; theme-derived and non-literal rows render read-only with the reason.
On apply, the panel shows the returned file:line and then the normal `building` →
`running` state transition from `/api/status`.

Client-side rules the existing test lock already enforces and the new code must
follow: every interpolated value goes through `escapeHTML`, hover reveals need a
focus equivalent, Tailwind-style class names are hardcoded not built at runtime,
and states must land in the intended `severityForText` bucket.

### 7. New DSL modifiers

Follow the established per-primitive `var copy = self` pattern
(`compatibility/Sources/CiderUI/Text.swift:22-27` explains why) — **do not**
introduce a generic `ViewModifier` mechanism. That comment's own argument still
holds: a general wrapper would be more code than the thing it generalises, and
designing it against these eight properties would be designing against guesses.

```swift
extension Button {
    public func foregroundColor(_ color: Color) -> Button   // ButtonNode.titleColor
    public func background(_ color: Color) -> Button        // + pressed derived, see below
    public func cornerRadius(_ radius: Double) -> Button
    public func padding(_ insets: EdgeInsets) -> Button
}
extension TextField {
    public func foregroundColor(_ color: Color) -> TextField
    public func background(_ color: Color) -> TextField
    public func cornerRadius(_ radius: Double) -> TextField
    public func padding(_ insets: EdgeInsets) -> TextField
}
```

`ButtonNode` has both `backgroundColor` and `pressedBackgroundColor`. Keep v1 to
one `background(_:)` that sets the base color and leaves the pressed color
derived from `Theme` — a two-color API is a design question the editor doesn't
need answered yet, and `STYLE-BRAND-001` asserts the brand defaults, which all
of these must preserve when uncalled.

Defer `Modal`'s `overlayColor` and `FontRequest.family`: neither has a settable
path today and neither is worth a modifier before someone asks.

---

## Editable properties, v1

| Node kind | Editable | Source form |
| --- | --- | --- |
| `TextNode` | text, fontSize, fontWeight, color | init arg 0; `.font`; `.foregroundColor` |
| `ButtonNode` | title, fontSize, fontWeight, isEnabled, titleColor, backgroundColor, cornerRadius, padding | init arg 0; `.font`; `.disabled`; new modifiers |
| `VStackNode` | spacing, alignment | init args (insertion path (b)) |
| `TextFieldNode` | width, fontSize, fontWeight, textColor, backgroundColor, cornerRadius, padding | init arg; `.font`; new modifiers |
| `ScrollViewNode` | width, height | init args |
| `ScrollViewNode` from `List` | width, height | init args |
| `VStackNode` at `<id>/rows` | spacing | the parent `List`'s `spacing:` init arg |
| `ImageNode` | — | pixels come from an `ImageSource`; nothing in source to edit |
| `NavigationStackNode`, `ModalPresenterNode` | — | structural; out of v1 scope |

**Synthetic nodes need an origin mapping.** Three node kinds emit wrapper nodes
with non-numeric ids that no view value ever produced —
`ScrollView`'s `<id>/wrap`, `List`'s `<id>/rows`
(`compatibility/Sources/CiderUI/List.swift:45-51`) and `NavigationView`'s
`<id>/screen`. They carry no origin of their own, so `register(origins:for:)`
must also register the *parent view's* origin for the synthetic id, with the
property mapped to the parent's initializer argument. `List`'s `spacing` is
exactly this case: the value lives on the synthetic `/rows` `VStackNode` but is
written as `List(width:height:spacing:)`. Getting this wrong would point an edit
at the wrong call, so it needs its own test in M3.

`TextFieldNode.text` is deliberately not editable: it is bound application state
(`TextField.swift:38`), not a source literal. All non-editable properties are
still *displayed*, with the reason (`theme default`, `bound state`, `not a
literal`) — an editor that hides what it can't change is harder to trust than one
that explains.

---

## Milestones

Each is independently committable and independently testable. Order puts the
demo first and the risky string surgery in the middle, behind unit tests.

**No milestone is pushed with a stale `README.md`.** Each one carries the
`README.md` and `CHANGELOG.md` edits for the behaviour *it* changes — M4 fixes
the "no padding modifiers" limitation, M1/M6 update the `cider dev` bullet — and
M7 is the final consistency sweep across the whole list, not the first time the
file is touched.

**M1 — Frame mirror and click-to-select.** A read-only visual inspector, useful
on its own: you see the running app in the browser and click a node to select it.
- `LaunchDescriptor.swift` (new `inspector.frame-path` field + encode/decode),
  `ApplicationRuntime.swift` (throttled frame write beside
  `writeInspectorSnapshotIfNeeded` at :501-512), `DevWorkspace.swift` (new path),
  `DevSession.swift:88-95` (set the field), `DevDashboardServer.swift` (new
  route), `DevDashboardAssets.swift` (Editor tab, canvas, overlay).
- Tests: descriptor round-trip in `tests/unit/LaunchDescriptorTests.swift`;
  frame-file header/throttle in a new unit test; route smoke in
  `tests/unit/DevExperienceClosureTests.swift:55`.

**M2 — Typed properties in the snapshot.** The panel shows real values instead of
a collapsed `label`.
- `Inspector.swift` (`InspectorPropertySnapshot`, per-kind property extraction
  beside `label(for:)`), `Package.swift` (`CiderProject` → `CiderInspector`),
  `DevDashboardAssets.swift` (property panel).
- Tests: extend `tests/unit/InspectorSnapshotTests.swift` with a per-kind
  property assertion and a round-trip that proves old JSON still decodes.

**M3 — Source origins.** The panel shows where each value is defined. This is
where the `#line`/`#column` assumption gets pinned.
- `CiderCore/SourceOrigin.swift` (new), `Lowering.swift` (+`origins`),
  `Application.swift` (+`ApplicationScene.origins`), every view type in
  `compatibility/Sources/CiderUI/` (defaulted location params), `Inspector.swift`
  (origin on each property).
- Tests: new conformance `EDIT-ORIGIN-001` asserting a fixture's recorded
  line/column for both an initializer and a chained modifier — **this test is the
  point of the milestone**, because it is the only way to verify the assumption
  without a local toolchain.

**M4 — New DSL modifiers.** Independent of everything above; can land in parallel.
- `Button.swift`, `TextField.swift`, `CHANGELOG.md`,
  `docs/04-compatibility-specification.md`, `docs/compatibility-registry.md`
  (regenerate via `cider compatibility-docs`).
- Tests: conformance `UI-BUTTON-002`, `UI-TEXTFIELD-002`; confirm
  `STYLE-BRAND-001` still passes with defaults untouched.

**M5 — The rewriter.** Pure logic, no I/O in the core, exhaustively unit-tested.
The lowest-risk way to build the highest-risk component with no local toolchain.
- `compiler-support/Sources/CiderProject/SwiftSourceEditor.swift`.
- Tests: a new `tests/unit/SwiftSourceEditorTests.swift` table-driven over both
  example apps' real source — rewrite-in-place, insert-init-arg,
  insert-modifier-single-line, insert-modifier-multi-line, and **one case per
  refusal row** in the table above, asserting the `CID` code and that the file is
  left byte-identical.

**M6 — Wire it up.** `POST /api/editor/apply` resolves node → property → origin
via the decoded snapshot, calls the rewriter, appends a `DevEvent`, and lets the
watcher rebuild. Panel inputs become live.
- `DevDashboardServer.swift`, `DevDashboardAssets.swift`.
- Tests: conformance-style `EDIT-WRITE-001` and `EDIT-REFUSE-001` driving the
  route against a temporary project fixture, as
  `DevExperienceClosureTests` already does.

**M7 — Docs and decisions.**
- `docs/adr/0006-source-origin-capture-and-write-back.md` — defaulted
  `#filePath/#line/#column` parameters on every public view initializer and
  modifier, the origins side table, and the refusal policy. Alternatives to
  record: SwiftSyntax (a dependency, and it cannot map a *runtime* node back to a
  source range); origins inside `UINode` (breaks `Equatable` stability across the
  suite); a `#sourceLocation`-style explicit developer annotation.
- `docs/adr/0007-frame-mirror-format.md` — raw RGBA + header, why not PNG,
  citing the PPM precedent; what a second backend must match.
- `docs/adr/0008-expanded-view-modifiers.md` — the eight new modifiers, and the
  argument for *not* introducing a generic `ViewModifier` yet.
- `docs/adr/README.md` index (add rows 0006–0008),
  `CHANGELOG.md` `[Unreleased]`,
  `docs/05-implementation-roadmap.md` (this is Stage 4 developer-experience
  work, not a new stage — the roadmap table's "4 | closed" row stands),
  `scripts/validate-stage4-dev.sh` (exercise the new routes under `--once`).

**`README.md` must be updated before pushing.** Five specific places, and the
limitations list is the one that matters most — `CONTRIBUTING.md` is explicit
that an out-of-date limitations list is worse than none, because it overclaims:

  1. **Status blockquote (line ~19)** — the sentence describing Stage 4
     developer-experience work currently ends at "and a sandbox browser". Add
     the visual editor to that list.
  2. **"What works today" → the `cider dev` bullet (~line 76)** — currently
     "graphical inspector, file-watching rebuild/relaunch, `CiderHTTP` request
     capture, sandbox browser and event timeline". Add the mirrored frame,
     click-to-select and source write-back.
  3. **"What works today" → the declarative API bullet (~line 87)** — add the
     eight new `Button`/`TextField` style modifiers alongside the existing view
     list.
  4. **"Current limitations" (line 299)** — two edits:
     - The **Layout** bullet says "no frame or padding modifiers". That becomes
       false the moment M4 lands: narrow it to say padding is settable on
       `Button` and `TextField` only, and that there is still no general
       `.frame`/`.padding` on arbitrary views.
     - The **Compatibility tooling / DX** bullet: add the editor, and state its
       real boundaries plainly — property edits only (no adding, deleting or
       reordering views), literal values only, and one rebuild-and-relaunch per
       edit, so app state resets. This bullet is where the honest caveats live;
       do not soften them.
  5. **"Repository layout" (line 241)** — the `inspector/` row reads "Textual
     dumps of runtime state", which undersells it once the snapshot carries
     typed properties and source origins. Reword to cover both the textual
     dumps and the structured snapshots.

Keep the marketing-language ban in view (`docs/07-legal-distribution-boundaries.md`
section 10, restated in `CONTRIBUTING.md`): describe what the editor is tested to
do. No "Xcode replacement", no "storyboard", no comparison to any vendor's tool.

---

## Things that will bite, and what to do about them

- **Golden asset snapshots churn three times.** `tests/unit/Snapshots/DevDashboardAssets/{index.html,app.css,app.js}` are compared byte-for-byte (`tests/unit/DevDashboardAssetsTests.swift:6-10`), so M1, M2 and M6 each require regenerating all three. Unavoidable; batch the asset work within each milestone rather than trickling it. The same test also asserts 14 verbatim CSS custom properties, forbids `transition: all` and `ease-in`, requires `escapeHTML`, `aria-selected`, `prefers-reduced-motion`, `button:active { transform: scale(0.97); }` and the `.severity-*` classes, and bans brand strings — the Editor tab must satisfy all of it.
- **Nothing can be compiled here.** Swift is not installed and Docker has no daemon, so every milestone is verified by CI on push (`.github/workflows/ci.yml`, Swift 6.0 × debug/release × Ubuntu 22.04/24.04). This is why M5 is pure logic and why M3's location test exists.
- **One source site can be many nodes.** `List`/`buildArray` build views in a loop; all of them record the same origin. The rewriter refuses ambiguous targets rather than guessing, and the panel should say so.
- **The relaunch resets app state.** After an edit the app restarts, so a modal closes and a text field empties. Expected under the source-only decision; worth one line in the docs so it does not read as a bug.
- **`DevHTTPServer` is serial and single-read.** One request per connection, no `Content-Length` continuation (`DevHTTPServer.swift:86-115`), so apply payloads must stay small — never round-trip source text through it.
- **Frame writes are the only new per-frame I/O.** 1.3 MB throttled to 5/s. If profiling says that matters, the marker-file gate noted above turns it off when the editor tab is closed.

---

## Verification

Per milestone, plus this end-to-end pass once M6 lands:

```sh
swift build && swift test                      # full suite, incl. new conformance IDs
swift test --filter SwiftSourceEditorTests     # the refusal table
scripts/validate-stage4-dev.sh                 # cider dev --once route smoke
```

Manual end-to-end (needs a display; `Xvfb :99 -screen 0 1280x1024x24 &`):

```sh
cd examples/hello-cider && cider dev --open
```

1. Open the Editor tab — `examples/hello-cider`'s screen renders in the canvas.
2. Click "Cider Demo" — the `TextNode` selects; the panel shows
   `text`, `fontSize 28`, `weight bold`, and the origin
   `HelloCiderApp.swift:19`.
3. Change `fontSize` to `36` and apply. `git diff` shows exactly
   `.font(size: 28, weight: .bold)` → `.font(size: 36, weight: .bold)`,
   one line changed. The console goes `building` → `running` and the canvas
   redraws larger.
4. Select "Press Me", set a background color. Because `.background(…)` was never
   written, a new modifier line is inserted at the chain's indentation and the
   button changes color.
5. Select `Text("Count: \(count)")` and try to edit its text — refused with the
   non-literal diagnostic, and `git diff` shows the file untouched.
6. Confirm `git diff` across the whole session contains only intended lines —
   no reformatting, no whitespace drift.

Step 6 is the real acceptance test. A visual editor that reformats source is one
nobody will leave switched on.
