// ── Initialization ───────────────────────────────────────────────
async function init() {
  if (isStatic) {
    notebookData = window.__SABELA_STATIC__;
    document.getElementById('edit-link').style.display = 'none';
    document.getElementById('export-btn').style.display = 'none';
  } else {
    const resp = await fetch('/api/notebook');
    notebookData = await resp.json();
  }
  renderDashboard(notebookData);
  if (renderMode === 'notebook') setupDownloadMd();
  if (!isStatic) connectSSE();
  // Opened with ?print=1 — let layout settle (iframes report heights, fonts
  // load), then drop straight into the print dialog.
  if (autoPrint) requestAnimationFrame(() => setTimeout(printToPdf, 300));
}

// In notebook (tutorial) mode, offer the notebook source for download so a
// reader can upload it into their own Sabela workspace and run it.
function setupDownloadMd() {
  const md = window.__SABELA_MARKDOWN__;
  const actions = document.getElementById('header-actions');
  if (!md || !actions || document.getElementById('dl-md-btn')) return;
  const btn = document.createElement('button');
  btn.id = 'dl-md-btn';
  btn.textContent = 'Download .md';
  btn.title = 'Download the notebook source — upload it into your own Sabela workspace to run it';
  btn.addEventListener('click', () => {
    const title = (notebookData && notebookData.nbTitle) || 'notebook.md';
    const name = /\.md$/.test(title) ? title.split('/').pop() : 'notebook.md';
    const blob = new Blob([md], { type: 'text/markdown' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      URL.revokeObjectURL(a.href);
      a.remove();
    }, 0);
  });
  actions.insertBefore(btn, actions.firstChild);
}
