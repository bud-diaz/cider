//  Self-contained dashboard assets for `cider dev`.
//
//  Keep these strings aligned with dev-tool-ui-redesign-spec.md. The dashboard is a
//  developer tool, so the visual system reads as IDE chrome: muted zinc surfaces,
//  monospace technical content, and state-driven rose/amber/emerald accents.

public enum DevDashboardAssets {
    public static let indexHTML = #"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CIDER Dev Dashboard</title>
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body>
  <div class="dashboard-shell">
    <header class="ide-titlebar" aria-label="CIDER dev dashboard">
      <div class="window-controls" aria-hidden="true"><span></span><span></span><span></span></div>
      <div class="titlebar-main">
        <span class="brand-mark">CIDER</span>
        <span class="file-chip"><span aria-hidden="true">▹</span><span>cider.dev/session.config</span></span>
      </div>
      <div class="titlebar-actions">
        <button id="copySession" class="icon-button" type="button" data-copy-target="sessionSummary" aria-label="Copy session summary">Copy</button>
        <span id="status" class="status-pill severity-warning">Starting…</span>
      </div>
    </header>

    <div class="workspace-grid">
      <aside class="resource-sidebar" aria-label="Dashboard sections">
        <div class="sidebar-label">Resources</div>
        <button class="resource-row active" data-tab="editor" aria-selected="true" type="button"><span class="row-index">01</span><span><strong>Editor</strong><small>frame preview + properties</small></span></button>
        <button class="resource-row" data-tab="inspector" aria-selected="false" type="button"><span class="row-index">02</span><span><strong>Inspector</strong><small>view tree + render commands</small></span></button>
        <button class="resource-row" data-tab="network" aria-selected="false" type="button"><span class="row-index">03</span><span><strong>Network</strong><small>CiderHTTP request capture</small></span></button>
        <button class="resource-row" data-tab="sandbox" aria-selected="false" type="button"><span class="row-index">04</span><span><strong>Sandbox</strong><small>files + JSON preview</small></span></button>
        <button class="resource-row" data-tab="events" aria-selected="false" type="button"><span class="row-index">05</span><span><strong>Events</strong><small>runtime event stream</small></span></button>
      </aside>

      <main class="tab-stack">
        <section id="editor" class="tab-panel active" aria-labelledby="editor-title">
          <div class="split-panel">
            <div class="editor-window focused-panel">
              <div class="editor-titlebar"><div class="window-controls small" aria-hidden="true"><span></span><span></span><span></span></div><span id="editor-title" class="file-chip">device.frame</span><span class="editor-action">live</span></div>
              <div id="stage" class="device-stage">
                <canvas id="frame" class="device-frame" width="1" height="1" aria-label="Rendered application frame"></canvas>
                <div id="overlay" class="node-overlay"></div>
              </div>
              <p id="frameStatus" class="stage-status">Waiting for a frame from the running application.</p>
            </div>
            <div class="proof-panel">
              <div class="proof-header"><span id="properties-title">PROPERTIES</span><span id="selectionPath" class="stream-badge">nothing selected</span></div>
              <div id="properties" class="proof-body" aria-labelledby="properties-title">Click a view in the preview to select it.</div>
            </div>
          </div>
        </section>

        <section id="inspector" class="tab-panel" aria-labelledby="inspector-title" hidden>
          <div class="editor-window focused-panel">
            <div class="editor-titlebar"><div class="window-controls small" aria-hidden="true"><span></span><span></span><span></span></div><span id="inspector-title" class="file-chip">Inspector.swiftui.tree</span><span class="editor-action">live</span></div>
            <div class="pipeline" aria-label="Swift app through Cider runtime into host"><span>Swift app</span><b>↓</b><span>Cider runtime</span><b>↓</b><span>Host</span></div>
            <div id="tree" class="editor-body line-reader" aria-live="polite"></div>
            <pre id="commands" class="code-output" aria-label="Render commands"></pre>
          </div>
        </section>

        <section id="network" class="tab-panel" aria-labelledby="network-title" hidden>
          <div class="proof-panel">
            <div class="proof-header"><span id="network-title">REQUEST CAPTURE</span><span class="header-dots" aria-hidden="true"><i></i><i></i></span></div>
            <div id="requests" class="proof-body">No CiderHTTP requests captured yet.</div>
          </div>
        </section>

        <section id="sandbox" class="tab-panel" aria-labelledby="sandbox-title" hidden>
          <div class="split-panel">
            <div class="proof-panel">
              <div class="proof-header"><span id="sandbox-title">SANDBOX BROWSER</span><button id="resetSandbox" class="danger-action" type="button">Reset sandbox</button></div>
              <div id="files" class="proof-body">No sandbox files.</div>
            </div>
            <div class="editor-window">
              <div class="editor-titlebar"><div class="window-controls small" aria-hidden="true"><span></span><span></span><span></span></div><span class="file-chip">preview.json</span><span class="editor-action">read-only</span></div>
              <pre id="preview" class="code-output"></pre>
            </div>
          </div>
        </section>

        <section id="events" class="tab-panel" aria-labelledby="events-title" hidden>
          <div class="proof-panel">
            <div class="proof-header"><span id="events-title">CLI OUTPUT</span><span class="stream-badge">streaming</span></div>
            <pre id="eventLog" class="proof-body cli-log"></pre>
          </div>
        </section>
      </main>

      <aside class="status-rail" aria-label="Runtime health">
        <article class="status-card severity-neutral"><span class="micro-label">Session</span><strong id="sessionSummary">Waiting for runtime snapshot</strong><small>Live state replaces static demo proof.</small></article>
        <article class="status-card severity-success"><span class="micro-label">Connected</span><strong>Dashboard server</strong><small>Polling APIs every second.</small></article>
        <article class="status-card severity-warning"><span class="micro-label">Focus</span><strong>Keyboard reachable</strong><small>Hover reveals are mirrored on focus.</small></article>
      </aside>
    </div>
  </div>
  <script src="/assets/app.js"></script>
</body>
</html>
"""#

    public static let appCSS = #"""
:root {
  color-scheme: dark;
  --bg-page: #09090b;
  --bg-panel: #111115;
  --bg-panel-deep: #0d0d0f;
  --bg-panel-hover: #15151a;
  --border-default: rgba(39, 39, 42, 0.78);
  --border-hover: #3f3f46;
  --text-primary: #fafafa;
  --text-body: #a1a1aa;
  --text-muted: #71717a;
  --text-dim: #52525b;
  --accent-rose: #fb7185;
  --accent-amber: #fbbf24;
  --accent-emerald: #34d399;
  --selection: rgba(244, 63, 94, 0.3);
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
  --motion-fast: 160ms;
  --motion-standard: 220ms;
  --motion-reveal: 300ms;
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-standard: cubic-bezier(0.77, 0, 0.175, 1);
  --mono: ui-monospace, "SF Mono", "JetBrains Mono", SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  --sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
* { box-sizing: border-box; }
::selection { background: var(--selection); color: var(--text-primary); }
body {
  margin: 0;
  min-height: 100vh;
  font-family: var(--sans);
  background:
    radial-gradient(circle at 20% -10%, rgba(251, 113, 133, 0.12), transparent 28rem),
    radial-gradient(circle at 100% 12%, rgba(52, 211, 153, 0.08), transparent 24rem),
    linear-gradient(180deg, #09090b 0%, #050506 100%);
  color: var(--text-primary);
}
button, pre, code, .file-chip, .resource-row, .status-pill, .micro-label, .editor-action, .line-reader, .code-output { font-family: var(--mono); }
button {
  appearance: none;
  border: 1px solid var(--border-default);
  background: var(--bg-panel);
  color: var(--text-body);
  cursor: pointer;
  transition: transform var(--motion-fast) var(--ease-out), border-color var(--motion-fast) var(--ease-out), background-color var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out), opacity var(--motion-fast) var(--ease-out), box-shadow var(--motion-standard) var(--ease-out);
}
button:active { transform: scale(0.97); }
button:focus-visible, .resource-row:focus-visible, .file:focus-visible, .node:focus-visible { outline: 2px solid var(--accent-rose); outline-offset: 2px; }
.dashboard-shell {
  width: min(1440px, calc(100vw - 32px));
  min-height: calc(100vh - 32px);
  margin: 16px auto;
  border: 1px solid var(--border-default);
  border-radius: var(--radius-lg);
  overflow: hidden;
  background: rgba(9, 9, 11, 0.92);
  box-shadow: 0 30px 100px rgba(0, 0, 0, 0.42);
}
.ide-titlebar {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
  min-height: 56px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--border-default);
  background: var(--bg-panel);
}
.window-controls { display: inline-flex; gap: 7px; align-items: center; }
.window-controls span { width: 10px; height: 10px; border-radius: 999px; background: #3f3f46; box-shadow: inset 0 0 0 1px rgba(255,255,255,0.04); }
.window-controls.small span { width: 8px; height: 8px; }
.titlebar-main, .titlebar-actions { display: flex; align-items: center; gap: 10px; min-width: 0; }
.titlebar-actions { justify-content: flex-end; }
.brand-mark { font: 800 12px/1 var(--mono); letter-spacing: 0.28em; color: var(--text-primary); }
.file-chip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
  max-width: 100%;
  border: 1px solid var(--border-default);
  border-radius: 999px;
  background: var(--bg-panel-deep);
  color: var(--text-body);
  padding: 6px 10px;
  font-size: 12px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.icon-button, .danger-action { border-radius: 999px; padding: 7px 10px; font-size: 12px; }
.icon-button[data-copied="true"] { color: var(--accent-emerald); border-color: rgba(52, 211, 153, 0.55); background: rgba(52, 211, 153, 0.08); }
.status-pill { border-radius: 999px; padding: 7px 10px; font-size: 12px; border: 1px solid currentColor; background: color-mix(in srgb, currentColor 9%, transparent); }
.workspace-grid { display: grid; grid-template-columns: 260px minmax(0, 1fr) 300px; gap: 0; min-height: calc(100vh - 89px); }
.resource-sidebar, .status-rail { background: var(--bg-panel); border-right: 1px solid var(--border-default); padding: 14px; }
.status-rail { border-right: 0; border-left: 1px solid var(--border-default); display: grid; align-content: start; gap: 12px; }
.sidebar-label, .micro-label { display: block; margin: 0 0 10px; color: var(--text-muted); font: 700 10px/1 var(--mono); letter-spacing: 0.18em; text-transform: uppercase; }
.resource-row {
  position: relative;
  display: grid;
  grid-template-columns: 34px minmax(0, 1fr);
  gap: 10px;
  width: 100%;
  text-align: left;
  border-radius: var(--radius-md);
  padding: 11px 10px;
  margin-bottom: 8px;
  border-left: 2px solid transparent;
}
.resource-row strong { display: block; color: var(--text-primary); font-size: 13px; font-weight: 650; }
.resource-row small { display: block; margin-top: 4px; color: var(--text-muted); font-size: 11px; line-height: 1.35; }
.row-index { color: var(--text-dim); font-size: 11px; padding-top: 1px; }
.resource-row[aria-selected="true"], .resource-row.active { background: var(--bg-panel-hover); border-left-color: var(--accent-rose); border-color: var(--border-hover); color: var(--accent-rose); box-shadow: 0 0 30px -12px rgba(251, 113, 133, 0.38); }
.resource-row[aria-selected="true"] .row-index, .resource-row.active .row-index { color: var(--accent-rose); }
.tab-stack { min-width: 0; padding: 14px; background: var(--bg-page); }
.tab-panel { display: block; animation: reveal var(--motion-reveal) var(--ease-out); }
.tab-panel[hidden] { display: none; }
.editor-window, .proof-panel, .status-card {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--border-default);
  border-radius: var(--radius-lg);
  background: var(--bg-panel);
  transition: border-color var(--motion-standard) var(--ease-out), background-color var(--motion-standard) var(--ease-out), box-shadow var(--motion-standard) var(--ease-out), opacity var(--motion-standard) var(--ease-out);
}
.focused-panel::before {
  content: "";
  position: absolute;
  inset: -2px;
  background: linear-gradient(180deg, rgba(63,63,70,0.65), rgba(24,24,27,0.1));
  filter: blur(18px);
  opacity: 0.22;
  pointer-events: none;
}
.editor-window:hover, .proof-panel:hover, .status-card:hover, .editor-window:focus-within, .proof-panel:focus-within { border-color: var(--border-hover); background: var(--bg-panel-hover); }
.editor-titlebar, .proof-header {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 44px;
  padding: 10px 12px;
  border-bottom: 1px solid var(--border-default);
  background: var(--bg-panel);
}
.editor-titlebar .file-chip { border-color: transparent; padding-inline: 0; background: transparent; color: var(--text-primary); }
.editor-action, .stream-badge { margin-left: auto; color: var(--text-muted); font-size: 10px; letter-spacing: 0.16em; text-transform: uppercase; }
.pipeline { position: relative; z-index: 1; display: grid; grid-template-columns: 1fr auto 1fr auto 1fr; align-items: center; gap: 10px; padding: 14px 14px 0; color: var(--text-muted); font: 12px/1 var(--mono); }
.pipeline span { border: 1px solid var(--border-default); border-radius: var(--radius-md); padding: 10px; background: var(--bg-panel-deep); color: var(--text-body); }
.pipeline b { color: var(--accent-rose); }
.editor-body, .code-output, .proof-body {
  position: relative;
  z-index: 1;
  margin: 14px;
  border: 1px solid var(--border-default);
  border-radius: var(--radius-md);
  background: var(--bg-panel-deep);
  color: var(--text-body);
  padding: 10px 0;
  overflow: auto;
  font-size: 12px;
  line-height: 1.75;
}
.code-output, .cli-log { padding: 12px; white-space: pre-wrap; }
.line-row, .node, .request, .file, .log-line {
  display: grid;
  grid-template-columns: 3.2ch minmax(0, 1fr);
  gap: 12px;
  min-height: 28px;
  padding: 3px 12px;
  border-left: 2px solid transparent;
  transition: opacity var(--motion-standard) var(--ease-out), background-color var(--motion-fast) var(--ease-out), border-color var(--motion-fast) var(--ease-out), transform var(--motion-fast) var(--ease-out);
}
.line-number { color: var(--text-dim); text-align: right; user-select: none; }
.node strong, .request strong, .file strong { color: var(--accent-amber); font-weight: 650; }
.node .muted, .request .muted, .file .muted, .muted { color: var(--text-muted); }
.node:hover, .node:focus, .file:hover, .file:focus, .request:hover, .request:focus, .log-line:hover { background: rgba(39, 39, 42, 0.5); border-left-color: var(--accent-rose); }
.proof-header { justify-content: space-between; color: var(--text-muted); font: 700 10px/1 var(--mono); letter-spacing: 0.18em; text-transform: uppercase; }
.header-dots { display: inline-flex; gap: 6px; }
.header-dots i { width: 7px; height: 7px; border-radius: 999px; background: var(--text-dim); }
.proof-panel:hover .proof-body, .proof-panel:focus-within .proof-body { box-shadow: inset 0 1px 0 rgba(255,255,255,0.03); }
.proof-panel::after { content: ""; position: absolute; inset: 44px 0 auto; height: 80px; pointer-events: none; opacity: 0; transform: translateY(-100%); background: linear-gradient(180deg, transparent, rgba(251, 113, 133, 0.10), transparent); transition: opacity var(--motion-standard) var(--ease-out); }
.proof-panel:hover::after, .proof-panel:focus-within::after { opacity: 1; animation: sweep 1.5s linear infinite; }
.status-card { display: grid; gap: 7px; padding: 13px; }
.status-card strong { color: var(--text-primary); font-size: 13px; }
.status-card small { color: var(--text-muted); line-height: 1.5; }
.severity-success { color: var(--accent-emerald); }
.severity-warning { color: var(--accent-amber); }
.severity-error { color: var(--accent-rose); }
.severity-neutral { color: var(--text-muted); }
.status-card.severity-success:hover { box-shadow: 0 0 32px -12px rgba(52, 211, 153, 0.45); }
.status-card.severity-warning:hover { box-shadow: 0 0 32px -12px rgba(251, 191, 36, 0.40); }
.status-card.severity-error:hover { box-shadow: 0 0 32px -12px rgba(251, 113, 133, 0.45); }
.split-panel { display: grid; grid-template-columns: minmax(260px, 0.85fr) minmax(0, 1.15fr); gap: 14px; }
.danger-action { color: var(--accent-rose); border-color: rgba(251, 113, 133, 0.45); background: rgba(251, 113, 133, 0.06); }
.device-stage { position: relative; margin: 12px auto; width: fit-content; line-height: 0; border: 1px solid var(--border-default); border-radius: var(--radius-md); overflow: hidden; }
.device-frame { display: block; max-width: 100%; height: auto; background: var(--bg-panel-deep); image-rendering: pixelated; }
.node-overlay { position: absolute; inset: 0; }
.node-box { position: absolute; border: 1px solid transparent; border-radius: 2px; cursor: pointer; background: transparent; padding: 0; }
.node-box:focus-visible { outline: 1px solid var(--accent-amber); outline-offset: 1px; }
.node-box.selected { border-color: var(--accent-amber); background: rgba(251, 191, 36, 0.10); }
.stage-status { margin: 0; padding: 9px 13px; border-top: 1px solid var(--border-default); color: var(--text-muted); font-family: var(--mono); font-size: 11px; }
.prop-row { display: grid; grid-template-columns: minmax(90px, 0.5fr) minmax(0, 1fr); gap: 10px; padding: 5px 0; border-bottom: 1px solid var(--border-default); }
.prop-row:last-child { border-bottom: 0; }
.prop-name { color: var(--text-muted); }
.prop-value { color: var(--text-primary); overflow-wrap: anywhere; }
.prop-note { color: var(--text-dim); font-size: 10px; letter-spacing: 0.08em; text-transform: uppercase; }
.token-keyword { color: var(--accent-rose); }
.token-identifier { color: var(--accent-amber); }
.token-string { color: var(--accent-emerald); }
.token-comment { color: var(--text-muted); }
@keyframes reveal { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
@keyframes sweep { from { transform: translateY(-100%); } to { transform: translateY(320%); } }
@media (hover: hover) and (pointer: fine) { button:hover { border-color: var(--border-hover); background: var(--bg-panel-hover); color: var(--text-primary); } .resource-row:hover { transform: translateX(2px); } }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { transition-duration: 0ms !important; animation-duration: 0ms !important; animation-iteration-count: 1 !important; transform: none !important; } }
@media (max-width: 1120px) { .workspace-grid { grid-template-columns: 220px minmax(0, 1fr); } .status-rail { grid-column: 1 / -1; border-left: 0; border-top: 1px solid var(--border-default); grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (max-width: 820px) { .dashboard-shell { width: calc(100vw - 20px); margin: 10px auto; } .ide-titlebar, .workspace-grid, .split-panel { grid-template-columns: 1fr; } .device-stage { width: 100%; } .titlebar-actions { justify-content: flex-start; flex-wrap: wrap; } .resource-sidebar { border-right: 0; border-bottom: 1px solid var(--border-default); } .status-rail { grid-template-columns: 1fr; } .pipeline { grid-template-columns: 1fr; } .pipeline b { text-align: center; transform: rotate(0deg); } }

"""#

    public static let appJS = #"""
const $ = (id) => document.getElementById(id);
const tabs = Array.from(document.querySelectorAll('.resource-row[data-tab]'));
const panels = Array.from(document.querySelectorAll('.tab-panel'));
const copyButtons = Array.from(document.querySelectorAll('[data-copy-target]'));

function escapeHTML(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function selectTab(tabName) {
  for (const panel of panels) {
    const isActive = panel.id === tabName;
    panel.classList.toggle('active', isActive);
    panel.hidden = !isActive;
  }
  for (const tab of tabs) {
    const isSelected = tab.dataset.tab === tabName;
    tab.classList.toggle('active', isSelected);
    tab.setAttribute('aria-selected', String(isSelected));
  }
}

for (const button of tabs) {
  button.addEventListener('click', () => selectTab(button.dataset.tab));
  button.addEventListener('keydown', (event) => {
    const index = tabs.indexOf(button);
    if (event.key === 'ArrowDown' || event.key === 'ArrowRight') {
      event.preventDefault();
      const next = tabs[(index + 1) % tabs.length];
      next.focus();
      selectTab(next.dataset.tab);
    }
    if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') {
      event.preventDefault();
      const previous = tabs[(index - 1 + tabs.length) % tabs.length];
      previous.focus();
      selectTab(previous.dataset.tab);
    }
  });
}

async function json(path) {
  const response = await fetch(path);
  if (response.status === 204) return null;
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return await response.json();
}

function severityForStatus(statusCode) {
  if (statusCode == null) return 'warning';
  if (statusCode >= 500) return 'error';
  if (statusCode >= 400) return 'warning';
  return 'success';
}

function severityForText(text) {
  const lower = String(text ?? '').toLowerCase();
  if (lower.includes('error') || lower.includes('fail') || lower.includes('disconnect')) return 'error';
  if (lower.includes('warn') || lower.includes('pending') || lower.includes('stale')) return 'warning';
  if (lower.includes('ready') || lower.includes('ok') || lower.includes('success') || lower.includes('captured')) return 'success';
  return 'neutral';
}

function lineRow(number, html, extraClass = '') {
  return `<div class="line-row ${extraClass}"><span class="line-number">${number}</span><span>${html}</span></div>`;
}

function inspectorNode(node, index) {
  const indent = 8 + Number(node.depth || 0) * 18;
  const label = node.label ? ` <span class="token-string">${escapeHTML(node.label)}</span>` : '';
  return `<div class="node" tabindex="0" style="padding-left:${indent}px"><span class="line-number">${index + 1}</span><span><strong>${escapeHTML(node.kind)}</strong> <span class="muted">${escapeHTML(node.id)}</span>${label}</span></div>`;
}

function renderCommands(commands) {
  if (!commands || !commands.length) return '';
  return commands.map((command, index) => `${String(index + 1).padStart(2, '0')}  ${command.index} ${command.kind} ${command.summary}`).join('\n');
}

function requestRow(request, index) {
  const severity = severityForStatus(request.statusCode);
  const status = request.statusCode ?? '…';
  const duration = request.durationMilliseconds ?? 0;
  return `<div class="request severity-${severity}" tabindex="0"><span class="line-number">${index + 1}</span><span><strong>${escapeHTML(request.method)}</strong> ${escapeHTML(status)} <span class="token-string">${escapeHTML(request.url)}</span><br><span class="muted">${escapeHTML(duration)}ms</span></span></div>`;
}

function fileRow(file, index) {
  return `<button class="file" type="button" data-path="${escapeHTML(file.path)}"><span class="line-number">${index + 1}</span><span><strong>${escapeHTML(file.path)}</strong> <span class="muted">${escapeHTML(file.size)} bytes</span></span></button>`;
}

function eventLine(event, index) {
  const stamp = new Date(event.timeMilliseconds).toISOString();
  const message = `${event.kind}: ${event.message}`;
  const severity = severityForText(message);
  return `${String(index + 1).padStart(2, '0')}  ${stamp}  [${severity.toUpperCase()}] ${message}`;
}

async function copyText(button, text) {
  try {
    await navigator.clipboard.writeText(text);
    button.textContent = 'Check';
    button.dataset.copied = 'true';
  } catch {
    button.textContent = 'Copy unavailable';
    button.dataset.copied = 'false';
  }
  setTimeout(() => {
    button.textContent = 'Copy';
    delete button.dataset.copied;
  }, 2000);
}

for (const button of copyButtons) {
  button.addEventListener('click', () => {
    const target = $(button.dataset.copyTarget);
    copyText(button, target ? target.textContent : document.body.innerText);
  });
}


// MARK: - Editor: frame mirror, node selection, properties

let editorNodes = [];
let editorLogicalWidth = 0;
let selectedNodeID = null;

async function drawFrame() {
  const response = await fetch('/api/inspector/frame');
  if (response.status === 204) {
    $('frameStatus').textContent = 'Waiting for a frame from the running application.';
    return false;
  }
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);

  const buffer = await response.arrayBuffer();
  const header = new DataView(buffer);
  // 'CIDR', then version, pixel width, pixel height, logical width, logical
  // height -- see CiderCore.FrameMirror for the writer.
  if (buffer.byteLength < 24 || header.getUint32(0, false) !== 0x43494452) {
    $('frameStatus').textContent = 'Frame mirror is not a CIDR frame.';
    return false;
  }
  const version = header.getUint32(4, true);
  if (version !== 1) {
    $('frameStatus').textContent = `Frame mirror version ${version} is newer than this dashboard.`;
    return false;
  }
  const pixelWidth = header.getUint32(8, true);
  const pixelHeight = header.getUint32(12, true);
  editorLogicalWidth = header.getUint32(16, true);
  const expected = 24 + pixelWidth * pixelHeight * 4;
  if (buffer.byteLength < expected) {
    $('frameStatus').textContent = 'Frame mirror is incomplete.';
    return false;
  }

  const canvas = $('frame');
  if (canvas.width !== pixelWidth || canvas.height !== pixelHeight) {
    canvas.width = pixelWidth;
    canvas.height = pixelHeight;
  }
  const pixels = new Uint8ClampedArray(buffer, 24, pixelWidth * pixelHeight * 4);
  canvas.getContext('2d').putImageData(new ImageData(pixels, pixelWidth, pixelHeight), 0, 0);
  $('frameStatus').textContent = `${pixelWidth}x${pixelHeight} px · ${editorLogicalWidth} pt wide`;
  return true;
}

function drawOverlay() {
  const canvas = $('frame');
  const overlay = $('overlay');
  const scale = editorLogicalWidth > 0 ? canvas.clientWidth / editorLogicalWidth : 0;
  if (scale <= 0) {
    overlay.innerHTML = '';
    return;
  }

  // Pre-order is painter's order -- a child always follows its parent, and a
  // later sibling is drawn over an earlier one -- so appending in array order
  // puts the topmost node last, where a click reaches it first.
  overlay.innerHTML = editorNodes
    .filter((node) => node.frame)
    .map((node) => {
      const selected = node.id === selectedNodeID ? ' selected' : '';
      const style = `left:${node.frame.x * scale}px;top:${node.frame.y * scale}px;`
        + `width:${node.frame.width * scale}px;height:${node.frame.height * scale}px`;
      return `<button type="button" class="node-box${selected}" style="${style}" `
        + `data-node="${escapeHTML(node.id)}" aria-label="${escapeHTML(node.kind)} ${escapeHTML(node.id)}"></button>`;
    })
    .join('');

  for (const box of overlay.querySelectorAll('.node-box')) {
    box.onclick = () => selectNode(box.dataset.node);
  }
}

function selectNode(nodeID) {
  selectedNodeID = nodeID;
  drawOverlay();
  renderProperties();
}

function ancestorIDs(nodeID) {
  const parts = String(nodeID).split('/');
  const chain = [];
  for (let index = 1; index < parts.length; index += 1) {
    chain.push(parts.slice(0, index).join('/'));
  }
  return chain.filter((id) => editorNodes.some((node) => node.id === id));
}

function propertyRow(name, value, note) {
  const suffix = note ? ` <span class="prop-note">${escapeHTML(note)}</span>` : '';
  return `<div class="prop-row"><span class="prop-name">${escapeHTML(name)}</span>`
    + `<span class="prop-value">${escapeHTML(value)}${suffix}</span></div>`;
}

function renderProperties() {
  const node = editorNodes.find((candidate) => candidate.id === selectedNodeID);
  if (!node) {
    $('selectionPath').textContent = 'nothing selected';
    $('properties').innerHTML = 'Click a view in the preview to select it.';
    return;
  }

  // A container's box is covered by its children, so the breadcrumb is the only
  // way to reach a VStack by pointer. Buttons, so it works from the keyboard too.
  const crumbs = ancestorIDs(node.id)
    .map((id) => `<button type="button" class="icon-button" data-ancestor="${escapeHTML(id)}">${escapeHTML(id)}</button>`)
    .join(' ');
  $('selectionPath').innerHTML = crumbs || escapeHTML(node.id);
  for (const crumb of $('selectionPath').querySelectorAll('[data-ancestor]')) {
    crumb.onclick = () => selectNode(crumb.dataset.ancestor);
  }

  let rows = propertyRow('kind', node.kind) + propertyRow('id', node.id);
  if (node.frame) {
    rows += propertyRow('frame', `${node.frame.x}, ${node.frame.y}  ${node.frame.width}x${node.frame.height}`, 'points');
  }
  if (Array.isArray(node.properties) && node.properties.length) {
    // A property with no source form is still shown, with the reason. Hiding
    // what cannot be changed makes the panel harder to trust, not simpler.
    rows += node.properties
      .map((property) => propertyRow(property.name, property.value, property.editable ? '' : (property.note || 'read-only')))
      .join('');
  } else if (node.label) {
    // An older runtime, or a node kind that exposes nothing.
    rows += propertyRow('summary', node.label);
  } else {
    rows += propertyRow('properties', 'none', 'nothing this view wrote');
  }
  $('properties').innerHTML = rows;
}

async function refresh() {
  try {
    const status = await json('/api/status');
    const state = status.state || 'unknown';
    const statusSeverity = severityForText(state);
    $('status').textContent = `${status.project} · ${state}`;
    $('status').className = `status-pill severity-${statusSeverity}`;
    $('sessionSummary').textContent = `${status.project} · ${state}`;

    const inspector = await json('/api/inspector/latest');
    if (inspector && inspector.nodes) {
      $('tree').innerHTML = inspector.nodes.map(inspectorNode).join('');
      $('commands').textContent = renderCommands(inspector.renderCommands || []);
      editorNodes = inspector.nodes;
    } else {
      $('tree').innerHTML = lineRow(1, '<span class="token-comment">No runtime snapshot yet.</span>');
      $('commands').textContent = '';
      editorNodes = [];
    }

    const drew = await drawFrame();
    if (drew) drawOverlay();
    renderProperties();

    const requests = await json('/api/network/requests');
    $('requests').innerHTML = requests.length ? requests.map(requestRow).join('') : lineRow(1, '<span class="token-comment">No CiderHTTP requests captured yet.</span>');

    const files = await json('/api/sandbox/tree');
    $('files').innerHTML = files.length ? files.map(fileRow).join('') : lineRow(1, '<span class="token-comment">No sandbox files.</span>');
    for (const file of document.querySelectorAll('.file')) {
      file.onclick = async () => {
        const path = encodeURIComponent(file.dataset.path);
        const preview = await json('/api/sandbox/file?path=' + path);
        $('preview').textContent = JSON.stringify(preview, null, 2);
      };
    }

    const events = await json('/api/events');
    $('eventLog').textContent = events.length ? events.map(eventLine).join('\n') : '01  waiting for CLI output…';
  } catch (error) {
    $('status').textContent = 'Dashboard error: ' + error.message;
    $('status').className = 'status-pill severity-error';
  }
}

$('resetSandbox').onclick = async () => {
  if (prompt('Type reset to clear the app sandbox') === 'reset') {
    await fetch('/api/sandbox/reset', { method: 'POST' });
    refresh();
  }
};

setInterval(refresh, 1000);
refresh();
"""#
}
