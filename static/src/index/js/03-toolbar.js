// ── Toolbar dropdowns ────────────────────────────────────────────
function toggleDropdown(btn) {
  const dd = btn.parentElement;
  const wasOpen = dd.classList.contains('open');
  closeDropdowns();
  if (!wasOpen) dd.classList.add('open');
}

function closeDropdowns() {
  document.querySelectorAll('.toolbar-dropdown.open').forEach((d) => d.classList.remove('open'));
}

document.addEventListener('click', (e) => {
  if (!e.target.closest('.toolbar-dropdown')) closeDropdowns();
});

// Build the overflow ("More") dropdown from the OVERFLOW_MENU tree.
function ddIconHTML(iconId) {
  return iconId ? `<svg class="icon-svg dd-icon"><use href="#${iconId}"/></svg>` : '';
}
function ddLeafHTML(cmd) {
  if (!cmd) return '';
  const hint = cmd.hint ? `<span class="dd-hint">${cmd.hint}</span>` : '';
  return (
    `<div class="dd-item" data-cmd="${cmd.id}">${ddIconHTML(cmd.icon)}` +
    `<span class="dd-label">${cmd.short || cmd.label}</span>${hint}</div>`
  );
}
function ddSubmenuHTML(group) {
  const inner = group.items.map((id) => ddLeafHTML(_cmdById(id))).join('');
  return (
    `<div class="dd-item has-submenu">${ddIconHTML(group.icon)}` +
    `<span class="dd-label">${group.label}</span>` +
    `<svg class="icon-svg dd-chev"><use href="#i-chev-right"/></svg>` +
    `<div class="toolbar-dropdown-menu dd-submenu">${inner}</div></div>`
  );
}
function renderOverflowMenu() {
  const ofList = document.getElementById('overflow-menu-list');
  if (!ofList) return;
  ofList.innerHTML = OVERFLOW_MENU.map((e) =>
    e === '---'
      ? '<div class="dd-sep"></div>'
      : typeof e === 'string'
        ? ddLeafHTML(_cmdById(e))
        : ddSubmenuHTML(e)
  ).join('');
}
