// ── Theme handling ───────────────────────────────────────────────
function currentTheme() {
  return document.documentElement.dataset.theme === 'light' ? 'light' : 'dark';
}
function applyTheme(theme, { persist = true } = {}) {
  document.documentElement.dataset.theme = theme;
  if (persist) {
    localStorage.setItem('sabela-theme', theme);
    window.__sabelaThemePinned = true;
  }
  // Theme toggle icon: show the icon for what clicking will switch TO.
  const iconUse = document.querySelector('#theme-icon use');
  if (iconUse) iconUse.setAttribute('href', theme === 'light' ? '#i-moon' : '#i-sun');
  // Update CodeMirror theme on every existing editor.
  const cmTheme = theme === 'light' ? 'idea' : 'nord';
  for (const id in editors) {
    try {
      editors[id].setOption('theme', cmTheme);
    } catch {}
  }
  // Refresh any rendered HTML iframes so their inlined CSS picks up new colors.
  document.querySelectorAll('.cell-output.mime-html iframe').forEach((f) => {
    if (f.dataset.lastContent) {
      try {
        const doc = f.contentDocument || f.contentWindow?.document;
        if (doc) {
          doc.open();
          doc.write(iframeBaseStyle() + f.dataset.lastContent);
          doc.close();
        }
      } catch {}
    }
  });
}
function toggleTheme() {
  applyTheme(currentTheme() === 'light' ? 'dark' : 'light');
}
function iframeBaseStyle() {
  const isLight = currentTheme() === 'light';
  const bg = isLight ? '#ffffff' : '#ffffff';
  const fg = isLight ? '#0a0a0a' : '#1e1e2e';
  const accent = isLight ? '#0066ff' : '#89b4fa';
  return `<style>body{background:${bg};color:${fg};font-family:'JetBrains Mono',ui-monospace,monospace;font-size:13px;margin:0;padding:4px 8px;font-variant-ligatures:none;font-feature-settings:"calt" 0,"liga" 0}input,select,button{accent-color:${accent};font-family:inherit;font-size:13px;cursor:pointer}</style>`;
}
// Live-follow OS theme until the user makes a manual choice
if (window.matchMedia) {
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e) => {
    if (!window.__sabelaThemePinned) applyTheme(e.matches ? 'light' : 'dark', { persist: false });
  });
}
// Initial sync (icon + CodeMirror theme will be set once editors mount)
applyTheme(currentTheme(), { persist: false });

// ── Dirty-dot indicator (filename next to the toolbar title) ─────
function updateDirtyDot() {
  const dot = document.getElementById('dirty-dot');
  if (!dot) return;
  if (unsavedChanges) dot.classList.add('show');
  else dot.classList.remove('show');
}
const _origSetStatusUnsaved = () => {};
// Hook into autosave + saveNotebook by polling unsavedChanges every 600ms — cheap.
setInterval(updateDirtyDot, 600);
