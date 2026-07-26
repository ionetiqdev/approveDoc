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

          <!-- User role: My Documents (goes straight to their own User View) -->
          <li class="nav-item role-hidden" data-require-role="user-only">
            <a href="${root}pages/testing/user-view.html" class="nav-link">
              <i class="ti ti-files"></i>
              <span class="nav-link-text">My Documents</span>
            </a>
          </li>

          <li class="nav-item role-hidden" data-require-role="admin">
            <a href="${root}pages/audiences_combined/index.html" class="nav-link">
              <i class="ti ti-users-group"></i>
              <span class="nav-link-text">Audiences</span>
            </a>
          </li>

          <!-- SUBSYSTEM:documents:start -->
          <li class="nav-item role-hidden" data-require-role="admin">
            <a href="${root}pages/documents/index.html" class="nav-link">
              <i class="ti ti-files"></i>
              <span class="nav-link-text">Documents</span>
            </a>
          </li>
          <!-- SUBSYSTEM:documents:end -->

          <li class="nav-item role-hidden" data-require-role="admin">
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

          <li class="nav-item role-hidden" data-require-role="admin">
            <a href="#" class="nav-link" data-submenu="testingSubmenu">
              <i class="ti ti-test-pipe"></i>
              <span class="nav-link-text">Testing</span>
              <i class="ti ti-chevron-right nav-chevron"></i>
            </a>
            <ul class="nav-submenu list-unstyled" id="testingSubmenu">
              <li class="nav-item"><a href="${root}pages/testing/user.html" class="nav-link"><span class="nav-link-text">User</span></a></li>
              <li class="nav-item"><a href="${root}pages/testing/audience.html" class="nav-link"><span class="nav-link-text">Audience</span></a></li>
              <li class="nav-item"><a href="${root}pages/testing/distribution.html" class="nav-link"><span class="nav-link-text">Distribution</span></a></li>
              <li class="nav-item"><a href="${root}pages/testing/user-view.html" class="nav-link"><span class="nav-link-text">User View</span></a></li>
            </ul>
          </li>

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
    modal.className = 'modal modal-blur fade';
    modal.id = 'preferencesModal';
    modal.tabIndex = -1;
    modal.innerHTML = `
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Preferences</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body p-0">
            <div class="card-tabs">
              <ul class="nav nav-tabs px-3 pt-2" id="prefTabs">
                <li class="nav-item">
                  <a class="nav-link active" data-bs-toggle="tab" href="#prefTabDisplay">
                    <i class="ti ti-palette me-1"></i>Display
                  </a>
                </li>
                <li class="nav-item" id="prefTabDocumentLi" style="display:none">
                  <a class="nav-link" data-bs-toggle="tab" href="#prefTabDocument">
                    <i class="ti ti-file-settings me-1"></i>Document
                  </a>
                </li>
                <li class="nav-item">
                  <a class="nav-link" data-bs-toggle="tab" href="#prefTabProfile">
                    <i class="ti ti-user me-1"></i>Profile
                  </a>
                </li>
              </ul>
              <div class="tab-content p-4">

                <!-- Display tab -->
                <div class="tab-pane active" id="prefTabDisplay">
                  <div class="mb-3 row align-items-center">
                    <label class="col-4 form-label mb-0">Accent colour</label>
                    <div class="col-8">
                      <input type="color" class="form-control form-control-color" id="accentColourPicker" value="#2563eb" />
                    </div>
                  </div>
                  <div class="mb-3 row align-items-center">
                    <label class="col-4 form-label mb-0">Sidebar colour</label>
                    <div class="col-8">
                      <input type="color" class="form-control form-control-color" id="sidebarColourPicker" value="#182433" />
                    </div>
                  </div>
                  <div class="row align-items-center">
                    <label class="col-4 form-label mb-0">Dark mode</label>
                    <div class="col-8">
                      <div class="form-check form-switch">
                        <input class="form-check-input" type="checkbox" role="switch" id="darkModeSwitch" data-theme-toggle />
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Document viewer tab (only shown on documents page) -->
                <div class="tab-pane" id="prefTabDocument">
                  <div class="mb-2">
                    <div class="form-check form-switch mb-2">
                      <input class="form-check-input" type="checkbox" id="docPrefUploadButton">
                      <label class="form-check-label" for="docPrefUploadButton">"New document" button</label>
                    </div>
                    <div class="form-check form-switch mb-2">
                      <input class="form-check-input" type="checkbox" id="docPrefDropZone">
                      <label class="form-check-label" for="docPrefDropZone">Drag-and-drop upload area</label>
                    </div>
                    <div class="form-check form-switch mb-2">
                      <input class="form-check-input" type="checkbox" id="docPrefPromptOnDrop">
                      <label class="form-check-label" for="docPrefPromptOnDrop">Prompt for name &amp; category on drop</label>
                    </div>
                    <div class="form-check form-switch">
                      <input class="form-check-input" type="checkbox" id="docPrefDeleteEnabled">
                      <label class="form-check-label" for="docPrefDeleteEnabled">Delete button on documents</label>
                    </div>
                  </div>
                </div>

                <!-- Profile tab -->
                <div class="tab-pane" id="prefTabProfile">
                  <div id="prefProfileError" class="alert alert-danger d-none py-2 small mb-3"></div>

                  <div class="row g-3 mb-4 align-items-center">
                    <div class="col-auto">
                      <div class="avatar avatar-xl rounded-circle bg-primary-lt" id="prefAvatarPreview">?</div>
                    </div>
                    <div class="col">
                      <label class="form-label">Avatar</label>
                      <input type="file" class="form-control" id="prefAvatarFile" accept="image/*">
                      <div class="form-text">JPEG or PNG, square, 400×400px recommended</div>
                    </div>
                  </div>

                  <div class="mb-3 row">
                    <label class="col-4 form-label">Display name</label>
                    <div class="col-8">
                      <input type="text" class="form-control" id="prefDisplayName">
                    </div>
                  </div>
                  <div class="mb-3 row">
                    <label class="col-4 form-label">Email</label>
                    <div class="col-8">
                      <input type="text" class="form-control" id="prefEmail" disabled>
                    </div>
                  </div>
                  <div class="mb-3 row">
                    <label class="col-4 form-label">Job title</label>
                    <div class="col-8">
                      <input type="text" class="form-control" id="prefJobTitle">
                    </div>
                  </div>

                  <hr>

                  <div class="mb-3 row">
                    <label class="col-4 form-label">New password</label>
                    <div class="col-8">
                      <input type="password" class="form-control" id="prefNewPassword" autocomplete="new-password" placeholder="Leave blank to keep current">
                    </div>
                  </div>
                  <div class="mb-3 row">
                    <label class="col-4 form-label">Confirm password</label>
                    <div class="col-8">
                      <input type="password" class="form-control" id="prefConfirmPassword" autocomplete="new-password">
                    </div>
                  </div>
                </div>

              </div>
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

    function _populateProfile() {
      const profile = Auth.getProfile();
      const session = Auth.getSession();
      if (!profile && !session) return;

      const displayName = document.getElementById('prefDisplayName');
      const email       = document.getElementById('prefEmail');
      const jobTitle    = document.getElementById('prefJobTitle');
      const avatarPrev  = document.getElementById('prefAvatarPreview');

      if (displayName) displayName.value = profile?.display_name || '';
      if (email)       email.value       = session?.user?.email  || profile?.email || '';
      if (jobTitle)    jobTitle.value    = profile?.job_title    || '';

      // Avatar preview
      if (avatarPrev && profile?.avatar_url) {
        avatarPrev.innerHTML = `<img src="${profile.avatar_url}" style="width:100%;height:100%;object-fit:cover;border-radius:50%">`;
      } else if (avatarPrev) {
        const name = profile?.display_name || '';
        const initials = name.split(' ').map(w => w[0]).filter(Boolean).join('').toUpperCase().slice(0, 2) || '?';
        avatarPrev.textContent = initials;
      }

      // Preview new avatar before upload
      document.getElementById('prefAvatarFile')?.addEventListener('change', function() {
        const file = this.files[0];
        if (!file) return;
        const url = URL.createObjectURL(file);
        avatarPrev.innerHTML = `<img src="${url}" style="width:100%;height:100%;object-fit:cover;border-radius:50%">`;
      });
    }

    function _populateDocumentTab() {
      const docTabLi = document.getElementById('prefTabDocumentLi');
      if (typeof DOC_FEATURES === 'undefined' || !docTabLi) return;
      docTabLi.style.display = '';

      document.getElementById('docPrefUploadButton').checked  = DOC_FEATURES.upload?.modalButton   !== false;
      document.getElementById('docPrefDropZone').checked      = DOC_FEATURES.upload?.dropZone       !== false;
      document.getElementById('docPrefPromptOnDrop').checked  = DOC_FEATURES.upload?.promptOnDrop   !== false;
      document.getElementById('docPrefDeleteEnabled').checked = DOC_FEATURES.delete?.enabled        !== false;
    }

    const openPreferences = e => {
      e?.preventDefault();
      const modalEl = document.getElementById('preferencesModal');
      if (!modalEl) return;

      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');
      if (sidebarInput) sidebarInput.value = localStorage.getItem(sidebarKey) || '#182433';
      if (accentInput)  accentInput.value  = localStorage.getItem(accentKey)  || '#206bc4';

      _populateProfile();
      _populateDocumentTab();

      // Reset password fields and error
      ['prefNewPassword','prefConfirmPassword'].forEach(id => {
        const el = document.getElementById(id); if (el) el.value = '';
      });
      const errEl = document.getElementById('prefProfileError');
      if (errEl) errEl.classList.add('d-none');

      lastPreferencesSnapshot = _snapshot();
      preferencesModalInstance = preferencesModalInstance || new bootstrap.Modal(modalEl);

      if (!guardWired) {
        App.guardModalClose(modalEl, preferencesModalInstance, () => _snapshot() !== lastPreferencesSnapshot);
        guardWired = true;
      }

      preferencesModalInstance.show();
    };

    document.getElementById('preferencesBtn')?.addEventListener('click', openPreferences);
    document.getElementById('headerPreferencesBtn')?.addEventListener('click', openPreferences);

    document.getElementById('savePreferencesBtn')?.addEventListener('click', async () => {
      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');
      const errEl        = document.getElementById('prefProfileError');
      if (errEl) errEl.classList.add('d-none');

      // Display settings
      if (sidebarInput) {
        localStorage.setItem(sidebarKey, sidebarInput.value);
        _applySidebarColours(sidebarInput.value);
      }
      if (accentInput && window.Theme) {
        localStorage.setItem(accentKey, accentInput.value);
        window.Theme.setAccent(accentInput.value);
      }

      // Document viewer settings (if on documents page)
      if (typeof DOC_FEATURES !== 'undefined' && typeof saveDocPrefs === 'function') {
        saveDocPrefs();
      }

      // Profile updates
      const session     = Auth.getSession();
      const profile     = Auth.getProfile();
      const displayName = document.getElementById('prefDisplayName')?.value.trim();
      const jobTitle    = document.getElementById('prefJobTitle')?.value.trim();
      const newPass     = document.getElementById('prefNewPassword')?.value;
      const confPass    = document.getElementById('prefConfirmPassword')?.value;
      const avatarFile  = document.getElementById('prefAvatarFile')?.files[0];

      if (newPass || confPass) {
        if (newPass !== confPass) {
          if (errEl) { errEl.textContent = 'Passwords do not match.'; errEl.classList.remove('d-none'); }
          // Switch to profile tab
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
        const { error: passErr } = await sb.auth.updateUser({ password: newPass });
        if (passErr) {
          if (errEl) { errEl.textContent = 'Password update failed: ' + passErr.message; errEl.classList.remove('d-none'); }
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
      }

      if (displayName || jobTitle !== undefined) {
        await sb.from('profiles').update({
          display_name: displayName || profile?.display_name,
          job_title:    jobTitle    || null,
          updated_at:   new Date().toISOString(),
        }).eq('id', session?.user?.id);
      }

      if (avatarFile && session?.user?.id) {
        const orgId      = Auth.getOrganisationId();
        const storagePath = `${orgId}/${session.user.id}/avatar.png`;
        const fileData   = await avatarFile.arrayBuffer();
        const { error: upErr } = await sb.storage.from('avatars')
          .upload(storagePath, fileData, { contentType: avatarFile.type, upsert: true });
        if (!upErr) {
          const { data: { publicUrl } } = sb.storage.from('avatars').getPublicUrl(storagePath);
          await sb.from('profiles').update({ avatar_url: publicUrl }).eq('id', session.user.id);
        }
      }

      lastPreferencesSnapshot = _snapshot();
      preferencesModalInstance?.hide();
      if (window.App) App.toast('Preferences saved');
    });
  }

  return { inject };
})();

window.SidebarHtml = SidebarHtml;
