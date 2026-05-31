// ── Examples ─────────────────────────────────────────────────────
async function loadExamples() {
  try {
    examples = await api('GET', 'examples');
    renderExamples();
  } catch (e) {
    console.error('Failed to load examples:', e);
  }
}

function renderExamples() {
  const container = document.getElementById('panel-examples');
  container.innerHTML = '';
  const categories = {};
  for (const ex of examples) {
    if (!categories[ex.exCategory]) categories[ex.exCategory] = [];
    categories[ex.exCategory].push(ex);
  }

  for (const [cat, exs] of Object.entries(categories)) {
    const catDiv = document.createElement('div');
    catDiv.className = 'example-category';
    const title = document.createElement('div');
    title.className = 'example-category-title';
    title.textContent = cat;
    catDiv.appendChild(title);

    for (const ex of exs) {
      const card = document.createElement('div');
      card.className = 'example-card';

      const header = document.createElement('div');
      header.className = 'example-card-header';
      header.innerHTML = `<span class="title">${esc(ex.exTitle)}</span><span class="desc">${esc(ex.exDesc)}</span>`;
      header.onclick = () => card.classList.toggle('expanded');

      const body = document.createElement('div');
      body.className = 'example-card-body';

      const code = document.createElement('div');
      code.className = 'example-code';
      code.textContent = ex.exCode;

      const actions = document.createElement('div');
      actions.className = 'example-actions';
      const copyBtn = document.createElement('button');
      copyBtn.textContent = '📋 copy';
      const copiedSpan = document.createElement('span');
      copiedSpan.className = 'copied';
      copiedSpan.textContent = 'copied!';
      copyBtn.onclick = (e) => {
        e.stopPropagation();
        navigator.clipboard.writeText(ex.exCode);
        copiedSpan.classList.add('show');
        setTimeout(() => copiedSpan.classList.remove('show'), 1500);
      };
      const insertBtn = document.createElement('button');
      insertBtn.className = 'insert-btn';
      insertBtn.textContent = '+ insert cell';
      insertBtn.onclick = async (e) => {
        e.stopPropagation();
        const afterId =
          notebook && notebook.nbCells.length > 0
            ? notebook.nbCells[notebook.nbCells.length - 1].cellId
            : -1;
        await api('POST', 'cell', {
          icAfter: afterId,
          icType: 'CodeCell',
          icLang: 'Haskell',
          icSource: ex.exCode,
        });
        const nb = await api('GET', 'notebook');
        render(nb);
        setStatus('Inserted: ' + ex.exTitle, '');
      };

      actions.appendChild(copyBtn);
      actions.appendChild(copiedSpan);
      actions.appendChild(insertBtn);
      body.appendChild(code);
      body.appendChild(actions);
      card.appendChild(header);
      card.appendChild(body);
      catDiv.appendChild(card);
    }
    container.appendChild(catDiv);
  }
}

function esc(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}
