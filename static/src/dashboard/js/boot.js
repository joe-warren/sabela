// Theme bootstrap — shared with editor via 'sabela-theme' localStorage key.
(() => {
  const stored = localStorage.getItem('sabela-theme');
  const theme =
    stored === 'light' || stored === 'dark'
      ? stored
      : window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches
        ? 'light'
        : 'dark';
  document.documentElement.dataset.theme = theme;
  window.__sabelaThemePinned = !!stored;
})();
