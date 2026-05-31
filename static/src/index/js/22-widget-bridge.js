// ── Widget postMessage bridge ─────────────────────────────────────
const _widgetDebounceTimers = new Map();
let _activeTextInput = null;
window.addEventListener('message', (e) => {
  const d = e.data;
  if (d && d.type === 'widget') {
    if (d.sel !== undefined) _activeTextInput = { cellId: String(d.cellId), sel: d.sel };
    const key = d.cellId + ':' + d.name;
    clearTimeout(_widgetDebounceTimers.get(key));
    _widgetDebounceTimers.set(
      key,
      setTimeout(() => {
        _widgetDebounceTimers.delete(key);
        fetch('/api/widget', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ wuCellId: d.cellId, wuName: d.name, wuValue: d.value }),
        });
      }, 300)
    );
  }
});
