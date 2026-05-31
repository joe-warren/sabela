const isStatic = !!window.__SABELA_STATIC__;
const _query = new URLSearchParams(location.search);
// 'notebook' (tutorial) mode shows each code cell's source; 'dashboard'
// (default) shows only prose + outputs. Static shares pin the mode via the
// injected flag; the live editor can request notebook mode with ?mode=notebook.
const renderMode =
  window.__SABELA_RENDER_MODE__ || (_query.get('mode') === 'notebook' ? 'notebook' : 'dashboard');
// ?print=1 — open straight into the browser print dialog (used by the editor's
// "Save as PDF" menu items, which open this page in a new tab).
const autoPrint = _query.get('print') === '1';
const HLJS_LANG = { Haskell: 'haskell', Python: 'python' };
let notebookData = null;

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
  // Re-render iframes with current theme colors
  document.querySelectorAll('iframe[data-last-content]').forEach((f) => {
    if (!f.dataset.lastContent) return;
    if (f.dataset.staticFrame) {
      f.srcdoc = staticSrcdoc(f.dataset.lastContent, f.dataset.iframeKind || 'content', f.id);
      return;
    }
    try {
      const doc = f.contentDocument || f.contentWindow?.document;
      if (!doc) return;
      doc.open();
      const style = f.dataset.iframeKind === 'widget' ? widgetIframeStyle() : iframeContentStyle();
      doc.write(style + f.dataset.lastContent);
      doc.close();
    } catch {}
  });
}
function toggleTheme() {
  applyTheme(currentTheme() === 'light' ? 'dark' : 'light');
}
function iframeContentStyle() {
  const isDark = currentTheme() === 'dark';
  const bg = isDark ? '#1e1e2e' : '#ffffff';
  const fg = isDark ? '#cdd6f4' : '#0a0a0a';
  const fgHead = isDark ? '#f5f5ff' : '#000000';
  const muted = isDark ? '#262637' : '#fafafa';
  const border = isDark ? '#313244' : '#e4e4e7';
  const accent = isDark ? '#89b4fa' : '#0066ff';
  const altRow = isDark ? 'rgba(137,180,250,0.05)' : 'rgba(0,102,255,0.04)';
  return `<style>body{background:${bg};color:${fg};font-family:'Geist',-apple-system,BlinkMacSystemFont,system-ui,sans-serif;font-size:15px;margin:0;padding:12px 16px;line-height:1.6;-webkit-font-smoothing:antialiased}img{max-width:100%}a{color:${accent}}table{border-collapse:separate;border-spacing:0;width:100%;border:1px solid ${border};border-radius:8px;overflow:hidden;margin:14px 0;font-size:14px}th,td{padding:10px 14px;text-align:left;border-bottom:1px solid ${border}}tr:last-child td{border-bottom:none}th{background:${muted};color:${fgHead};font-weight:600}tr:nth-child(even) td{background:${altRow}}input,select,button{font-family:inherit;font-size:14px;accent-color:${accent}}</style>`;
}
function widgetIframeStyle() {
  const isDark = currentTheme() === 'dark';
  const fg = isDark ? '#cdd6f4' : '#0a0a0a';
  const fgDim = isDark ? '#9399b2' : '#71717a';
  const accent = isDark ? '#89b4fa' : '#0066ff';
  return `<style>body{background:transparent;color:${fg};font-family:'JetBrains Mono',ui-monospace,monospace;font-size:14px;margin:0;padding:6px 12px;line-height:1.2;font-variant-ligatures:none;font-feature-settings:"calt" 0,"liga" 0}input,select{font-family:inherit;font-size:14px;accent-color:${accent};vertical-align:middle}button{font-family:inherit;font-size:14px;cursor:pointer;accent-color:${accent};vertical-align:middle}label{font-weight:600;font-size:13px;color:${fgDim};display:inline-block;margin-right:8px;vertical-align:middle}</style>`;
}
