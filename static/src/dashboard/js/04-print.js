// ── Print to PDF ─────────────────────────────────────────────────
// Browsers print an <iframe> as one atomic box: a tall frame is clipped at the
// page edge, not paginated. Content outputs (e.g. dataframe tables) live in
// iframes, so before printing we swap each one for inline, script-stripped DOM
// that flows across pages. SVG/markdown/image/JSON/plain outputs are already
// inline and need no help; short widget iframes are left as-is.

// Strip <script> elements and on*= handlers, then return the safe HTML. Inlining
// runs in this page's origin (unlike the sandboxed iframe), so for untrusted
// static shares this prevents the output HTML from executing.
function sanitizeForPrint(html) {
  const tpl = document.createElement('template');
  tpl.innerHTML = html;
  tpl.content.querySelectorAll('script').forEach((s) => s.remove());
  tpl.content.querySelectorAll('*').forEach((el) => {
    for (const attr of [...el.attributes]) {
      if (/^on/i.test(attr.name)) el.removeAttribute(attr.name);
    }
  });
  return tpl.innerHTML;
}

// Replace each content iframe with an inline .print-inline div; return undo fns.
function inlineContentFramesForPrint() {
  const frames = [...document.querySelectorAll('iframe[data-last-content]')].filter(
    (f) => f.dataset.iframeKind !== 'widget'
  );
  const restore = [];
  for (const f of frames) {
    const div = document.createElement('div');
    div.className = 'print-inline';
    div.innerHTML = sanitizeForPrint(f.dataset.lastContent || '');
    f.style.display = 'none';
    f.parentNode.insertBefore(div, f);
    restore.push(() => {
      div.remove();
      f.style.display = '';
    });
  }
  return restore;
}

function printToPdf() {
  const restore = inlineContentFramesForPrint();
  const cleanup = () => {
    restore.forEach((r) => r());
    window.removeEventListener('afterprint', cleanup);
  };
  window.addEventListener('afterprint', cleanup);
  requestAnimationFrame(() => window.print());
}
