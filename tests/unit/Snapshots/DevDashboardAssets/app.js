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

// The console refuses an unauthenticated request that changes state. Loopback
// is not a boundary -- any page can POST here and the browser delivers it -- so
// every mutating call carries this session's token, and sending a custom header
// also forces a preflight a cross-origin simple request cannot make.
let sessionToken = '';

async function loadSessionToken() {
  const session = await json('/api/dev/session');
  sessionToken = session && session.token ? session.token : '';
}

async function post(path, payload) {
  const response = await fetch(path, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-cider-dev-token': sessionToken,
    },
    body: payload === undefined ? '' : JSON.stringify(payload),
  });
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`;
    try {
      const problem = await response.json();
      if (problem && problem.summary) detail = `${problem.code}: ${problem.summary}`;
    } catch (ignored) {
      // A refusal without a JSON body still has its status line.
    }
    throw new Error(detail);
  }
  return response;
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
// Set the moment an edit is written, cleared when the console reports the
// application running again. Positions in the panel refer to the file as it was
// before the edit, so a second edit aimed at them could land in the wrong place.
let awaitingRebuild = false;

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

function originLabel(origin) {
  if (!origin || !origin.file) return '';
  const name = String(origin.file).split('/').pop();
  return `${name}:${origin.line}`;
}

function propertyRow(name, value, note, origin) {
  // A written value shows where it was written; an unwritten one shows why it
  // has no source. Both are more use than a bare number.
  const trailer = origin ? originLabel(origin) : note;
  const suffix = trailer ? ` <span class="prop-note">${escapeHTML(trailer)}</span>` : '';
  return `<div class="prop-row"><span class="prop-name">${escapeHTML(name)}</span>`
    + `<span class="prop-value">${escapeHTML(value)}${suffix}</span></div>`;
}

function editableRow(property, origin) {
  const trailer = origin ? originLabel(origin) : 'default';
  const control = property.type === 'enum'
    ? `<select class="prop-input" data-property="${escapeHTML(property.name)}">`
      + (property.options || []).map((option) =>
          `<option value="${escapeHTML(option)}"${option === property.value ? ' selected' : ''}>${escapeHTML(option)}</option>`
        ).join('')
      + '</select>'
    : `<input class="prop-input" type="${property.type === 'bool' ? 'checkbox' : 'text'}" `
      + `data-property="${escapeHTML(property.name)}" `
      + (property.type === 'bool'
          ? (property.value === 'true' ? 'checked' : '')
          : `value="${escapeHTML(property.value)}"`)
      + '>';
  // A label wrapping its control needs no `for`, and keeps the pair associated
  // for a screen reader without inventing ids that have to stay unique.
  return `<div class="prop-row"><span class="prop-name">${escapeHTML(property.name)}</span>`
    + `<label class="prop-value" aria-label="${escapeHTML(property.name)}">${control}`
    + ` <span class="prop-note">${escapeHTML(trailer)}</span></label></div>`;
}

/// Turns a displayed value into the Swift literal the rewriter expects. The
/// panel shows `bold`, `Cider Demo`, `#E89A2FFF`; the source needs `.bold`,
/// `"Cider Demo"`, `Color(hex: 0xE89A2F)`.
function swiftLiteral(property, raw) {
  if (property.type === 'enum') return '.' + raw;
  if (property.type === 'bool') return raw ? 'true' : 'false';
  if (property.type === 'color') {
    const hex = String(raw).replace('#', '').slice(0, 6);
    return `Color(hex: 0x${hex.toUpperCase()})`;
  }
  if (property.type === 'string') return JSON.stringify(String(raw));
  return String(raw);
}

/// Values of the other arguments in the same call, needed when the call has to
/// be written from scratch. Sent every time; the rewriter ignores them when it
/// is only replacing an argument that is already there.
const siblingsByProperty = {
  fontSize: { weight: 'fontWeight' },
  fontWeight: { size: 'fontSize' },
  paddingHorizontal: { vertical: 'paddingVertical' },
  paddingVertical: { horizontal: 'paddingHorizontal' },
  backgroundColor: { pressed: 'pressedBackgroundColor' },
  pressedBackgroundColor: { _0: 'backgroundColor' },
};

async function applyEdit(node, property, rawValue) {
  // No origin means nobody wrote this node -- a synthetic wrapper -- and there
  // is nothing in the source to point an edit at.
  if (!node.origin || !node.view) return;
  const siblings = {};
  for (const [label, source] of Object.entries(siblingsByProperty[property.name] || {})) {
    const sibling = (node.properties || []).find((candidate) => candidate.name === source);
    if (sibling) siblings[label] = swiftLiteral(sibling, sibling.value);
  }

  await post('/api/editor/apply', {
    file: node.origin.file,
    line: node.origin.line,
    column: node.origin.column,
    head: node.view,
    property: property.name,
    value: swiftLiteral(property, rawValue),
    expectedCurrentValue: property.origin ? property.value : null,
    siblingValues: siblings,
  });
}


function renderProperties() {
  // The refresh loop calls this every second. Rebuilding the panel under a
  // field someone is typing in would discard what they typed, so leave it
  // alone until focus moves on.
  const active = document.activeElement;
  if (active && active.classList && active.classList.contains('prop-input')) return;

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
  if (node.origin) {
    rows += propertyRow('written at', originLabel(node.origin), 'source');
  }
  if (Array.isArray(node.properties) && node.properties.length) {
    // A property with no source form is still shown, with the reason. Hiding
    // what cannot be changed makes the panel harder to trust, not simpler.
    const writable = Boolean(node.origin && node.view) && !awaitingRebuild;
    rows += node.properties
      .map((property) => (property.editable && writable)
        ? editableRow(property, property.origin)
        : propertyRow(
            property.name,
            property.value,
            property.editable ? (awaitingRebuild ? 'rebuilding' : 'default') : (property.note || 'read-only'),
            property.origin
          ))
      .join('');
  } else if (node.label) {
    // An older runtime, or a node kind that exposes nothing.
    rows += propertyRow('summary', node.label);
  } else {
    rows += propertyRow('properties', 'none', 'nothing this view wrote');
  }
  $('properties').innerHTML = rows;

  for (const input of $('properties').querySelectorAll('.prop-input')) {
    const property = (node.properties || []).find((candidate) => candidate.name === input.dataset.property);
    if (!property) continue;
    // `change`, not `input`: an edit rewrites a file and relaunches the
    // application, so it fires when the developer is done typing rather than
    // on every keystroke.
    input.onchange = async () => {
      const raw = input.type === 'checkbox' ? input.checked : input.value;
      try {
        await applyEdit(node, property, raw);
        awaitingRebuild = true;
        $('editStatus').textContent = `wrote ${property.name} to ${originLabel(node.origin)}`;
        $('editStatus').className = 'stage-status severity-success';
      } catch (error) {
        $('editStatus').textContent = error.message;
        $('editStatus').className = 'stage-status severity-error';
        renderProperties();
      }
    };
  }
}

async function refresh() {
  try {
    const status = await json('/api/status');
    const state = status.state || 'unknown';
    const statusSeverity = severityForText(state);
    $('status').textContent = `${status.project} · ${state}`;
    $('status').className = `status-pill severity-${statusSeverity}`;
    if (state === 'running' || state === 'watching') awaitingRebuild = false;
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
    try {
      await post('/api/sandbox/reset');
    } catch (error) {
      $('status').textContent = 'Sandbox reset refused: ' + error.message;
      $('status').className = 'status-pill severity-error';
      return;
    }
    refresh();
  }
};

loadSessionToken().then(refresh);
setInterval(refresh, 1000);
