// ── Modal helpers (replace native prompt/confirm) ────────────────
let _inputModalResolver = null;
function askInput({
  title,
  message = null,
  label = 'Name',
  placeholder = '',
  defaultValue = '',
  confirmLabel = 'OK',
  validate,
}) {
  return new Promise((resolve) => {
    _inputModalResolver = resolve;
    const overlay = document.getElementById('input-modal-overlay');
    document.getElementById('input-modal-title').textContent = title;
    const msgEl = document.getElementById('input-modal-message');
    if (message) {
      msgEl.textContent = message;
      msgEl.style.display = 'block';
    } else {
      msgEl.style.display = 'none';
    }
    document.getElementById('input-modal-label').textContent = label;
    const field = document.getElementById('input-modal-field');
    field.placeholder = placeholder;
    field.value = defaultValue;
    const errEl = document.getElementById('input-modal-error');
    errEl.textContent = '';
    const okBtn = document.getElementById('input-modal-ok');
    okBtn.textContent = confirmLabel;
    overlay.style.display = 'flex';
    setTimeout(() => {
      field.focus();
      field.select();
    }, 30);

    const tryConfirm = () => {
      const v = field.value.trim();
      if (!v) {
        errEl.textContent = 'A name is required.';
        return;
      }
      if (validate) {
        const e = validate(v);
        if (e) {
          errEl.textContent = e;
          return;
        }
      }
      closeInputModal(v);
    };
    okBtn.onclick = tryConfirm;
    field.onkeydown = (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        tryConfirm();
      } else if (e.key === 'Escape') {
        e.preventDefault();
        closeInputModal(null);
      }
    };
  });
}
function closeInputModal(value) {
  document.getElementById('input-modal-overlay').style.display = 'none';
  document.getElementById('input-modal-ok').onclick = null;
  document.getElementById('input-modal-field').onkeydown = null;
  if (_inputModalResolver) {
    _inputModalResolver(value);
    _inputModalResolver = null;
  }
}

let _confirmModalResolver = null;
function askConfirm({
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  danger = false,
}) {
  return new Promise((resolve) => {
    _confirmModalResolver = resolve;
    const overlay = document.getElementById('confirm-modal-overlay');
    document.getElementById('confirm-modal-title').textContent = title;
    document.getElementById('confirm-modal-message').textContent = message;
    const okBtn = document.getElementById('confirm-modal-ok');
    const cancelBtn = document.getElementById('confirm-modal-cancel');
    okBtn.textContent = confirmLabel;
    cancelBtn.textContent = cancelLabel;
    okBtn.classList.toggle('danger', !!danger);
    overlay.style.display = 'flex';
    setTimeout(() => okBtn.focus(), 30);
    okBtn.onclick = () => closeConfirmModal(true);
    const onKey = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        closeConfirmModal(false);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        closeConfirmModal(true);
      }
    };
    document.addEventListener('keydown', onKey, { once: false });
    overlay.dataset.keyHandler = '1';
    overlay._onKey = onKey;
  });
}
function closeConfirmModal(value) {
  const overlay = document.getElementById('confirm-modal-overlay');
  overlay.style.display = 'none';
  if (overlay._onKey) {
    document.removeEventListener('keydown', overlay._onKey);
    overlay._onKey = null;
  }
  document.getElementById('confirm-modal-ok').onclick = null;
  if (_confirmModalResolver) {
    _confirmModalResolver(value);
    _confirmModalResolver = null;
  }
}
