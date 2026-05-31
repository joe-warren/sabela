// ── Editors (live mode) ──────────────────────────────────────────
// Render KaTeX inside a markdown source before handing to marked, so
// $...$ / $$...$$ blocks survive marked's underscore/star handling.
function renderMarkdownWithMath(src) {
  let s = src || '';
  if (typeof katex !== 'undefined') {
    s = s.replace(/\$\$([\s\S]+?)\$\$/g, (_, tex) => {
      try {
        return katex.renderToString(tex.trim(), { displayMode: true, throwOnError: false });
      } catch (_e) {
        return _;
      }
    });
    s = s.replace(/(^|[^\\$])\$([^\$\n]+?)\$(?!\d)/g, (_, pre, tex) => {
      try {
        return pre + katex.renderToString(tex, { displayMode: false, throwOnError: false });
      } catch (_e) {
        return _;
      }
    });
  }
  return marked.parse(s);
}

function buildProseEditor(cell) {
  const ta = document.createElement('textarea');
  ta.className = 'prose-editor';
  ta.value = cell.cellSource || '';
  ta.spellcheck = false;
  ta.addEventListener('blur', () => saveCell(cell, ta.value, false));
  ta.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      ta.blur();
    } else if (e.key === 'Escape') {
      ta.value = cell.cellSource || '';
      ta.blur();
    }
  });
  const wrap = document.createElement('div');
  wrap.appendChild(ta);
  const hint = document.createElement('div');
  hint.className = 'edit-hint';
  hint.textContent = 'Markdown — saves on blur (⌘/Ctrl+Enter), Esc to discard';
  wrap.appendChild(hint);
  return wrap;
}

// Paint the highlight layer. A trailing newline gets a phantom space so
// the empty last line still has a line box and the layer stays the same
// height as the textarea.
function paintHighlight(codeEl, value, lang) {
  const v = value.endsWith('\n') ? value + ' ' : value;
  const hl = HLJS_LANG[lang];
  if (hl && window.hljs && hljs.getLanguage(hl)) {
    codeEl.innerHTML = hljs.highlight(v, { language: hl }).value;
  } else {
    codeEl.textContent = v;
  }
}

function buildCodeEditor(cell, lang) {
  const wrap = document.createElement('div');
  const head = document.createElement('div');
  head.className = 'code-edit-head';
  const label = document.createElement('div');
  label.className = 'code-lang';
  label.textContent = lang;
  const runBtn = document.createElement('button');
  runBtn.className = 'run-btn';
  runBtn.title = 'Run cell (⌘/Ctrl+Enter)';
  runBtn.innerHTML =
    '<svg viewBox="0 0 24 24"><polygon points="6 4 20 12 6 20 6 4" fill="currentColor" stroke="none"/></svg>Run';
  head.appendChild(label);
  head.appendChild(runBtn);

  const ed = document.createElement('div');
  ed.className = 'code-ed';
  const pre = document.createElement('pre');
  pre.className = 'code-ed-hl';
  pre.setAttribute('aria-hidden', 'true');
  const codeEl = document.createElement('code');
  codeEl.className = 'hljs';
  pre.appendChild(codeEl);

  const ta = document.createElement('textarea');
  ta.className = 'code-ed-ta';
  ta.value = cell.cellSource || '';
  ta.spellcheck = false;
  ta.wrap = 'off';
  paintHighlight(codeEl, ta.value, lang);

  const syncScroll = () => {
    pre.scrollTop = ta.scrollTop;
    pre.scrollLeft = ta.scrollLeft;
  };
  const sync = () => {
    paintHighlight(codeEl, ta.value, lang);
    syncScroll();
  };

  const run = () => {
    cell.cellSource = ta.value;
    runCell(cell, ta.value);
  };
  runBtn.addEventListener('click', run);
  ta.addEventListener('input', sync);
  ta.addEventListener('scroll', syncScroll);
  ta.addEventListener('blur', () => saveCell(cell, ta.value, true));
  ta.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      run();
    } else if (e.key === 'Escape') {
      ta.value = cell.cellSource || '';
      sync();
      ta.blur();
    }
  });

  ed.appendChild(pre);
  ed.appendChild(ta);
  wrap.appendChild(head);
  wrap.appendChild(ed);
  const hint = document.createElement('div');
  hint.className = 'edit-hint';
  hint.textContent = '⌘/Ctrl+Enter to run · blur saves without running · Esc discards';
  wrap.appendChild(hint);
  return wrap;
}

async function apiFetch(method, path, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body !== undefined) opts.body = JSON.stringify(body);
  const res = await fetch('/api/' + path, opts);
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

// Persist source. codeOnly=true uses the no-execute /source endpoint so a
// blur doesn't surprise-run; prose persists via the reactive endpoint.
async function saveCell(cell, value, codeOnly) {
  if (isStatic || value === (cell.cellSource || '')) return;
  cell.cellSource = value;
  const path = codeOnly ? `cell/${cell.cellId}/source` : `cell/${cell.cellId}`;
  try {
    await apiFetch('PUT', path, { ucSource: value });
    showStatus('Saved', false);
    setTimeout(hideStatus, 1200);
  } catch (err) {
    showStatus('Save failed', false);
  }
}

async function runCell(cell, value) {
  if (isStatic) return;
  showStatus('Running...', true);
  try {
    await apiFetch('PUT', `cell/${cell.cellId}`, { ucSource: value });
    await apiFetch('POST', `run/${cell.cellId}`);
    // Outputs arrive via SSE (cellResult) and refresh just the output pane.
  } catch (err) {
    showStatus('Run failed', false);
  }
}

function wrapTables(root) {
  root.querySelectorAll('table').forEach((t) => {
    const w = document.createElement('div');
    w.style.overflowX = 'auto';
    t.parentNode.insertBefore(w, t);
    w.appendChild(t);
  });
}
function escapeHtml(s) {
  return String(s).replace(
    /[&<>"]/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]
  );
}

// Map Sabela cell languages to highlight.js language ids.
const HLJS_LANG = { Haskell: 'haskell', Python: 'python' };

// Syntax-highlight fenced code blocks inside rendered markdown.
function highlightWithin(root) {
  if (!window.hljs) return;
  root.querySelectorAll('pre code').forEach((el) => {
    try {
      hljs.highlightElement(el);
    } catch {}
  });
}
