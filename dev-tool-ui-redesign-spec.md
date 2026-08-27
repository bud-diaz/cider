# Redesign Spec: Dev Tool Web Dashboard

**Goal:** Bring the full visual language of the `dev-tool-landing-page` reference component (dark, IDE-inspired, code-forward) into your CLI's companion web dashboard, which is primarily used for writing/viewing code and config.

**Reference:** `dev-tool-landing-page-design-spec.md` (this doc extends it — token values, syntax colors, and interaction patterns below are pulled directly from that spec unless noted as new).

---

## 1. Design Principles to Carry Over

1. **The UI itself should look like a code editor**, not decorate around one. Panels, headers, and chrome should read as IDE surfaces — title bars with dots, filename chips, monospace by default wherever content is technical.
2. **Muted by default, saturated on purpose.** Base palette stays desaturated zinc/gray; color (rose/amber/emerald) is reserved for state — active, error/warning, success — never for decoration.
3. **Reveal over display.** Secondary detail (proof panels, diagnostics, metadata) stays visually quiet until hovered/focused, then animates in. Avoid showing everything at full opacity all the time.
4. **Motion signals relationship, not decoration.** Use animated highlight bars / shared layout transitions to show "this control affects that content," the way the walkthrough-to-code-line linking works in the reference.

---

## 2. Design Tokens (adopt as-is)

### 2.1 Color

| Token | Value | Apply to |
|---|---|---|
| `--bg-page` | `#09090b` | App shell background |
| `--bg-panel` | `#111115` | Sidebar, toolbar, panel headers |
| `--bg-panel-deep` | `#0d0d0f` | Code/editor pane body, log pane body |
| `--bg-panel-hover` | `#15151a` | Hoverable list rows, file tree items |
| `--border-default` | `zinc-800` (`#27272a`) at 50–80% opacity | All panel dividers |
| `--border-hover` | `zinc-700` (`#3f3f46`) | Hovered/focused panel or row |
| `--text-primary` | `white` / `zinc-100` | Headings, active file name, primary labels |
| `--text-body` | `zinc-400` | Descriptions, secondary UI copy |
| `--text-muted` | `zinc-500` | Line numbers, timestamps, inactive labels |
| `--text-dim` | `zinc-600` | Gutter numbers, disabled state |
| `--accent-rose` | `rose-400` (`#fb7185`) / `rose-500` | Primary interactive accent — active states, selection, primary actions |
| `--accent-amber` | `amber-400` (`#fbbf24`) | Warnings, type/schema-related states |
| `--accent-emerald` | `emerald-400` (`#34d399`) | Success, "passing," build-OK states |
| `--selection` | `rose-500/30` | Text selection color app-wide |

**Status-color mapping for your dashboard specifically** (extends the reference, which only used color for feature categories):
- Emerald → success / valid / connected / running
- Amber → warning / stale / needs attention
- Rose → error / disconnected / primary CTA
- Zinc → neutral / idle / default

### 2.2 Typography

| Element | Spec |
|---|---|
| Page/section heading | `text-2xl md:text-3xl font-semibold text-white tracking-tight` |
| Panel/card title | `text-lg font-medium text-zinc-100` |
| Body copy | `text-sm text-zinc-400 leading-relaxed` |
| Overline/label | `text-xs font-medium text-zinc-500 uppercase tracking-wider` |
| Micro label (panel headers) | `text-[10px] uppercase tracking-widest text-zinc-500 font-semibold` |
| Code/config content | `font-mono text-sm leading-loose`, line numbers in `text-zinc-600` |
| CLI output / logs | `font-mono text-xs leading-relaxed` |

Use a system monospace stack (e.g. `ui-monospace, "SF Mono", "JetBrains Mono", monospace`) for anything representing code, config, CLI output, or file paths — this should be the dominant "voice" of the dashboard given code/config viewing is the core task.

### 2.3 Shape & Elevation

- Panels/cards: `rounded-xl` (editor-like surfaces) to `rounded-2xl` (larger content cards).
- Hairline borders everywhere; avoid heavy drop shadows except:
  - A soft ambient glow behind the primary/focused editor panel (`blur`, low opacity, brightens on focus) — same treatment as the reference hero's code panel.
  - Colored glow on hover for status-bearing cards, tinted to their status color at ~15% opacity.

---

## 3. Application to Your Dashboard's Core Surfaces

Since the dashboard's main job is **write/view code or config**, map the reference's patterns onto these concrete surfaces:

### 3.1 Editor / Config Viewer Panel
- Adopt the reference hero's code-window chrome exactly: header bar (`bg-[#111115]`, border-bottom) with three muted decorative dots, a filename chip (`FileCode2` icon + filename, monospace, in a pill), and a right-aligned action (copy, in your case likely also "run," "save," or "diff").
- Body on `#0d0d0f`, line-numbered, `font-mono text-sm leading-loose`.
- Reuse the syntax highlight palette: keywords → rose-400, identifiers/tags → amber-400, strings → emerald-300/90, punctuation/comments → zinc-500.
- **New pattern for your tool:** if the CLI writes to this same file live, add a brief line-level flash (background pulse in accent color, fading over ~600ms) when a line changes from external CLI activity — this extends the reference's "highlight a line" motion into "a line just changed," which the static reference component doesn't need but your live-editing use case does.

### 3.2 Sidebar / File or Resource Tree
- Background `#111115`, rows on hover shift to `#15151a` per the reference's row-hover treatment.
- Active/selected row gets the same treatment as the reference's active walkthrough button: left accent border (`border-l-2 border-rose-400`), background lift, and the row's index/icon recolors to rose.

### 3.3 CLI Output / Log Pane
- Style as a "proof panel" from the reference: micro-label header (e.g. "CLI OUTPUT", `text-[10px] uppercase tracking-widest`), monospace body, dim vs. emphasized line coloring (muted zinc for regular log lines, accent color for warnings/errors/success lines — same inline-color-by-severity approach as `feature.proof.lines[].dim`).
- Consider the reference's skeleton→reveal pattern for a "waiting for output" state: show placeholder bars, cross-fade to real content once the CLI streams a result.

### 3.4 Status / Health Cards (e.g. build status, connection status, validation state)
- Structure like the reference's feature rows: icon + title + one-line description on one side, a compact "proof" readout (last build output, last error, last validated timestamp) on the other, divided by a border.
- Use the per-status glow-on-hover technique, but drive the accent color from actual status (success/warning/error) rather than a fixed per-item color — this is the one place your implementation should branch from the static reference, which hardcodes colors per feature rather than per live state.

### 3.5 Global Actions / Primary Buttons
- Primary actions (Run, Deploy, Save) get the rose accent, consistent with the reference's use of rose as the "primary/active" signal color throughout (active line indicator, selection color, headless-accessibility feature).
- Copy-to-clipboard buttons anywhere in the dashboard should use the reference's icon-swap pattern (`Copy` → `Check`, emerald, revert after ~2s) — but wire it to `navigator.clipboard.writeText()` for real, since the reference component's own copy button is non-functional (see source spec, Section 6).

---

## 4. Motion Guidelines

| Interaction | Pattern | Duration |
|---|---|---|
| Selecting a file/row that maps to visible content elsewhere | Animated highlight bar with shared layout ID (slides between positions rather than refading) | ~150–200ms |
| Dimming non-focused content when something is focused | Sibling elements drop to `opacity: 0.3` | ~200ms |
| Revealing detail panels (logs, diagnostics, proof content) | Skeleton fades out, real content fades/slides in (`translate-y-2 → 0`) | ~300ms |
| Live/streaming states (build running, tests running) | Looping opacity-pulse sweep across the panel, in accent color at low opacity | 1.5s linear loop |
| Card/panel hover | Border brightens one step, background lifts one step, colored ambient shadow appears | ~300–500ms |

Keep all of this to Framer Motion + Tailwind transitions, matching the reference's implementation approach, so the codebase stays consistent if you're pulling any reference code directly.

---

## 5. Explicit Departures From the Reference

Call these out to your team/self so the redesign doesn't just copy a static marketing page:

1. **Color must be state-driven, not content-driven.** The reference assigns emerald/amber/rose to features arbitrarily (one per card). Your dashboard should assign them by actual status (success/warning/error), which means building this as a real token → state mapping, not hardcoded per-component classes like the reference does.
2. **Fix the dynamic-Tailwind-class bug before reusing any lifted code.** If you copy the "scanning sweep" gradient technique, hardcode the three (or however many) full class name variants — don't reconstruct class strings at runtime (see source spec Section 6, item 1).
3. **Keyboard accessibility is not optional here.** The reference's line-highlight interaction is mouse-only; your dashboard is a working tool, so every hover-triggered reveal (active row, proof/log panel, diagnostics) needs a focus-triggered equivalent for keyboard and screen-reader users.
4. **Live data replaces static demo data.** Every "proof panel" style surface in your dashboard reads from real CLI/build state instead of the reference's hardcoded `FEATURES` array — treat the reference's data shape (`label` + `lines[{text, dim}]`) as a good *format* for real log/diagnostic output, not literal content to reuse.

---

## 6. Suggested Rollout Order

1. Global tokens (colors, type, radius) applied to the app shell — gets you dark IDE aesthetic everywhere immediately with lowest risk.
2. Editor/config panel chrome (header bar, filename chip, syntax colors) — highest-visibility surface given code/config viewing is the core task.
3. Sidebar active-row + highlight-bar motion.
4. CLI output pane restyle with severity-colored lines.
5. Status cards with live-state-driven glow/accent.
6. Motion pass (skeleton reveals, sweep animations) once static styling is stable — motion is easiest to tune last.
