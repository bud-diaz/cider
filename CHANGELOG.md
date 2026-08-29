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
