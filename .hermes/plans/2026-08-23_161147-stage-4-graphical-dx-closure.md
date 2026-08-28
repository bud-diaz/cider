# Stage 4 Graphical Developer Experience Closure Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace Stage 4's text-first MVP caveat with a real local developer console: graphical inspector UI, live file-watching rebuild/relaunch, request-capture proxy, and a rich sandbox browser.

**Architecture:** Keep the existing command-line surfaces intact, but add a new local-only `cider dev` command that starts a browser-based dashboard and supervises the app process. Runtime/application state crosses the process boundary through explicit dev-mode artifacts: JSON inspector snapshots, a local capture proxy endpoint, and sandbox file APIs; the CLI still does not link host backends or application runtime code.

**Tech Stack:** Swift 6.0, SwiftPM, Foundation/FoundationNetworking, CiderCore/CiderProject/CiderInspector, existing Cider runtime and host abstractions, self-contained HTML/CSS/JS served by a small local HTTP + Server-Sent Events dev server, polling file watcher first (portable and dependency-free), optional Linux inotify later.

---

## Current Context

Stage 4 is currently marked as **MVP done** in `docs/05-implementation-roadmap.md`, but `HANDOFF.md`, `README.md`, and `docs/04-compatibility-specification.md` explicitly say it is text-first only:

- `cider inspect` prints manifest/sandbox/scan summaries.
- `cider run --inspect` logs textual UI tree dumps.
- `cider network` finds literal `CiderHTTP` URL call sites only.
- `cider storage` lists sandbox files only.
- `cider dev-loop` documents `swift build` + `cider run --no-build`, but does not watch or reload.

The closing slice should turn those into an integrated local workflow without pretending to be an IDE or a device emulator.

## Non-Negotiable Boundaries

- Do **not** add Apple/iOS binary execution claims.
- Do **not** route arbitrary host system traffic through the proxy. Capture Cider app requests only.
- Bind all dev-server/proxy ports to `127.0.0.1` only.
- Redact sensitive headers before rendering/logging captured requests.
- Preserve existing text commands for CI/script users.
- Keep the `cider` executable free of host backend dependencies; it may orchestrate subprocesses but should not import `CiderRuntime`, `CiderUI`, `CiderHostLinux`, or X11 modules.
- Keep the first implementation dependency-free unless tests prove a local HTTP server is not viable with small socket code. If that happens, choose SwiftNIO deliberately in a separate dependency task.

## Proposed User Experience

```bash
cider dev --path examples/rest-client-cider --open
```

Expected behavior:

1. Builds and launches the app.
2. Starts a local dashboard, for example `http://127.0.0.1:5757/`.
3. Dashboard shows:
   - current app/process status;
   - live UI tree + render command inspector;
   - recent rebuild/relaunch events;
   - captured `CiderHTTP` requests/responses;
   - sandbox files grouped by `Documents`, `Cache`, `tmp`, `Preferences`.
4. Editing `.swift` or `Cider.yaml` triggers rebuild + relaunch.
5. Network requests made through `CiderHTTP` appear in the Request Capture tab.
6. Sandbox files can be listed/read as text and reset via explicit action.

---

## Milestone 1: Inspector Snapshots as Structured Data

### Task 1: Add structured inspector models

**Objective:** Give the graphical UI stable JSON data instead of scraping text dumps.

**Files:**
- Modify: `inspector/Sources/CiderInspector/Inspector.swift`
- Test: `tests/unit/InspectorSnapshotTests.swift`
- Possibly modify: `Package.swift` test target dependencies if `CiderUnitTests` needs `CiderInspector`

**Implementation notes:**

Add public Codable/Sendable DTOs near `Inspector`:

```swift
public struct InspectorSnapshot: Codable, Equatable, Sendable {
    public var frameCount: Int
    public var generatedAtMilliseconds: Int64
    public var nodes: [InspectorNodeSnapshot]
    public var renderCommands: [InspectorRenderCommandSnapshot]
    public var hitRegions: [InspectorHitRegionSnapshot]
}

public struct InspectorNodeSnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var kind: String
    public var label: String
    public var frame: InspectorRectSnapshot?
    public var depth: Int
}
```

Keep the existing text methods unchanged. Add methods like:

```swift
public static func snapshot(node: UINode, layout: LayoutBox?, renderTree: RenderTree?, frameCount: Int) -> InspectorSnapshot
public static func json(_ snapshot: InspectorSnapshot) throws -> String
```

**Tests:**

- Build a small `UINode.vstack` containing `Text` and `Button`.
- Layout it with `LayoutEngine.layoutCentered`.
- Build a `RenderTree`.
- Assert `snapshot.nodes` includes kind names, IDs, labels, and frames.
- Assert `Inspector.json(snapshot)` round-trips through `JSONDecoder`.

**Verify:**

```bash
swift test --filter InspectorSnapshotTests
```

Expected: new tests pass.

### Task 2: Persist inspector snapshots from the runtime

**Objective:** Let an external dev server observe runtime state without linking the runtime.

**Files:**
- Modify: `runtime/Sources/CiderCore/LaunchDescriptor.swift`
- Modify: `runtime/Sources/CiderRuntime/ApplicationRuntime.swift`
- Modify: `compiler-support/Sources/CiderProject/Manifest.swift` if descriptor encode/decode helpers live there
- Modify tests: `tests/unit/LaunchDescriptorTests.swift`
- Add/modify conformance or runtime tests for snapshot writing

**Implementation notes:**

Add to `LaunchDescriptor`:

```swift
public var inspectorSnapshotPath: String
```

Default to `""` for backward compatibility. Include it in encoding/decoding.

In `ApplicationRuntime.renderFrame()`, after `self.renderTree = tree` and after frame count increments, if `descriptor.inspectorEnabled` and `inspectorSnapshotPath` is non-empty:

- Build `InspectorSnapshot`.
- Write JSON atomically to the configured path.
- Keep failures non-fatal but log a warning once per failure mode.

Prefer a single latest snapshot file first:

```text
.cider/dev/inspector/latest.json
```

The dev server can poll it cheaply. Avoid JSONL until the UI needs historical frame scrubbing.

**Tests:**

- Extend `LaunchDescriptorTests` for round-trip/default behavior.
- Runtime test launches with `TestingHostBackend`, `inspectorEnabled: true`, and temp snapshot path.
- After launch/pump, assert file exists and decodes as `InspectorSnapshot`.

**Verify:**

```bash
swift test --filter LaunchDescriptorTests
swift test --filter Inspector
```

Expected: launch descriptor and snapshot persistence tests pass.

---

## Milestone 2: Dev Workspace and Local Dashboard Server

### Task 3: Add dev workspace path helpers

**Objective:** Centralize `.cider/dev` paths used by watcher, inspector, proxy, and dashboard.

**Files:**
- Create: `compiler-support/Sources/CiderProject/DevWorkspace.swift`
- Test: `tests/unit/DevWorkspaceTests.swift`

**Implementation notes:**

Create a small value type:

```swift
public struct DevWorkspace: Sendable {
    public var root: URL
    public var inspectorSnapshotURL: URL
    public var eventsURL: URL
    public var proxyLogURL: URL

    public init(project: Project) {
        root = project.workDirectory.appendingPathComponent("dev", isDirectory: true)
        inspectorSnapshotURL = root.appendingPathComponent("inspector/latest.json")
        eventsURL = root.appendingPathComponent("events.jsonl")
        proxyLogURL = root.appendingPathComponent("proxy/requests.jsonl")
    }

    public func prepare() throws { ... }
}
```

**Tests:**

- Assert paths are under `project.workDirectory/dev`.
- `prepare()` creates parent directories.

**Verify:**

```bash
swift test --filter DevWorkspaceTests
```

### Task 4: Implement a minimal loopback HTTP server

**Objective:** Serve dashboard assets and JSON APIs locally without pulling runtime/backend dependencies into the CLI.

**Files:**
- Create: `compiler-support/Sources/CiderProject/DevHTTPServer.swift`
- Test: `tests/unit/DevHTTPServerTests.swift`

**Implementation notes:**

Start small:

- Bind only `127.0.0.1`.
- Support `GET`, `POST`, and `OPTIONS` enough for local dashboard APIs.
- Return `Connection: close` for every response.
- No TLS; local only.
- `port: 0` should choose an available port and expose the bound port.

Suggested API:

```swift
public struct DevHTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    public var headers: [String: String]
    public var body: Data
}

public struct DevHTTPResponse: Sendable {
    public var status: Int
    public var contentType: String
    public var body: Data
}

public final class DevHTTPServer {
    public init(host: String = "127.0.0.1", port: Int = 0, handler: @escaping @Sendable (DevHTTPRequest) -> DevHTTPResponse)
    public func start() throws
    public func stop()
    public var boundURL: URL { get }
}
```

Use blocking sockets on a background thread/queue. This is enough for a local dev server and easier to audit than a dependency.

**Tests:**

- Start server on port 0.
- Fetch `/health` using `URLSession`.
- Assert response status/body.
- Assert `boundURL.host == "127.0.0.1"`.

**Verify:**

```bash
swift test --filter DevHTTPServerTests
```

### Task 5: Add dashboard HTML assets

**Objective:** Provide the graphical inspector shell.

**Files:**
- Create: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Test: `tests/unit/DevDashboardAssetsTests.swift`

**Implementation notes:**

Embed self-contained assets as Swift string literals for now:

- `indexHTML`
- `appCSS`
- `appJS`

Dashboard sections:

- Status bar: project name, process state, build status, server URL.
- Inspector tab: tree table + render-command list.
- Network tab: request table + detail drawer.
- Sandbox tab: directory tree + text preview + reset button.
- Events tab: build/relaunch log.

JS should poll initial JSON endpoints first; SSE can be added in a later task.

**Tests:**

- Assert assets include root element IDs used by JS.
- Assert no external CDN URLs are required.

**Verify:**

```bash
swift test --filter DevDashboardAssetsTests
```

### Task 6: Route dashboard and inspector API endpoints

**Objective:** Serve UI and runtime state through `cider dev`'s local API.

**Files:**
- Create: `compiler-support/Sources/CiderProject/DevDashboardServer.swift`
- Test: `tests/unit/DevDashboardServerTests.swift`

**Endpoints:**

```text
GET /                         -> HTML
GET /assets/app.css           -> CSS
GET /assets/app.js            -> JS
GET /api/status               -> process/build/server status JSON
GET /api/inspector/latest     -> latest InspectorSnapshot JSON or 204/empty state
GET /api/events               -> recent dev events JSON
```

**Tests:**

- With no inspector snapshot, `/api/inspector/latest` returns `204` or a JSON `{ "available": false }` consistently.
- With a temp snapshot file, endpoint returns the exact JSON.
- `/` returns `text/html` and contains dashboard root.

**Verify:**

```bash
swift test --filter DevDashboardServerTests
```

---

## Milestone 3: File-Watching Hot Reload

### Task 7: Add a dependency-free project file watcher

**Objective:** Detect changes to app source/manifests and ignore build/dev artifacts.

**Files:**
- Create: `compiler-support/Sources/CiderProject/ProjectFileWatcher.swift`
- Test: `tests/unit/ProjectFileWatcherTests.swift`

**Implementation notes:**

Use polling first for portability:

- Watch `*.swift`, `Package.swift`, `Cider.yaml`.
- Ignore `.build`, `.git`, `.cider`, `DerivedData`.
- Store last seen modification times and sizes.
- Debounce changes for ~300ms.

Suggested API:

```swift
public struct ProjectChange: Equatable, Sendable {
    public var path: String
    public var kind: Kind
}

public final class ProjectFileWatcher {
    public init(project: Project, intervalMilliseconds: Int = 500)
    public func scan() throws -> [ProjectChange]
}
```

The long-running loop can live in the dev session; this type only scans and diffs.

**Tests:**

- Initial scan returns empty after baseline.
- Editing a Swift file emits a change.
- Writing under `.build` and `.cider` emits nothing.
- Multiple quick writes collapse in the session debounce test later.

**Verify:**

```bash
swift test --filter ProjectFileWatcherTests
```

### Task 8: Add dev-process build/relaunch supervisor

**Objective:** Build and relaunch the app when watched files change.

**Files:**
- Create: `compiler-support/Sources/CiderProject/DevSession.swift`
- Modify: `cli/Sources/cider/DevToolsCommands.swift`
- Modify: `cli/Sources/cider/main.swift`
- Modify: `cli/Sources/cider/Usage.swift`
- Test: `tests/unit/DevSessionTests.swift`

**Implementation notes:**

`DevSession` should orchestrate, not render:

```swift
public final class DevSession {
    public init(project: Project, configuration: String, openBrowser: Bool)
    public func start() throws
    public func stop()
    public func pollOnce() throws
}
```

Responsibilities:

1. Prepare `DevWorkspace`.
2. Build project using existing `SwiftToolchain`/`BuildCommand` logic where possible.
3. Launch app as a subprocess with a launch descriptor containing:
   - `inspectorEnabled: true`
   - `inspectorSnapshotPath: workspace.inspectorSnapshotURL.path`
   - later proxy URL from Milestone 4
4. On changes, terminate old process, rebuild, and launch fresh artifact.
5. Append structured events to memory and `events.jsonl`.

Because `BuildCommand` currently lives in CLI code, decide one of two routes:

- Preferred: move reusable build/artifact helpers from `cli/Sources/cider/BuildCommand.swift` into `CiderProject` so both `BuildCommand` and `DevSession` use one implementation.
- Acceptable short-term: keep subprocess `swift build --package-path ...` in `DevSession`, but do not duplicate manifest/project parsing.

**Tests:**

Use an injectable process runner to avoid starting real apps in unit tests:

- `DevSession` calls build before launch.
- Change event triggers stop -> build -> launch.
- Build failure records an event and does not relaunch stale app.

**Verify:**

```bash
swift test --filter DevSessionTests
```

### Task 9: Wire `cider dev` command

**Objective:** Expose the integrated dev loop.

**Files:**
- Modify: `cli/Sources/cider/DevToolsCommands.swift`
- Modify: `cli/Sources/cider/main.swift`
- Modify: `cli/Sources/cider/Usage.swift`
- Test: `tests/unit/DeveloperExperienceTests.swift`

**CLI:**

```text
cider dev [--path <dir>] [--configuration debug|release] [--port <n>] [--open] [--no-open]
```

`--open` should try `xdg-open` on Linux, but failing to open the browser is not fatal; print the URL.

**Verify:**

```bash
swift test --filter DeveloperExperienceTests
swift build
.build/debug/cider --help | grep "dev"
```

Expected: help lists `dev`; command parsing works.

---

## Milestone 4: Request-Capture Proxy

### Task 10: Add request capture models and redaction

**Objective:** Define a durable, safe request/response record for the Network tab.

**Files:**
- Create: `runtime/Sources/CiderCore/RequestCapture.swift`
- Test: `tests/unit/RequestCaptureTests.swift`

**Implementation notes:**

Models should be Codable/Equatable:

```swift
public struct CapturedHTTPRequest: Codable, Equatable, Sendable {
    public var id: String
    public var startedAtMilliseconds: Int64
    public var method: String
    public var url: String
    public var requestHeaders: [String: String]
    public var statusCode: Int?
    public var responseHeaders: [String: String]
    public var responseBodyPreview: String
    public var error: String?
    public var durationMilliseconds: Int?
}
```

Redact at least:

- `authorization`
- `cookie`
- `set-cookie`
- `x-api-key`
- any header containing `token`, `secret`, or `key`

Reuse `LogRedaction` behavior where possible, but header redaction should be explicit and testable.

**Verify:**

```bash
swift test --filter RequestCaptureTests
```

### Task 11: Implement local proxy endpoint in dashboard server

**Objective:** Let app-side `CiderHTTP` route requests through the dev server for capture.

**Files:**
- Modify: `compiler-support/Sources/CiderProject/DevDashboardServer.swift`
- Create/modify tests: `tests/unit/RequestCaptureProxyTests.swift`

**Endpoint:**

```text
POST /api/proxy/fetch
```

Request body:

```json
{
  "id": "uuid",
  "method": "GET",
  "url": "https://example.com/api",
  "headers": {}
}
```

Response body:

```json
{
  "statusCode": 200,
  "headers": { "content-type": "application/json" },
  "body": "..."
}
```

Keep MVP scope to `GET` first because `CiderHTTP` currently exposes only `get` and `getBlocking`. Structure for future methods, but do not implement unused methods.

The server should:

1. Validate `http`/`https` only.
2. Forward with `URLSession`.
3. Capture request/response/error record in memory and append JSONL to `workspace.proxyLogURL`.
4. Expose:

```text
GET /api/network/requests
GET /api/network/requests/<id>
```

**Tests:**

- Use a local fake upstream HTTP server from `DevHTTPServer`.
- POST `/api/proxy/fetch` to fetch fake upstream.
- Assert captured record includes URL, status, preview, duration.
- Assert sensitive headers are redacted.

**Verify:**

```bash
swift test --filter RequestCaptureProxyTests
```

### Task 12: Route `CiderHTTP` through the capture proxy in dev mode

**Objective:** Capture app requests without asking users to change app source.

**Files:**
- Modify: `runtime/Sources/CiderCore/LaunchDescriptor.swift`
- Modify: `compatibility/Sources/CiderUI/Services.swift`
- Modify: `compiler-support/Sources/CiderProject/Manifest.swift` descriptor builder if needed
- Modify: `cli/Sources/cider/RunCommand.swift`
- Modify: `compiler-support/Sources/CiderProject/DevSession.swift`
- Tests: `tests/unit/LaunchDescriptorTests.swift`, `tests/conformance/Stage3ServiceTests.swift`, new capture-specific tests

**Implementation notes:**

Add to `LaunchDescriptor`:

```swift
public var requestCaptureProxyURL: String
```

Default `""`.

When `CiderServiceContext.current?.requestCaptureProxyURL` is non-empty, `CiderHTTP.get` and `getBlocking` should call the local proxy endpoint instead of the target URL directly.

This requires plumbing from `LaunchDescriptor` into `RuntimeContext`:

- Add `requestCaptureProxyURL` to `RuntimeContext`.
- Set it in `ApplicationRuntime.launch()`.
- Store it in `CiderServiceContext.current` via context.

**Important:** Do not use `CiderHTTP` recursively to call the proxy. Use `URLSession`/`Data(contentsOf:)` directly inside `Services.swift`.

**Tests:**

- Existing `NET-HTTP-001` permission-denied behavior still denies before proxy use.
- With permission true and proxy URL set, `CiderHTTP.getBlocking("http://upstream")` calls proxy endpoint.
- With proxy URL empty, existing direct behavior remains.

**Verify:**

```bash
swift test --filter Stage3ServiceTests
swift test --filter RequestCapture
```

### Task 13: Build Network tab UI

**Objective:** Display captured requests clearly in the dashboard.

**Files:**
- Modify: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Tests: `tests/unit/DevDashboardAssetsTests.swift`

**UI behavior:**

- Request table columns: time, method, status, duration, URL.
- Detail panel: redacted request headers, response headers, body preview, error.
- Empty state: "No CiderHTTP requests captured yet."
- Poll `/api/network/requests` every 1s or refresh on SSE event after Task 17.

**Verify:**

```bash
swift test --filter DevDashboardAssetsTests
```

---

## Milestone 5: Rich Sandbox Browser

### Task 14: Add sandbox browser APIs

**Objective:** Let the dashboard inspect and reset sandbox files safely.

**Files:**
- Create: `compiler-support/Sources/CiderProject/SandboxBrowser.swift`
- Modify: `compiler-support/Sources/CiderProject/DevDashboardServer.swift`
- Test: `tests/unit/SandboxBrowserTests.swift`

**API endpoints:**

```text
GET /api/sandbox/tree
GET /api/sandbox/file?path=Documents/note.txt
POST /api/sandbox/reset
```

**Implementation notes:**

- Use `SandboxPathResolver.dataRoot(for:)` for the root.
- Normalize paths and reject absolute paths or `..`.
- Only read regular files.
- For MVP, preview UTF-8 text and base64/hex preview for binary/non-UTF8.
- `reset` should delete contents under the app sandbox root, then recreate `Documents`, `Cache`, and `tmp`.
- Do not expose arbitrary host paths.

**Tests:**

- Lists files grouped by area.
- Reads UTF-8 text.
- Rejects `../outside`.
- Reset deletes sandbox files but not files outside the root.

**Verify:**

```bash
swift test --filter SandboxBrowserTests
```

### Task 15: Build Sandbox tab UI

**Objective:** Make storage inspection useful without terminal commands.

**Files:**
- Modify: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Test: `tests/unit/DevDashboardAssetsTests.swift`

**UI behavior:**

- Tree grouped by `Documents`, `Cache`, `tmp`, `Preferences`.
- Click file -> preview panel with size, modified time, content preview.
- Reset button requires a typed confirmation string like `reset` or a browser confirm; typed is safer.
- After reset, refresh tree and add an event.

**Verify:**

```bash
swift test --filter DevDashboardAssetsTests
```

---

## Milestone 6: Live Dashboard Updates and Polish

### Task 16: Add Server-Sent Events for live updates

**Objective:** Avoid blind polling while keeping protocol complexity lower than WebSockets.

**Files:**
- Modify: `compiler-support/Sources/CiderProject/DevHTTPServer.swift`
- Modify: `compiler-support/Sources/CiderProject/DevDashboardServer.swift`
- Modify: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Test: `tests/unit/DevDashboardServerTests.swift`

**Endpoint:**

```text
GET /api/events/stream
```

Events:

```text
event: status
data: {...}

event: inspector
data: {"available": true}

event: network
data: {"id":"..."}

event: sandbox
data: {"changed":true}
```

If SSE complicates the small server too much, keep polling and document that tradeoff. Do not derail Stage 4 closure on protocol perfection.

**Verify:**

```bash
swift test --filter DevDashboardServerTests
```

### Task 17: Improve inspector UI interaction

**Objective:** Make the graphical inspector useful, not just a JSON dump.

**Files:**
- Modify: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Possibly modify: `inspector/Sources/CiderInspector/Inspector.swift` to include additional metadata
- Tests: `tests/unit/DevDashboardAssetsTests.swift`, `tests/unit/InspectorSnapshotTests.swift`

**UI behavior:**

- Tree rows indented by depth.
- Selecting a node highlights details: ID, kind, label, frame.
- Render command list shows painter order.
- Hit regions are visible in a separate list.
- Empty state explains: "Launch with `cider dev` and wait for first frame."

Optional if fast: render a simple canvas overlay using frame coordinates. Do not block closure on pixel-perfect overlay.

**Verify:**

```bash
swift test --filter InspectorSnapshotTests
swift test --filter DevDashboardAssetsTests
```

### Task 18: Add events timeline

**Objective:** Give developers a clear explanation of what the dev loop did.

**Files:**
- Create: `compiler-support/Sources/CiderProject/DevEventLog.swift`
- Modify: `compiler-support/Sources/CiderProject/DevSession.swift`
- Modify: `compiler-support/Sources/CiderProject/DevDashboardServer.swift`
- Modify: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Test: `tests/unit/DevEventLogTests.swift`

**Events:**

- server started
- build started/succeeded/failed
- app launched/exited
- file changes detected
- reload skipped due to build failure
- request captured
- sandbox reset

**Verify:**

```bash
swift test --filter DevEventLogTests
```

---

## Milestone 7: End-to-End Validation and Documentation

### Task 19: Add integration test for `cider dev` smoke path

**Objective:** Prove the dashboard server can start and expose basic APIs through the real CLI path.

**Files:**
- Create: `tests/integration/DevCommandIntegrationTests.swift`
- Possibly modify: `Package.swift` integration test dependencies

**Implementation notes:**

Avoid a forever-running test command. Add a test-friendly flag:

```text
cider dev --path <fixture> --once
```

`--once` should:

1. Prepare workspace.
2. Build or validate setup if practical.
3. Start dashboard server.
4. Print dashboard URL.
5. Fetch/validate internal health endpoint.
6. Shut down.

If building fixture apps is too slow for unit CI, keep it in integration tests and filterable.

**Verify:**

```bash
swift test --filter DevCommandIntegrationTests
```

### Task 20: Manual/Xvfb validation script

**Objective:** Exercise the real launch path enough to close the previous manual-validation caveat.

**Files:**
- Create: `scripts/validate-stage4-dev.sh`
- Modify docs to reference it

**Script behavior:**

```bash
#!/usr/bin/env bash
set -euo pipefail
swift build
swift test
xvfb-run -a .build/debug/cider dev --path examples/rest-client-cider --once
xvfb-run -a .build/debug/cider run --path examples/ui-showcase --inspect --no-build --log-level debug
```

Adjust commands after implementation reality, but keep the script honest: it must fail on broken dashboard startup or broken inspect snapshot generation.

**Verify:**

```bash
bash scripts/validate-stage4-dev.sh
```

### Task 21: Update docs and roadmap from MVP caveat to Stage 4 closed

**Objective:** Make the project status match reality after tests pass.

**Files:**
- Modify: `README.md`
- Modify: `docs/04-compatibility-specification.md`
- Modify: `docs/05-implementation-roadmap.md`
- Modify: `docs/06-testing-strategy.md`
- Modify: `HANDOFF.md`
- Possibly modify: `CHANGELOG.md`

**Content changes:**

- Replace "text-first MVP" caveats with accurate completed Stage 4 statement.
- Document `cider dev` command and dashboard URL behavior.
- Document local-only proxy security boundaries.
- Document file watcher limitations: polling/debounce, restart not in-process hot-swap.
- Document sandbox browser reset behavior.
- Keep explicit non-goals: no iOS binary execution, no arbitrary system proxy, no IDE extension yet.

**Verify:**

```bash
swift test
bash scripts/validate-stage4-dev.sh
```

### Task 22: Full Docker/CI-equivalent verification

**Objective:** Confirm closure on the same Swift 6 Noble path used by prior continuations.

**Files:**
- No source changes unless validation exposes issues.

**Commands:**

Use the repo's established Docker path from `HANDOFF.md` if host Swift is unavailable:

```bash
docker run --rm \
  -v /home/bud/cider:/home/bud/cider \
  -w /home/bud/cider \
  swift:6.0-noble \
  bash -lc 'apt-get update && apt-get install -y libx11-dev libfreetype-dev libfontconfig-dev xvfb && swift build && swift test && bash scripts/validate-stage4-dev.sh'
```

If local Swift is installed and dependencies are present:

```bash
swift build
swift test
bash scripts/validate-stage4-dev.sh
```

Expected: all tests pass; validation script passes; `cider dev --once` prints a loopback dashboard URL and exits cleanly.

---

## Files Likely to Change

### New files

- `compiler-support/Sources/CiderProject/DevWorkspace.swift`
- `compiler-support/Sources/CiderProject/DevHTTPServer.swift`
- `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- `compiler-support/Sources/CiderProject/DevDashboardServer.swift`
- `compiler-support/Sources/CiderProject/ProjectFileWatcher.swift`
- `compiler-support/Sources/CiderProject/DevSession.swift`
- `compiler-support/Sources/CiderProject/DevEventLog.swift`
- `compiler-support/Sources/CiderProject/SandboxBrowser.swift`
- `runtime/Sources/CiderCore/RequestCapture.swift`
- `tests/unit/InspectorSnapshotTests.swift`
- `tests/unit/DevWorkspaceTests.swift`
- `tests/unit/DevHTTPServerTests.swift`
- `tests/unit/DevDashboardAssetsTests.swift`
- `tests/unit/DevDashboardServerTests.swift`
- `tests/unit/ProjectFileWatcherTests.swift`
- `tests/unit/DevSessionTests.swift`
- `tests/unit/RequestCaptureTests.swift`
- `tests/unit/RequestCaptureProxyTests.swift`
- `tests/unit/SandboxBrowserTests.swift`
- `tests/unit/DevEventLogTests.swift`
- `tests/integration/DevCommandIntegrationTests.swift`
- `scripts/validate-stage4-dev.sh`

### Existing files

- `Package.swift`
- `inspector/Sources/CiderInspector/Inspector.swift`
- `runtime/Sources/CiderCore/LaunchDescriptor.swift`
- `runtime/Sources/CiderRuntime/RuntimeContext.swift`
- `runtime/Sources/CiderRuntime/ApplicationRuntime.swift`
- `compatibility/Sources/CiderUI/Services.swift`
- `compiler-support/Sources/CiderProject/Manifest.swift`
- `cli/Sources/cider/DevToolsCommands.swift`
- `cli/Sources/cider/main.swift`
- `cli/Sources/cider/Usage.swift`
- `cli/Sources/cider/RunCommand.swift`
- `tests/unit/LaunchDescriptorTests.swift`
- `tests/unit/DeveloperExperienceTests.swift`
- `tests/conformance/Stage3ServiceTests.swift`
- `README.md`
- `docs/04-compatibility-specification.md`
- `docs/05-implementation-roadmap.md`
- `docs/06-testing-strategy.md`
- `HANDOFF.md`
- `CHANGELOG.md`

---

## Acceptance Criteria

Stage 4 is closed only when all of these are true:

- `cider dev --path examples/rest-client-cider --once` starts dashboard infrastructure and exits cleanly.
- `cider dev --path <app>` in normal mode prints a `http://127.0.0.1:<port>/` dashboard URL.
- Editing app Swift source causes rebuild/relaunch, with visible build/reload events.
- Runtime writes structured inspector snapshots in dev/inspect mode.
- Dashboard renders current UI tree, render commands, and hit regions.
- `CiderHTTP` requests made while launched under `cider dev` appear in the Network tab.
- Captured headers are redacted before display/persistence.
- Sandbox tab lists, previews, and resets files without escaping the app sandbox root.
- Existing commands (`inspect`, `network`, `storage`, `dev-loop`, `run --inspect`) still work.
- `swift test` passes.
- `scripts/validate-stage4-dev.sh` passes locally or in Swift 6 Noble Docker.
- Documentation no longer overstates or understates Stage 4.

---

## Risks and Tradeoffs

- **Small HTTP server risk:** Hand-rolled HTTP can become a tarpit. Keep it local-only, HTTP/1.1 close-only, and minimal. If request parsing gets messy, stop and add SwiftNIO as a deliberate dependency with tests.
- **"Hot reload" wording:** This plan implements file-watching rebuild/relaunch, not in-process Swift hot code swap. Docs must call it rebuild/relaunch hot reload.
- **Proxy scope:** Capturing only `CiderHTTP` is the right MVP. Do not attempt system proxy settings or arbitrary `URLSession` interception.
- **SSE complexity:** SSE is nice-to-have polish. Polling every 500-1000ms is acceptable if it keeps the feature shippable.
- **Dashboard assets in Swift strings:** Good for a first integrated tool. If assets grow unwieldy, move to generated static resources later.
- **Process lifecycle:** Killing/relaunching developer apps can leak child processes if not handled carefully. Add tests for stop paths and document if signal handling is limited.

## Suggested Commit Sequence

1. `feat(inspector): add structured runtime snapshots`
2. `feat(dev): add local dashboard server`
3. `feat(dev): add file watcher and relaunch session`
4. `feat(cli): add cider dev command`
5. `feat(network): capture CiderHTTP requests through local proxy`
6. `feat(dev): add sandbox browser APIs and UI`
7. `feat(dev): add live dashboard updates and event timeline`
8. `test(dev): add stage 4 validation script`
9. `docs: mark stage 4 developer experience closed`

## Execution Note

Implement this plan in order. Do not update roadmap/status docs to "Stage 4 closed" until after the dashboard, watcher, proxy capture, sandbox browser, and validation script all pass real tests.
