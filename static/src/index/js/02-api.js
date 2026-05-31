// ── API helpers ──────────────────────────────────────────────────
async function api(method, path, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body !== undefined) opts.body = JSON.stringify(body);
  const res = await fetch('/api/' + path, opts);
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

function setStatus(text, cls) {
  const el = document.getElementById('status');
  el.textContent = text;
  el.className = 'status ' + (cls || '');
  if (!cls || cls !== 'running')
    setTimeout(() => {
      if (el.textContent === text) el.textContent = '';
    }, 4000);
}

function flashSaved() {
  const el = document.getElementById('save-indicator');
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 2000);
}
