// ── Render one slide's content ───────────────────────────────────
const canEdit = () => editMode && !isStatic;

function renderSlide(slide, cell) {
  slide.innerHTML = '';
  const inner = document.createElement('div');
  inner.className = 'slide-inner';

  if (cell.cellType === 'ProseCell') {
    if (canEdit()) {
      inner.appendChild(buildProseEditor(cell));
    } else {
      const prose = document.createElement('div');
      prose.className = 'prose';
      prose.innerHTML = renderMarkdownWithMath(cell.cellSource || '');
      wrapTables(prose);
      highlightWithin(prose);
      inner.appendChild(prose);
    }
    slide.appendChild(inner);
    return;
  }

  // CodeCell — mark as code-bearing so the "show code" layout applies.
  slide.classList.add('has-code');

  const codeCol = document.createElement('div');
  codeCol.className = 'slide-code';
  const lang = cell.cellLang || 'Haskell';

  if (canEdit()) {
    codeCol.appendChild(buildCodeEditor(cell, lang));
  } else {
    codeCol.innerHTML = '<div class="code-lang">' + escapeHtml(lang) + '</div>';
    const pre = document.createElement('pre');
    const codeEl = document.createElement('code');
    codeEl.className = 'hljs';
    const src = cell.cellSource || '';
    const hl = HLJS_LANG[lang];
    if (hl && window.hljs && hljs.getLanguage(hl)) {
      codeEl.innerHTML = hljs.highlight(src, { language: hl }).value;
    } else {
      codeEl.textContent = src;
    }
    pre.appendChild(codeEl);
    codeCol.appendChild(pre);
  }

  const outCol = document.createElement('div');
  outCol.className = 'slide-output';
  fillOutputs(outCol, cell);

  inner.appendChild(codeCol);
  inner.appendChild(outCol);
  slide.appendChild(inner);
}

// Render a cell's outputs/error into a (possibly cleared) container.
function fillOutputs(outCol, cell) {
  outCol.innerHTML = '';
  const merged = mergeHtmlOutputs(cell.cellOutputs || []);
  let rendered = 0;
  for (const o of merged) {
    if (!o.oiOutput || !o.oiOutput.trim()) continue;
    const isWidget = classifyOutput(o) === 'widget';
    const block = document.createElement('div');
    block.className = isWidget ? 'slide-widget' : 'output-block';
    if (isWidget) renderWidgetOutput(block, o);
    else renderOutput(block, o.oiOutput, o.oiMime);
    outCol.appendChild(block);
    rendered++;
  }
  if (cell.cellError && cell.cellError.trim()) {
    const errEl = document.createElement('div');
    errEl.className = 'slide-error';
    errEl.textContent = cell.cellError;
    outCol.appendChild(errEl);
    rendered++;
  }
  if (rendered === 0) {
    const empty = document.createElement('div');
    empty.className = 'slide-empty';
    empty.textContent = '— no output —';
    outCol.appendChild(empty);
  }
}
