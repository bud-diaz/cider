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
    } else {
      $('tree').innerHTML = lineRow(1, '<span class="token-comment">No runtime snapshot yet.</span>');
      $('commands').textContent = '';
    }

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