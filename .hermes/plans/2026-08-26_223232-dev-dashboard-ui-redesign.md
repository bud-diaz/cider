# CIDER Dev Dashboard UI Redesign Implementation Plan

> **For Hermes:** Use frontend-visual-redesign principles to implement this plan directly in the embedded dashboard assets, then verify with Swift tests and browser QA.

**Goal:** Redesign the `cider dev` companion web dashboard so it follows `dev-tool-ui-redesign-spec.md` as source of truth: dark IDE-inspired surfaces, code-forward typography, muted zinc panels, state-driven rose/amber/emerald accents, accessible row selection, editor chrome, proof/log panels, and restrained motion.

**Architecture:** The dashboard is currently a self-contained static asset bundle embedded in `compiler-support/Sources/CiderProject/DevDashboardAssets.swift` and locked by snapshot tests. The redesign should keep that architecture, avoiding a frontend build pipeline unless genuinely needed, and update the locked snapshots plus static preview after implementation.

**Tech Stack:** Swift Package Manager, embedded HTML/CSS/vanilla JS, XCTest snapshot locks, browser smoke testing.

---

## Source of truth

- Read and follow `dev-tool-ui-redesign-spec.md`.
- Use `dev-tool-landing-page-design-spec.md` only as the upstream reference for code-window/proof-panel patterns.
- Preserve live API behavior from the current dashboard:
  - `/api/status`
  - `/api/inspector/latest`
  - `/api/network/requests`
  - `/api/sandbox/tree`
  - `/api/sandbox/file?path=...`
  - `/api/events`
  - `POST /api/sandbox/reset`

## Task 1: Replace global dashboard tokens

**Objective:** Move from the older CIDER amber/graphite look to the spec’s zinc/rose/amber/emerald IDE palette.

**Files:**
- Modify: `compiler-support/Sources/CiderProject/DevDashboardAssets.swift`
- Modify snapshots: `tests/unit/Snapshots/DevDashboardAssets/app.css`, `index.html`, `app.js`

**Implementation details:**
- Add exact tokens from spec:
  - `--bg-page: #09090b;`
  - `--bg-panel: #111115;`
  - `--bg-panel-deep: #0d0d0f;`
  - `--bg-panel-hover: #15151a;`
  - `--border-default: rgba(39, 39, 42, 0.78);`
  - `--border-hover: #3f3f46;`
  - `--text-primary: #fafafa;`
  - `--text-body: #a1a1aa;`
  - `--text-muted: #71717a;`
  - `--text-dim: #52525b;`
  - `--accent-rose: #fb7185;`
  - `--accent-amber: #fbbf24;`
  - `--accent-emerald: #34d399;`
  - `--selection: rgba(244, 63, 94, 0.3);`
- Use `ui-monospace, "SF Mono", "JetBrains Mono", monospace` as dominant font for technical UI.
- Keep transitions explicit; no `transition: all`, no `ease-in`.

## Task 2: Redesign HTML structure into IDE surfaces

**Objective:** Make the UI itself read like a compact code editor/dashboard, not a marketing shell.

**Files:**
- Modify: `DevDashboardAssets.indexHTML`

**Implementation details:**
- Replace the current brand/topbar/tabs shell with:
  - IDE titlebar with three muted dots.
  - Filename chip: `cider.dev/session.config`.
  - Status pill on the right.
  - Sidebar/resource tree with tab buttons styled as active rows.
  - Main editor/config viewer panel for Inspector.
  - Right rail proof/status panels for CLI output, request capture, sandbox, and events.
- Preserve all IDs required by JS (`status`, `tree`, `commands`, `requests`, `files`, `preview`, `eventLog`, `resetSandbox`).

## Task 3: Rewrite CSS as shared primitives

**Objective:** Implement reusable primitives for shell, titlebar, resource rows, editor windows, proof panels, status cards, log lines, and state accents.

**Files:**
- Modify: `DevDashboardAssets.appCSS`

**Implementation details:**
- Add primitives:
  - `.editor-window`, `.editor-titlebar`, `.window-dot`, `.file-chip`, `.editor-body`
  - `.resource-row`, `.resource-row[aria-selected="true"]`
  - `.proof-panel`, `.proof-header`, `.proof-body`
  - `.status-card`, `.severity-success`, `.severity-warning`, `.severity-error`, `.severity-neutral`
  - `.log-line`, `.line-number`, `.token-keyword`, `.token-identifier`, `.token-string`, `.token-comment`
- Add hover/focus equivalents for every reveal/selection interaction.
- Add `button:active { transform: scale(0.97); }` and visible focus states.
- Add reduced-motion override.

## Task 4: Update JS rendering and accessibility

**Objective:** Keep live dashboard data behavior while rendering real API data through the new visual system.

**Files:**
- Modify: `DevDashboardAssets.appJS`

**Implementation details:**
- Implement `escapeHTML` to prevent raw API strings from being injected into `innerHTML`.
- Keep tab/resource-row switching keyboard-accessible:
  - `aria-selected`
  - `hidden`
  - focus styles
- Render:
  - inspector nodes as selectable tree rows with line numbers and syntax-like tokens.
  - render commands in the editor body with line numbers.
  - requests as proof-panel/status-card rows with severity based on HTTP status.
  - events as CLI log lines with severity based on message/kind.
  - sandbox files as resource rows and preview as line-numbered JSON.
- Wire copy buttons to `navigator.clipboard.writeText()` with Check/success state and graceful fallback.

## Task 5: Update locked tests/snapshots

**Objective:** Bring tests in line with the new source-of-truth tokens rather than the older CIDER amber tokens.

**Files:**
- Modify: `tests/unit/DevDashboardAssetsTests.swift`
- Overwrite snapshots under `tests/unit/Snapshots/DevDashboardAssets/`

**Implementation details:**
- Replace old token assertions with the exact spec tokens.
- Add assertions for:
  - IDE titlebar/chrome.
  - filename chip.
  - rose/amber/emerald state tokens.
  - explicit clipboard copy wiring.
  - `escapeHTML` presence.
  - keyboard/focus-friendly aria state updates.
- Preserve assertions rejecting forbidden brand imagery and motion anti-patterns.

## Task 6: Generate static preview

**Objective:** Keep `.hermes/previews/cider-dev-dashboard-final.html` available for browser QA without needing the dev server.

**Files:**
- Modify/create: `.hermes/previews/cider-dev-dashboard-final.html`

**Implementation details:**
- Inline the updated CSS and JS.
- Add fixture API shims so the static preview renders a representative Inspector/Network/Sandbox/Events state.

## Verification

Run from `/home/bud/cider`:

```bash
swift test --filter DevDashboardAssetsTests
swift test
swift build
```

Then serve the static preview and inspect it in browser:

```bash
python3 -m http.server 4177 --directory .hermes/previews
```

Open `http://127.0.0.1:4177/cider-dev-dashboard-final.html` and verify:
- The screen reads as dark IDE/code editor, not the old amber brand shell.
- Primary accents are rose; success/warning/error states map to emerald/amber/rose.
- Sidebar selection has left accent border and is keyboard reachable.
- Editor/config and proof panels have titlebar chrome and monospace content.
- Copy button really copies or gracefully reports unsupported clipboard.
- Mobile width has no horizontal overflow.

## Risks / constraints

- This project has many pre-existing uncommitted changes; only touch dashboard asset/test/preview/plan files.
- Because assets are embedded static strings, Framer Motion/Tailwind/lucide should not be added unless the architecture changes. The spec says to keep reference approach if pulling React reference code, but this dashboard is vanilla embedded assets; CSS transitions are lower risk and match the design intent.
- Snapshot tests will intentionally fail until snapshots are updated.
