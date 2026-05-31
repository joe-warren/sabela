// ── Initialization ───────────────────────────────────────────────
async function init() {
  restoreZoom();
  if (isStatic) {
    notebookData = window.__SABELA_STATIC__;
    document.getElementById('edit-link').style.display = 'none';
    document.getElementById('export-btn').style.display = 'none';
    document.getElementById('edit-toggle').style.display = 'none';
  } else {
    const resp = await fetch('/api/notebook');
    notebookData = await resp.json();
  }
  buildDeck(notebookData);
  if (!isStatic) connectSSE();
}
