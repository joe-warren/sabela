const isStatic = !!window.__SABELA_STATIC__;
let notebookData = null;
let slideEls = []; // one .slide element per cell
let current = 0;
let editMode = false; // live-editing toggle (live mode only)
let _editForcedShowCode = false; // did edit mode auto-enable show-code?

// ── Theme handling (shared with editor via 'sabela-theme' key) ──
function currentTheme() {
  return document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
}
function applyTheme(theme, { persist = true } = {}) {
  document.documentElement.dataset.theme = theme;
  if (persist) {
    localStorage.setItem('sabela-theme', theme);
    window.__sabelaThemePinned = true;
  }
  const iconUse = document.querySelector('#theme-icon use');
  if (iconUse) iconUse.setAttribute('href', theme === 'light' ? '#i-moon' : '#i-sun');
  rerenderVisibleIframes();
}
function toggleTheme() {
  applyTheme(currentTheme() === 'light' ? 'dark' : 'light');
}
