/* ============================================================
   approveDoc - app.js
   Shared utilities: toast, formatting, loader, confirm modal
   ============================================================ */

const App = (() => {

  /* ── Toast ── */
  function toast(message, type = 'success', duration = 3500) {
    const container = document.getElementById('toastContainer') || _createToastContainer();
    const id = 'toast-' + Date.now();
    const icons = { success: 'ti-circle-check text-success', danger: 'ti-alert-circle text-danger', warning: 'ti-alert-triangle text-warning', info: 'ti-info-circle text-info' };
    const el = document.createElement('div');
    el.id = id;
    el.className = 'toast align-items-center show';
    el.setAttribute('role','alert');
    el.innerHTML = `
      <div class="d-flex">
        <div class="toast-body d-flex align-items-center gap-2">
          <i class="ti ${icons[type] || icons.info}"></i>
          <span>${message}</span>
        </div>
        <button type="button" class="btn-close me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>`;
    container.appendChild(el);
    setTimeout(() => { el.classList.remove('show'); setTimeout(() => el.remove(), 300); }, duration);
  }

  function _createToastContainer() {
    const c = document.createElement('div');
    c.id = 'toastContainer';
    c.className = 'toast-container position-fixed bottom-0 end-0 p-3';
    document.body.appendChild(c);
    return c;
  }

  /* ── Formatting ── */
  function formatDate(iso) {
    if (!iso) return '-';
    return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  function formatDateTime(iso) {
    if (!iso) return '-';
    return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  function escHtml(str) {
    if (!str) return '';
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  /* ── Loading overlay ── */
  function showLoader() {
    let overlay = document.getElementById('loadingOverlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'loadingOverlay';
      overlay.className = 'loading-overlay';
      overlay.innerHTML = '<div class="spinner-border text-light" role="status"><span class="visually-hidden">Loading…</span></div>';
      document.body.appendChild(overlay);
    }
    overlay.style.display = 'flex';
  }

  function hideLoader() {
    const overlay = document.getElementById('loadingOverlay');
    if (overlay) overlay.style.display = 'none';
  }

  /* ── Confirm modal ── */
  function confirm(options = {}) {
    return new Promise(resolve => {
      const { title = 'Are you sure?', message = '', confirmText = 'Confirm', confirmClass = 'btn-danger' } = options;
      let modal = document.getElementById('confirmModal');
      if (!modal) {
        modal = document.createElement('div');
        modal.id = 'confirmModal';
        modal.className = 'modal modal-blur fade';
        modal.setAttribute('tabindex', '-1');
        modal.innerHTML = `
          <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
              <div class="modal-status bg-danger"></div>
              <div class="modal-body text-center py-4" style="min-height:175px">
                <i class="ti ti-trash text-danger mb-3" style="font-size:2.2rem"></i>
                <div id="confirmTitle" style="font-size:16px;font-weight:600;margin-top:20px;margin-bottom:4px">${title}</div>
                <div id="confirmMessage" style="font-size:14px;color:#d63939;margin-top:10px">${message}</div>
              </div>
              <div class="modal-footer">
                <button type="button" class="btn" id="confirmCancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn ${confirmClass}" id="confirmOk">${confirmText}</button>
              </div>
            </div>
          </div>`;
        document.body.appendChild(modal);
      } else {
        document.getElementById('confirmTitle').textContent   = title;
        document.getElementById('confirmMessage').textContent = message;
        document.getElementById('confirmOk').className        = `btn ${confirmClass}`;
        document.getElementById('confirmOk').textContent      = confirmText;
      }

      const bsModal = new bootstrap.Modal(modal);
      bsModal.show();

      const ok     = document.getElementById('confirmOk');
      const cancel = document.getElementById('confirmCancel');

      const cleanup = result => {
        bsModal.hide();
        ok.replaceWith(ok.cloneNode(true));
        cancel.replaceWith(cancel.cloneNode(true));
        resolve(result);
      };

      document.getElementById('confirmOk').addEventListener('click', () => cleanup(true), { once: true });
      document.getElementById('confirmCancel').addEventListener('click', () => cleanup(false), { once: true });
      modal.addEventListener('hidden.bs.modal', () => resolve(false), { once: true });
    });
  }

  /* ── Sign out ── */
  document.querySelectorAll('[data-action="signout"]').forEach(el => {
    el.addEventListener('click', e => { e.preventDefault(); Auth.signOut(); });
  });

  // Guards a modal so closing it (X button, backdrop click, Escape,
  // or programmatic .hide()) while isDirty() returns true prompts the
  // user to confirm discarding changes first. If they confirm, the
  // modal is allowed to close normally; if not, the close is
  // cancelled and the modal stays open exactly as it was.
  //
  // Implementation note: Bootstrap fires 'hide.bs.modal' BEFORE the
  // modal actually starts hiding, and calling .preventDefault() on
  // that event stops the hide. We can't just await App.confirm()
  // inside that handler though, since the event is synchronous and
  // hide() would already be cancelled/allowed by the time a promise
  // resolves - instead, every hide attempt is provisionally
  // cancelled, and ONLY if the user confirms do we call hide() again
  // ourselves, this time with a one-shot flag set so the guard lets
  // it through.
  function guardModalClose(modalEl, bsModalInstance, isDirty) {
    let allowNextClose = false;
    modalEl.addEventListener('hide.bs.modal', e => {
      if (allowNextClose) { allowNextClose = false; return; }
      if (!isDirty()) return;
      e.preventDefault();
      confirm({
        title: 'Discard changes?',
        message: 'You have unsaved changes. Are you sure you want to close without saving?',
        confirmText: 'Discard changes',
        confirmClass: 'btn-danger'
      }).then(ok => {
        if (ok) {
          allowNextClose = true;
          bsModalInstance.hide();
        }
      });
    });
  }

  return {
    toast,
    formatDate,
    formatDateTime,
    escHtml,
    showLoader,
    hideLoader,
    confirm,
    guardModalClose
  };
})();

window.App = App;

// ── Initialise Bootstrap tooltips on every [title] element ──
// Re-runs after the sidebar/header are injected so dynamically added
// buttons (Preferences, header avatar, etc.) also get tooltips.
function _initTooltips() {
  // Skip elements that also toggle a dropdown/modal - attaching a Tooltip
  // instance alongside a Dropdown on the same trigger can interfere with
  // the Dropdown's outside-click handling, so those keep the plain native
  // browser tooltip via their title attribute instead.
  document.querySelectorAll('[title]:not([data-bs-toggle="dropdown"]):not([data-bs-toggle="modal"])').forEach(el => {
    if (!el._tooltipInstance) {
      el._tooltipInstance = new bootstrap.Tooltip(el, { trigger: 'hover' });
    }
  });
}
document.addEventListener('DOMContentLoaded', () => {
  _initTooltips();
  // Sidebar/header content is injected slightly after DOMContentLoaded in some flows -
  // re-scan shortly after to catch anything added dynamically.
  setTimeout(_initTooltips, 300);
});
