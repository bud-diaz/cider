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
  // Typed properties land with the richer snapshot; until then the inspector's
  // own summary is the honest thing to show rather than an empty panel.
  if (Array.isArray(node.properties) && node.properties.length) {
    rows += node.properties.map((property) => propertyRow(property.name, property.value, property.editable ? '' : 'read-only')).join('');
  } else if (node.label) {
    rows += propertyRow('summary', node.label);
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
