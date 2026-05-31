// ── Build the deck ───────────────────────────────────────────────
function buildDeck(nb) {
  document.getElementById('deck-title').textContent = formatTitle(nb.nbTitle);
  document.title = formatTitle(nb.nbTitle) + ' — Sabela Slideshow';

  const deck = document.getElementById('deck');
  deck.innerHTML = '';
  slideEls = [];

  const cells = nb.nbCells || [];
  for (const cell of cells) {
    const slide = document.createElement('section');
    slide.className = 'slide';
    slide.dataset.cellId = cell.cellId;
    renderSlide(slide, cell);
    deck.appendChild(slide);
    slideEls.push(slide);
  }

  if (slideEls.length === 0) {
    const slide = document.createElement('section');
    slide.className = 'slide';
    slide.innerHTML =
      '<div class="slide-inner"><div class="slide-empty">This notebook has no cells.</div></div>';
    deck.appendChild(slide);
    slideEls.push(slide);
  }

  // Restore position from hash (#3) if present.
  const fromHash = parseInt((location.hash || '').slice(1), 10);
  current = Number.isFinite(fromHash)
    ? Math.min(Math.max(fromHash - 1, 0), slideEls.length - 1)
    : 0;
  goTo(current);
}
