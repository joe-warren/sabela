// ── Navigation ───────────────────────────────────────────────────
function goTo(i) {
  if (slideEls.length === 0) return;
  current = Math.min(Math.max(i, 0), slideEls.length - 1);
  slideEls.forEach((el, idx) => el.classList.toggle('active', idx === current));
  const total = slideEls.length;
  document.getElementById('slide-counter').textContent = current + 1 + ' / ' + total;
  document.getElementById('progress-fill').style.width = ((current + 1) / total) * 100 + '%';
  document.getElementById('nav-prev').disabled = current === 0;
  document.getElementById('nav-next').disabled = current === total - 1;
  history.replaceState(null, '', '#' + (current + 1));
  const active = slideEls[current];
  if (active) active.scrollTop = 0;
  // Iframes that were rendered while hidden need a reflow once visible.
  requestAnimationFrame(rerenderVisibleIframes);
}
function next() {
  goTo(current + 1);
}
function prev() {
  goTo(current - 1);
}

function toggleCode() {
  const deck = document.getElementById('deck');
  const on = deck.classList.toggle('show-code');
  document.getElementById('code-toggle').classList.toggle('active', on);
  // Layout width changed — reflow iframes on the active slide.
  requestAnimationFrame(rerenderVisibleIframes);
}

// Re-render every slide in place, preserving the current position.
function renderAllSlides() {
  if (!notebookData) return;
  const cells = notebookData.nbCells || [];
  slideEls.forEach((slide, i) => {
    const cell = cells[i];
    if (!cell) return;
    slide.classList.remove('has-code');
    renderSlide(slide, cell);
  });
  goTo(current);
}

function toggleEdit() {
  if (isStatic) return;
  editMode = !editMode;
  const deck = document.getElementById('deck');
  deck.classList.toggle('editing', editMode);
  document.getElementById('edit-toggle').classList.toggle('active', editMode);
  // You can't edit code you can't see — force the code pane open while
  // editing, and restore the prior show-code state when leaving.
  if (editMode) {
    if (!deck.classList.contains('show-code')) {
      deck.classList.add('show-code');
      document.getElementById('code-toggle').classList.add('active');
      _editForcedShowCode = true;
    }
  } else if (_editForcedShowCode) {
    deck.classList.remove('show-code');
    document.getElementById('code-toggle').classList.remove('active');
    _editForcedShowCode = false;
  }
  renderAllSlides();
}

// ── Slide font size ──────────────────────────────────────────────
const ZOOM_MIN = 0.6,
  ZOOM_MAX = 2.4,
  ZOOM_STEP = 0.1;
let slideZoom = 1;
function applyZoom(z, { persist = true } = {}) {
  slideZoom = Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, Math.round(z * 100) / 100));
  document.getElementById('deck').style.setProperty('--slide-zoom', slideZoom);
  document.getElementById('fs-pct').textContent = Math.round(slideZoom * 100) + '%';
  if (persist) localStorage.setItem('sabela-slide-zoom', String(slideZoom));
}
function bumpZoom(dir) {
  applyZoom(slideZoom + dir * ZOOM_STEP);
}
function resetZoom() {
  applyZoom(1);
}
function restoreZoom() {
  const stored = parseFloat(localStorage.getItem('sabela-slide-zoom'));
  applyZoom(Number.isFinite(stored) ? stored : 1, { persist: false });
}

function toggleFullscreen() {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen?.();
  } else {
    document.exitFullscreen?.();
  }
}
