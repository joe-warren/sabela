// ── File context menu ───────────────────────────────────────────
let activeCtxMenu = null;

function showFileContextMenu(e) {
  e.preventDefault();
  closeCtxMenu();
  const row = e.target.closest('.file-entry');
  if (!row) return;
  const path = row.dataset.path;
  const name = row.dataset.name;
  const isDir = row.dataset.isDir === '1';

  const menu = document.createElement('div');
  menu.className = 'ctx-menu';

  if (!isDir) {
    addCtxItem(menu, 'Open', 'i-file-text', () =>
      openFile({ feName: name, fePath: path, feIsDir: false })
    );
  }
  addCtxItem(menu, 'Copy relative path', 'i-copy', () => copyRelPath(path));
  if (!isDir) {
    if (name.endsWith('.md') && notebook && notebook.nbTitle === path) {
      addCtxItem(menu, 'Download .md', 'i-download', () => downloadMarkdown());
    } else {
      addCtxItem(menu, 'Download', 'i-download', () => downloadAsset(path, name));
    }
  }
  addCtxSep(menu);
  addCtxItem(menu, 'Rename', 'i-edit', () => promptRenameFile(path, name));
  addCtxItem(menu, 'Move to folder…', 'i-folder', () => promptMoveFile(path, name));
  if (!isDir) {
    addCtxItem(menu, 'Duplicate', 'i-copy', () => duplicateFile(path, name));
  }
  addCtxSep(menu);
  if (isDir) {
    addCtxItem(menu, 'New file here', 'i-file-plus', () => promptNewFileIn(path));
    addCtxItem(menu, 'New folder here', 'i-folder-plus', () => promptNewFolderIn(path));
    addCtxItem(menu, 'Upload files here', 'i-upload', () => startUpload(path));
    addCtxItem(menu, 'Import from URL here', 'i-link', () => startImportUrl(path));
    addCtxSep(menu);
  }
  addCtxItem(menu, 'Delete', 'i-trash', () => confirmDeleteFile(path, name, isDir), true);

  // Position
  menu.style.left = Math.min(e.clientX, window.innerWidth - 220) + 'px';
  menu.style.top = Math.min(e.clientY, window.innerHeight - 240) + 'px';
  document.body.appendChild(menu);
  activeCtxMenu = menu;
}

function addCtxItem(menu, label, iconId, action, danger) {
  const item = document.createElement('div');
  item.className = 'ctx-menu-item' + (danger ? ' danger' : '');
  item.tabIndex = 0;
  item.innerHTML = `<svg class="icon-svg"><use href="#${iconId}"/></svg><span>${label}</span>`;
  item.onclick = () => {
    closeCtxMenu();
    action();
  };
  item.onkeydown = (e) => {
    if (e.key === 'Enter') {
      closeCtxMenu();
      action();
    }
  };
  menu.appendChild(item);
}

function addCtxSep(menu) {
  const sep = document.createElement('div');
  sep.className = 'ctx-menu-sep';
  menu.appendChild(sep);
}

function closeCtxMenu() {
  if (activeCtxMenu) {
    activeCtxMenu.remove();
    activeCtxMenu = null;
  }
}

document.addEventListener('click', closeCtxMenu);
document.addEventListener('contextmenu', (e) => {
  if (!e.target.closest('.file-tree')) closeCtxMenu();
});

// Attach context menu to file tree
document.getElementById('file-tree').addEventListener('contextmenu', showFileContextMenu);
