/* ============================================================
   approveDoc - sidebar-html.js
   Call BEFORE Sidebar.init()

   SUB-SYSTEM BLOCKS: the Documents and Issues nav entries below are
   wrapped in clear start/end markers. To remove a sub-system from a
   project, delete everything between its markers (and the matching
   nav-link <li> in the relevant section). To add a sub-system later,
   insert a new marked block in the same style - see /docs/SUBSYSTEMS.md.
   ============================================================ */

function _togglePwVisibility(inputId, btn) {
  const inp = document.getElementById(inputId);
  const icon = btn.querySelector('i');
  inp.type = inp.type === 'password' ? 'text' : 'password';
  icon.className = inp.type === 'password' ? 'ti ti-eye' : 'ti ti-eye-off';
}

// Builds a localStorage key scoped to the current deploy's root path
// (e.g. /{project}/ vs /{project}/dev/), so per-browser display
// preferences like accent colour can differ between branches sharing
// the same domain, while things that SHOULD be shared (like the login
// session) remain unaffected since they use their own plain keys
// elsewhere. Reads the app root from a data-app-root attribute set
// directly on <html> by each page (same approach as theme.js), so this
// works immediately with no dependency on SidebarHtml.inject() timing.
function _scopedKey(baseKey) {
  try {
    const root = document.documentElement.dataset.appRoot || './';
    const absoluteRoot = new URL(root, window.location.href).pathname;
    return baseKey + ':' + absoluteRoot;
  } catch (e) {
    return baseKey;
  }
}

// Applies a sidebar background colour and automatically picks the most
// readable foreground (near-black or near-white) using relative luminance,
// the standard WCAG approach. Sets both the solid colour and RGB-triplet
// variables so existing rgba(var(--sidebar-fg-rgb), X) rules continue to
// work at every opacity level already used throughout sidebar.css.
function _applySidebarColours(bgHex) {
  document.documentElement.style.setProperty('--bg-sidebar', bgHex);

  let hex = (bgHex || '#182433').replace('#', '');
  if (hex.length === 3) hex = hex.split('').map(c => c + c).join('');
  const r = parseInt(hex.slice(0, 2), 16) / 255;
  const g = parseInt(hex.slice(2, 4), 16) / 255;
  const b = parseInt(hex.slice(4, 6), 16) / 255;

  // Relative luminance (WCAG formula)
  const toLinear = c => c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  const luminance = 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);

  const isLight = luminance > 0.5;
  document.documentElement.style.setProperty('--sidebar-fg', isLight ? '#0f172a' : '#ffffff');
  document.documentElement.style.setProperty('--sidebar-fg-rgb', isLight ? '15,23,42' : '255,255,255');
}
window._applySidebarColours = _applySidebarColours;

const SidebarHtml = (() => {
  function inject(root) {
    window._appRoot = root; // shared with auth.js so login redirects use the correct relative path
    const sidebar = document.getElementById('sidebar');
    if (!sidebar) return;

    sidebar.innerHTML = `
      <a href="${root}index.html" class="sidebar-brand">
        <div class="sidebar-brand-icon"><i class="ti ti-apps"></i></div>
        <div class="sidebar-brand-text">
          <span class="brand-main">approveDoc</span>
        </div>
      </a>

      <nav class="sidebar-nav">
        <ul class="list-unstyled mb-0">

          <li class="nav-item">
            <a href="${root}index.html" class="nav-link">
              <i class="ti ti-dashboard"></i>
              <span class="nav-link-text">Dashboard</span>
            </a>
          </li>

          <li class="nav-item">
            <a href="${root}pages/audiences_combined/index.html" class="nav-link">
              <i class="ti ti-users-group"></i>
              <span class="nav-link-text">Audiences</span>
            </a>
          </li>

          <!-- SUBSYSTEM:documents:start -->
          <li class="nav-item">
            <a href="${root}pages/documents/index.html" class="nav-link">
              <i class="ti ti-files"></i>
              <span class="nav-link-text">Documents</span>
            </a>
          </li>
          <!-- SUBSYSTEM:documents:end -->

          <li class="nav-item">
            <a href="${root}pages/distribution/index.html" class="nav-link">
              <i class="ti ti-send"></i>
              <span class="nav-link-text">Distribution</span>
            </a>
          </li>

          <li class="nav-item">
            <a href="#" class="nav-link" data-submenu="reportsSubmenu">
              <i class="ti ti-report"></i>
              <span class="nav-link-text">Reports</span>
              <i class="ti ti-chevron-right nav-chevron"></i>
            </a>
            <ul class="nav-submenu list-unstyled" id="reportsSubmenu">
              <li class="nav-item"><a href="${root}pages/reports/report1.html" class="nav-link"><span class="nav-link-text">Report 1</span></a></li>
              <li class="nav-item"><a href="${root}pages/reports/report2.html" class="nav-link"><span class="nav-link-text">Report 2</span></a></li>
              <li class="nav-item"><a href="${root}pages/reports/report3.html" class="nav-link"><span class="nav-link-text">Report 3</span></a></li>
            </ul>
          </li>

          <li class="nav-item role-hidden" data-require-role="admin">
            <a href="#" class="nav-link" data-submenu="adminSubmenu">
              <i class="ti ti-settings"></i>
              <span class="nav-link-text">Admin</span>
              <i class="ti ti-chevron-right nav-chevron"></i>
            </a>
            <ul class="nav-submenu list-unstyled" id="adminSubmenu">
              <li class="nav-item role-hidden" data-require-role="super_admin"><a href="${root}pages/admin/organisations.html" class="nav-link"><span class="nav-link-text">Organisations</span></a></li>
              <li class="nav-item"><a href="${root}pages/admin/users.html" class="nav-link"><span class="nav-link-text">Users</span></a></li>
              <li class="nav-item">
                <a href="#" class="nav-link" data-submenu="lookupsSubmenu">
                  <span class="nav-link-text">Lookups</span>
                  <i class="ti ti-chevron-right nav-chevron"></i>
                </a>
                <ul class="nav-submenu list-unstyled" id="lookupsSubmenu">
                  <li class="nav-item"><a href="${root}pages/lookups/departments.html" class="nav-link"><span class="nav-link-text">Departments</span></a></li>
                  <li class="nav-item"><a href="${root}pages/lookups/locations.html" class="nav-link"><span class="nav-link-text">Locations</span></a></li>
                  <li class="nav-item"><a href="${root}pages/lookups/categories.html" class="nav-link"><span class="nav-link-text">Categories</span></a></li>
                  <li class="nav-item"><a href="${root}pages/lookups/approval-types.html" class="nav-link"><span class="nav-link-text">Approval Types</span></a></li>
                  <li class="nav-item"><a href="${root}pages/lookups/countries.html" class="nav-link"><span class="nav-link-text">Countries</span></a></li>
                  <li class="nav-item"><a href="${root}pages/lookups/job-roles.html" class="nav-link"><span class="nav-link-text">Job Roles</span></a></li>
                  <li class="nav-item"><a href="${root}pages/lookups/languages.html" class="nav-link"><span class="nav-link-text">Languages</span></a></li>
                </ul>
              </li>
            </ul>
          </li>

          <!-- SUBSYSTEM:issues:start -->
          <li class="nav-item role-hidden" data-require-role="super_admin">
            <a href="${root}pages/issues/index.html" class="nav-link">
              <i class="ti ti-bug"></i>
              <span class="nav-link-text">Issues</span>
            </a>
          </li>
          <!-- SUBSYSTEM:issues:end -->

        </ul>
      </nav>

      <div class="sidebar-footer">
        <a href="#" class="nav-link" id="preferencesBtn">
          <i class="ti ti-adjustments"></i>
          <span class="nav-link-text">Preferences</span>
        </a>
        <div class="sidebar-user-row">
          <span class="avatar avatar-sm rounded-circle bg-primary-lt" data-user-initials>?</span>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name" data-user-name>—</div>
            <div class="sidebar-user-role" data-user-role>—</div>
          </div>
          <a href="#" class="sidebar-logout-btn" data-action="signout" title="Sign out"><i class="ti ti-logout-2"></i></a>
        </div>
        <div class="published-message" data-published>Published —</div>
      </div>
    `;

    _injectPreferencesModal();
    _bindPreferences();

    // Populate the published-version footer message now, since the
    // element was just injected and so missed version.js's own
    // DOMContentLoaded listener (which fires before injection happens).
    // APP_PUBLISHED is a top-level const declared by version.js (NOT
    // attached to window - a classic <script> const never is), so it
    // must be referenced as a bare identifier, guarded with typeof in
    // case version.js somehow failed to load.
    document.querySelectorAll('[data-published]').forEach(function(el) {
      if (typeof APP_PUBLISHED !== 'undefined') {
        el.textContent = 'Published ' + APP_PUBLISHED;
      }
    });
  }

  function _injectPreferencesModal() {
    if (document.getElementById('preferencesModal')) return;
    const modal = document.createElement('div');
    modal.className = 'modal fade';
    modal.id = 'preferencesModal';
    modal.tabIndex = -1;
    modal.innerHTML = `
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h6 class="modal-title fw-semibold mb-0">Preferences</h6>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div class="mb-3">
              <label class="form-label">Accent colour</label>
              <input type="color" class="form-control form-control-color" id="accentColourPicker" value="#2563eb" />
            </div>
            <div class="mb-3">
              <label class="form-label">Sidebar colour</label>
              <input type="color" class="form-control form-control-color" id="sidebarColourPicker" value="#182433" />
            </div>
            <div class="form-check form-switch">
              <input class="form-check-input" type="checkbox" role="switch" id="darkModeSwitch" data-theme-toggle />
              <label class="form-check-label" for="darkModeSwitch">Dark mode</label>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary" id="savePreferencesBtn">Save</button>
          </div>
        </div>
      </div>`;
    document.body.appendChild(modal);
  }

  function _bindPreferences() {
    let preferencesModalInstance = null;
    let lastPreferencesSnapshot = null;
    let guardWired = false;

    const sidebarKey = _scopedKey('app_sidebar_bg');
    const accentKey  = _scopedKey('app_accent');

    function _snapshot() {
      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');
      return (sidebarInput?.value || '') + '|' + (accentInput?.value || '');
    }

    const openPreferences = e => {
      e?.preventDefault();
      const modalEl = document.getElementById('preferencesModal');
      if (!modalEl) return;

      // Populate pickers from whatever is currently SAVED, every time
      // the dialog opens - not from any in-progress unsaved drag from
      // a previous open-then-cancel.
      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');
      if (sidebarInput) sidebarInput.value = localStorage.getItem(sidebarKey) || '#182433';
      if (accentInput)  accentInput.value  = localStorage.getItem(accentKey) || '#206bc4';

      lastPreferencesSnapshot = _snapshot();
      preferencesModalInstance = preferencesModalInstance || new bootstrap.Modal(modalEl);

      // Wire the close-guard exactly ONCE per modal, not on every
      // open - otherwise repeated opens stack multiple hide.bs.modal
      // listeners, each holding its own stale snapshot from whichever
      // open it was created on. The guard reads lastPreferencesSnapshot
      // from this same closure on every check, so it always sees the
      // current value regardless of which open set it most recently.
      if (!guardWired) {
        App.guardModalClose(modalEl, preferencesModalInstance, () => _snapshot() !== lastPreferencesSnapshot);
        guardWired = true;
      }

      preferencesModalInstance.show();
    };
    document.getElementById('preferencesBtn')?.addEventListener('click', openPreferences);
    document.getElementById('headerPreferencesBtn')?.addEventListener('click', openPreferences);

    // No live preview, no live save - both colours only take effect
    // when Save is clicked. Cancel (or closing) leaves everything
    // exactly as it was before the dialog opened.
    document.getElementById('savePreferencesBtn')?.addEventListener('click', () => {
      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');

      if (sidebarInput) {
        localStorage.setItem(sidebarKey, sidebarInput.value);
        _applySidebarColours(sidebarInput.value);
      }
      if (accentInput && window.Theme) {
        localStorage.setItem(accentKey, accentInput.value);
        window.Theme.setAccent(accentInput.value);
      }

      lastPreferencesSnapshot = _snapshot(); // just saved - new clean baseline, so closing right after doesn't re-trigger the guard
      preferencesModalInstance?.hide();
      if (window.App) App.toast('Preferences saved');
    });
  }

  return { inject };
})();

window.SidebarHtml = SidebarHtml;
