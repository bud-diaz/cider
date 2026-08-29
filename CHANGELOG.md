# Changelog

All notable changes to Cider are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Cider is pre-alpha and does not yet follow semantic versioning; version numbers
before `0.1.0` carry no compatibility promise, and
`docs/04-compatibility-specification.md` section 7 describes the policy that
takes effect once one exists.

## [0.1.0-alpha.0]

First tagged alpha milestone. See `RELEASE_NOTES.md` for the full Stage 5
gate status and accepted caveats, and `HANDOFF.md` for implementation
detail. Highlights since the entries below: Stage 3 services (HTTP,
preferences, storage, timers, clipboard), Stage 4 developer experience
(`cider scan`/`inspect`/`network`/`storage`/`dev`), an Apache-2.0 license,
a versioned compatibility contract, 10 reference applications, and CI
across two Ubuntu LTS releases (24.04, 22.04).

## [Unreleased]

### Security

- **The dev console now authenticates every request that changes state.**
  Loopback is not a security boundary: any web page a developer visits can POST
  to `127.0.0.1` and the browser delivers it, even though CORS stops the page
  reading the reply. That already reached `/api/sandbox/reset` and
  `/api/proxy/fetch`. `cider dev` now mints a per-run token, hands it out only
  to its own origin at `GET /api/dev/session`, and requires it in an
  `X-Cider-Dev-Token` header on every mutating route (`CID0631`). `Origin` and
  `Host` are validated on the same routes, and `OPTIONS` preflight is answered
  so the custom header is usable at all.
- The token reaches the running application through a new
  `request-capture.token` launch-descriptor field, so `CiderHTTP`'s capture POST
  stays authorised without widening the hole.

### Fixed

- `DevHTTPServer` read a request with a single `read()` and never consulted
  `Content-Length`. A client that split its head and body across writes -- which
  browsers routinely do -- could have its POST body silently truncated to
  nothing. The server now reads the head, then exactly as many body bytes as
  declared, capped at 1 MiB (`CID0630`) so one connection cannot hold the
  single-threaded accept loop.

### Added

**Developer console editor**

- `cider dev` gains an editor tab: the running application's presented frame is
  mirrored into the browser and views are selected by clicking them. Selection
  uses the inspector snapshot's node frames, so it reaches `Text`, `Image` and
  `VStack` -- node kinds the runtime deliberately publishes no hit region for.
- `FrameMirror` wire format: a 24-byte header (`CIDR`, version, pixel size,
  logical size) followed by straight-alpha RGBA8. No image codec is involved --
  the browser hands the buffer straight to `ImageData`, which is why raw bytes
  beat PNG here for the same reason `tests/visual/PPM.swift` gives.
- `LaunchDescriptor.inspectorFramePath` (`inspector.frame-path`), set only by
  `cider dev`. Frame writes are throttled to five a second, so an application
  presenting at the loop's full rate does not turn the mirror into the most
  expensive thing in the process.
- `GET /api/inspector/frame` on the dev dashboard, 204 until a frame exists.

**UI style modifiers**

- `Button.foregroundColor(_:)`, `Button.background(_:pressed:)`,
  `Button.cornerRadius(_:)`, `Button.padding(horizontal:vertical:)`, and the
  matching `TextField.foregroundColor(_:)`, `TextField.background(_:)`,
  `TextField.cornerRadius(_:)`, `TextField.padding(horizontal:vertical:)`.
  These properties existed on `ButtonNode` and `TextFieldNode` but were
  hard-wired from `Theme`, so no application could set them and the editor
  could only ever show them read-only. Unset properties still resolve to
  `Theme` at lowering time, so every existing default is unchanged.
- `Button.background` requires the pressed colour as well as the resting one.
  Deriving one from the other means choosing a colour space and a factor, and
  a factor that reads correctly on a mid-tone background reads as a broken
  button on a dark or fully saturated one.
- Conformance IDs `UI-BUTTON-002` and `UI-TEXTFIELD-002`.

**Inspector snapshot**

- `InspectorNodeSnapshot.properties`: each node takes itself apart into named,
  typed values instead of collapsing into one `label` string, so the editor can
  address a property rather than read a summary. Optional, so a snapshot from
  an older runtime still decodes.
- Properties an application could not have written are reported rather than
  hidden, carrying the reason: a `TextField`'s text is `bound to app state`, an
  `Image`'s dimensions are `image pixels`, a modal's overlay is a
  `theme default`.
- `CiderProject` now depends on `CiderInspector`, so the console can decode the
  snapshot it serves instead of duck-typing it in JavaScript. This keeps the
  rule that the CLI links neither the runtime nor a backend: `CiderInspector`
  depends only on `CiderCore` and `CiderUITree`.

**Source origins**

- `SourceOrigin` and `NodeOrigins` in `CiderCore`, and
  `ApplicationScene.origins`: every view records the file, line and column it
  was written at, and which of its values the developer actually wrote. Origins
  travel beside the tree, like actions and text-input handlers, so `UINode`
  stays pure comparable data.
- Captured through defaulted `#filePath`/`#line`/`#column` parameters placed
  last in every view initializer and modifier, so no call site mentions them and
  trailing-closure matching is unaffected.
- `VStack.spacing`/`alignment` and `List.spacing` became optional parameters
  defaulting to `nil` rather than to their previous constants. Behaviour is
  identical when omitted; what changes is that "the caller wrote a value" is now
  distinguishable from "the caller did not", which is what decides whether an
  edit rewrites an argument or inserts one.
- Synthetic wrapper nodes -- `ScrollView`'s `/wrap`, `List`'s `/rows`,
  `NavigationView`'s `/screen`, `Modal`'s two slots, and the root stack lowering
  builds for a multi-node body -- deliberately record no origin. Nobody wrote
  them.
- The inspector snapshot carries a node's origin and a per-property origin, and
  the editor panel shows `File.swift:42` beside a written value and `default`
  beside one nobody wrote.
- Conformance IDs `EDIT-ORIGIN-001` through `EDIT-ORIGIN-004`.

**Toolchain**

- `cider doctor` — checks host OS, architecture, Swift version, C compiler,
  pkg-config, the X11/FreeType/fontconfig development packages, and `DISPLAY`.
  Failures carry an actionable remedy; unverifiable checks report themselves as
  unverified rather than passing.
- `cider build` — project discovery, manifest validation, SwiftPM build
  orchestration, artifact resolution.
- `cider run` — build, device-profile resolution, launch-descriptor generation,
  subprocess launch.
- `Cider.yaml` manifest with a project-owned YAML-subset parser: line-numbered
  diagnostics, unknown keys rejected, every problem reported at once.
- Versioned launch descriptor as the CLI-to-runtime contract.

**Runtime**

- `ApplicationRuntime` — lifecycle, event loop, invalidation, render scheduling,
  logging, device profile.
- `Touch` abstraction and pointer-to-touch translation, including letterbox
  offset handling.
- Hit testing, press tracking, and drag-off cancellation.
- Five log levels on two channels, so developer output stays distinguishable
  from Cider's own.
- Structured `Diagnostic` type carrying what failed, where, why, and how to fix
  it.

**UI**

- `CiderApp`, `CiderView`, `Text`, `Button`, `VStack`, `@CiderState`,
  `CiderViewBuilder`.
- Normalized UI tree (`TextNode`, `ButtonNode`, `VStackNode`) with stable
  structural identity.
- Two-pass layout engine.
- Render tree of ordered draw commands plus hit regions.
- Software rasterizer with analytically antialiased rounded rectangles and
  alpha-composited glyph masks.

**Hosts**

- Abstract host interfaces: `HostBackend`, `HostWindow`, `HostEvent`,
  `TextEngine`.
- Linux backend over X11 and FreeType/fontconfig, behind two thin C shims.
- Headless testing backend with a deterministic text engine.
- `CiderHostBootstrap` as the single point of backend selection.

**Other**

- `phone-standard` device profile.
- Textual inspector dumps of the UI tree and render tree.
- `examples/hello-cider` reference application.
- 103 tests across unit, conformance, integration and visual-regression suites.
- ADRs 0001–0005.

### Known limitations

Listed in full under "Current limitations" in `README.md`. In short: three UI
node kinds, no services, single-line left-to-right text, one device profile,
Linux and X11 only.
