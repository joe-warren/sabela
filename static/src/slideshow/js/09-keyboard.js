// ── Keyboard ─────────────────────────────────────────────────────
document.addEventListener('keydown', (e) => {
  // Don't hijack typing inside widget iframes / inputs.
  const t = e.target;
  if (t && (t.tagName === 'INPUT' || t.tagName === 'SELECT' || t.tagName === 'TEXTAREA')) return;
  switch (e.key) {
    case 'ArrowRight':
    case 'ArrowDown':
    case 'PageDown':
    case ' ':
      e.preventDefault();
      next();
      break;
    case 'ArrowLeft':
    case 'ArrowUp':
    case 'PageUp':
      e.preventDefault();
      prev();
      break;
    case 'Home':
      e.preventDefault();
      goTo(0);
      break;
    case 'End':
      e.preventDefault();
      goTo(slideEls.length - 1);
      break;
    case 'c':
    case 'C':
      toggleCode();
      break;
    case 'e':
    case 'E':
      if (!isStatic) toggleEdit();
      break;
    case 'f':
    case 'F':
      toggleFullscreen();
      break;
    case '+':
    case '=':
      e.preventDefault();
      bumpZoom(1);
      break;
    case '-':
    case '_':
      e.preventDefault();
      bumpZoom(-1);
      break;
    case '0':
      e.preventDefault();
      resetZoom();
      break;
  }
});

let _resizeTimer = null;
window.addEventListener('resize', () => {
  clearTimeout(_resizeTimer);
  _resizeTimer = setTimeout(rerenderVisibleIframes, 200);
});
