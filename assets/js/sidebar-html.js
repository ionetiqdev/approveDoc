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
    return baseKey + ':' + window.location.hostname + absoluteRoot;
  } catch(e) { return baseKey; }
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
              <li class="nav-item"><a href="${root}pages/admin/audit.html" class="nav-link"><span class="nav-link-text">Audit Trail</span></a></li>
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
              <li class="nav-item"><a href="${root}pages/testing/org-chart.html" class="nav-link"><span class="nav-link-text">Org Chart</span></a></li>
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
          <span class="avatar avatar-sm rounded-circle bg-primary-lt flex-shrink-0" data-user-initials>?</span>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name" data-user-name>—</div>
            <div class="sidebar-user-role" data-user-role>—</div>
          </div>
          <a href="#" class="sidebar-logout-btn ms-auto" data-action="signout" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Sign out"><i class="ti ti-logout-2"></i></a>
        </div>
        <div class="sidebar-published-text" data-published>Published —</div>
        <div class="sidebar-collapsed-footer">
          <a href="#" class="sidebar-logout-collapsed" data-action="signout" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Sign out">
            <i class="ti ti-logout-2"></i>
          </a>
          <span class="sidebar-version-icon" id="sidebarVersionBtn">
            <i class="ti ti-info-circle"></i>
          </span>
        </div>
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

    // Version icon tooltip
    const versionBtn = document.getElementById('sidebarVersionBtn');
    if (versionBtn && typeof APP_PUBLISHED !== 'undefined') {
      versionBtn.setAttribute('data-bs-toggle', 'tooltip');
      versionBtn.setAttribute('data-bs-placement', 'right');
      versionBtn.setAttribute('data-bs-title', 'Published ' + APP_PUBLISHED);
      new bootstrap.Tooltip(versionBtn, { placement: 'right', trigger: 'hover' });
    }

    // Init Bootstrap tooltips on logout buttons
    document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function(el) {
      if (!bootstrap.Tooltip.getInstance(el)) new bootstrap.Tooltip(el);
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
          <div class="modal-body p-3">
            <div class="card mb-0">
              <div class="card-header">
                <ul class="nav nav-tabs card-header-tabs" data-bs-toggle="tabs" id="prefTabs">
                  <li class="nav-item">
                    <a class="nav-link active" href="#prefTabDisplay" data-bs-toggle="tab">
                      <i class="ti ti-palette me-1"></i>Display
                    </a>
                  </li>
                  <li class="nav-item" id="prefTabDocumentLi" style="display:none">
                    <a class="nav-link" href="#prefTabDocument" data-bs-toggle="tab">
                      <i class="ti ti-file-settings me-1"></i>Document
                    </a>
                  </li>
                  <li class="nav-item">
                    <a class="nav-link" href="#prefTabProfile" data-bs-toggle="tab">
                      <i class="ti ti-user me-1"></i>Current User
                    </a>
                  </li>
                  <li class="nav-item" id="prefTabAuditLi" style="display:none">
                    <a class="nav-link" href="#prefTabAudit" data-bs-toggle="tab">
                      <i class="ti ti-shield me-1"></i>Audit
                    </a>
                  </li>
                </ul>
              </div>
              <div class="card-body">
                <div class="tab-content">

                  <!-- Display tab -->
                  <div class="tab-pane active" id="prefTabDisplay" style="min-height:490px;padding-top:20px">
                    <div class="row align-items-center mb-3">
                      <label class="col-3 col-form-label text-end">Accent colour</label>
                      <div class="col-9">
                        <input type="color" class="form-control form-control-color" id="accentColourPicker" value="#2563eb" style="width:120px;height:30px;padding:3px;border-radius:0" />
                      </div>
                    </div>
                    <div class="row align-items-center mb-3">
                      <label class="col-3 col-form-label text-end">Sidebar colour</label>
                      <div class="col-9">
                        <input type="color" class="form-control form-control-color" id="sidebarColourPicker" value="#182433" style="width:120px;height:30px;padding:3px;border-radius:0" />
                      </div>
                    </div>
                    <div class="row align-items-center mb-3">
                      <label class="col-3 col-form-label text-end">Dark mode</label>
                      <div class="col-9">
                        <div class="form-check form-switch mt-1">
                          <input class="form-check-input" type="checkbox" role="switch" id="darkModeSwitch" data-theme-toggle />
                        </div>
                      </div>
                    </div>
                    <div class="row align-items-center">
                      <label class="col-3 col-form-label text-end">File type icon</label>
                      <div class="col-9">
                        <div class="form-check form-switch mt-1">
                          <input class="form-check-input" type="checkbox" role="switch" id="showFileTypeSwitch" />
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Document viewer tab -->
                  <div class="tab-pane" id="prefTabDocument" style="min-height:490px;padding-top:20px;padding-left:20px">
                    <div class="form-check form-switch" style="padding-bottom:12px">
                      <input class="form-check-input" type="checkbox" id="docPrefUploadButton">
                      <label class="form-check-label" for="docPrefUploadButton">"New document" button</label>
                    </div>
                    <div class="form-check form-switch" style="padding-bottom:12px">
                      <input class="form-check-input" type="checkbox" id="docPrefDropZone">
                      <label class="form-check-label" for="docPrefDropZone">Drag-and-drop upload area</label>
                    </div>
                    <div class="form-check form-switch" style="padding-bottom:12px">
                      <input class="form-check-input" type="checkbox" id="docPrefPromptOnDrop">
                      <label class="form-check-label" for="docPrefPromptOnDrop">Prompt for name &amp; category on drop</label>
                    </div>
                    <div class="form-check form-switch" style="padding-bottom:12px">
                      <input class="form-check-input" type="checkbox" id="docPrefDeleteEnabled">
                      <label class="form-check-label" for="docPrefDeleteEnabled">Delete button on documents</label>
                    </div>
                  </div>

                  <!-- Current User tab -->
                  <div class="tab-pane" id="prefTabProfile" style="min-height:490px">
                    <div id="prefProfileError" class="alert alert-danger d-none py-2 small mb-3"></div>
                    <div class="mb-3" style="padding-top:20px;padding-left:20px">
                      <div class="row align-items-center">
                        <div class="col-auto">
                          <input type="file" id="prefAvatarFile" accept="image/*" style="display:none">
                          <div id="prefAvatarPreview"
                            class="avatar avatar-xl rounded-circle bg-primary-lt"
                            style="cursor:pointer;width:72px;height:72px;overflow:hidden;display:flex;align-items:center;justify-content:center;font-size:1.5rem"
                            title="Click to change avatar">?</div>
                        </div>
                        <div class="col">
                          <div class="fw-semibold" id="prefAvatarName">—</div>
                          <div class="text-secondary small" id="prefAvatarEmail">—</div>
                          <div class="text-muted mt-1" style="font-size:.7rem">Click avatar to change</div>
                        </div>
                      </div>
                    </div>
                    <div class="mb-3" style="padding-top:20px;padding-left:20px">
                      <div class="row align-items-center mb-3">
                        <label class="col-3 col-form-label text-end">Display name</label>
                        <div class="col-9"><input type="text" class="form-control" id="prefDisplayName"></div>
                      </div>
                      <div class="row align-items-center mb-3">
                        <label class="col-3 col-form-label text-end">Email</label>
                        <div class="col-9"><input type="text" class="form-control" id="prefEmail" disabled></div>
                      </div>
                      <div class="row align-items-center">
                        <label class="col-3 col-form-label text-end">Job title</label>
                        <div class="col-9"><input type="text" class="form-control" id="prefJobTitle"></div>
                      </div>
                    </div>
                    <div style="padding-top:20px;padding-left:20px">
                      <div class="row align-items-center mb-3">
                        <label class="col-3 col-form-label text-end">Current password</label>
                        <div class="col-9">
                          <div class="input-group">
                            <input type="password" class="form-control" id="prefCurrentPassword" autocomplete="current-password" placeholder="Required to change password">
                            <button class="btn btn-outline-secondary pref-eye-btn" type="button" data-target="prefCurrentPassword" tabindex="-1"><i class="ti ti-eye"></i></button>
                          </div>
                        </div>
                      </div>
                      <div class="row align-items-center mb-3">
                        <label class="col-3 col-form-label text-end">New password</label>
                        <div class="col-9">
                          <div class="input-group">
                            <input type="password" class="form-control" id="prefNewPassword" autocomplete="new-password" placeholder="Leave blank to keep current">
                            <button class="btn btn-outline-secondary pref-eye-btn" type="button" data-target="prefNewPassword" tabindex="-1"><i class="ti ti-eye"></i></button>
                          </div>
                        </div>
                      </div>
                      <div class="row align-items-center">
                        <label class="col-3 col-form-label text-end">Confirm</label>
                        <div class="col-9">
                          <div class="input-group">
                            <input type="password" class="form-control" id="prefConfirmPassword" autocomplete="new-password">
                            <button class="btn btn-outline-secondary pref-eye-btn" type="button" data-target="prefConfirmPassword" tabindex="-1"><i class="ti ti-eye"></i></button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Audit tab (admin only) -->
                  <div class="tab-pane" id="prefTabAudit" style="min-height:490px;padding:20px">
                    <h4 class="mb-3">Audit Trail Settings</h4>

                    <!-- Include archived -->
                    <div class="mb-4">
                      <label class="form-check form-switch">
                        <input class="form-check-input" type="checkbox" id="prefIncludeArchived" />
                        <span class="form-check-label fw-semibold">Show archived records on Audit Trail page</span>
                      </label>
                      <p class="text-secondary small mt-1">When enabled, the Audit Trail page queries the archive table instead of the live table. An indicator will appear on the page. This may be slower on large datasets.</p>
                    </div>

                    <!-- Record counts -->
                    <div class="mb-4">
                      <h5 class="mb-2">Record Counts</h5>
                      <div id="prefAuditCounts" class="text-secondary small">
                        <span class="spinner-border spinner-border-sm me-1"></span>Loading…
                      </div>
                    </div>

                    <!-- Archive action -->
                    <div class="mb-3 border-top pt-3">
                      <h5 class="mb-1">Archive Old Records</h5>
                      <p class="text-secondary small mb-3">Move records older than the selected date to the archive table. This cannot be undone.</p>
                      <div class="row g-2 align-items-end mb-3">
                        <div class="col">
                          <label class="form-label mb-1 small">Archive records older than</label>
                          <input type="datetime-local" id="prefArchiveCutoff" class="form-control form-control-sm" />
                        </div>
                        <div class="col-auto">
                          <button class="btn btn-sm btn-outline-secondary" id="prefArchivePreview">Preview count</button>
                        </div>
                      </div>
                      <div id="prefArchivePreviewResult" class="small text-secondary mb-3" style="display:none"></div>
                      <button class="btn btn-sm btn-warning" id="prefArchiveRun" disabled>
                        <i class="ti ti-archive me-1"></i>Archive now
                      </button>
                      <div id="prefArchiveResult" class="small mt-2" style="display:none"></div>
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

    document.getElementById('prefAvatarPreview')?.addEventListener('click', () => {
      document.getElementById('prefAvatarFile')?.click();
    });
    document.getElementById('prefAvatarFile')?.addEventListener('change', function() {
      const file = this.files[0];
      if (!file) return;
      const url = URL.createObjectURL(file);
      const prev = document.getElementById('prefAvatarPreview');
      prev.innerHTML = `<img src="${url}" style="width:100%;height:100%;object-fit:cover">`;
    });

    // Eye toggle buttons
    modal.querySelectorAll('.pref-eye-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const input = document.getElementById(btn.dataset.target);
        if (!input) return;
        const show = input.type === 'password';
        input.type = show ? 'text' : 'password';
        btn.querySelector('i').className = show ? 'ti ti-eye-off' : 'ti ti-eye';
      });
    });
  }

  function _bindPreferences() {
    let preferencesModalInstance = null;
    let lastPreferencesSnapshot = null;
    let guardWired = false;

    const sidebarKey = _scopedKey('app_sidebar_bg');
    const accentKey  = _scopedKey('app_accent');
    const showFileTypeKey = _scopedKey('app_show_file_type_icon');

    function _snapshot() {
      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');
      const showFileTypeInput = document.getElementById('showFileTypeSwitch');
      return (sidebarInput?.value || '') + '|' + (accentInput?.value || '') + '|' + (showFileTypeInput?.checked ?? '');
    }

    function _populateProfile() {
      const profile = Auth.getProfile();
      const session = Auth.getSession();
      if (!profile && !session) return;

      const displayName = document.getElementById('prefDisplayName');
      const email       = document.getElementById('prefEmail');
      const jobTitle    = document.getElementById('prefJobTitle');
      const avatarPrev  = document.getElementById('prefAvatarPreview');
      const avatarName  = document.getElementById('prefAvatarName');
      const avatarEmail = document.getElementById('prefAvatarEmail');

      const nameVal  = profile?.display_name || '';
      const emailVal = session?.user?.email || profile?.email || '';

      if (displayName)  displayName.value  = nameVal;
      if (email)        email.value        = emailVal;
      if (jobTitle)     jobTitle.value     = profile?.job_title || '';
      if (avatarName)   avatarName.textContent  = nameVal  || '—';
      if (avatarEmail)  avatarEmail.textContent = emailVal || '—';

      if (avatarPrev) {
        if (profile?.avatar_url) {
          avatarPrev.innerHTML = `<img src="${profile.avatar_url}" style="width:100%;height:100%;object-fit:cover">`;
        } else {
          const initials = nameVal.split(' ').map(w => w[0]).filter(Boolean).join('').toUpperCase().slice(0, 2) || '?';
          avatarPrev.textContent = initials;
        }
      }

      // Clear file input so change event fires even if same file selected again
      const fileInput = document.getElementById('prefAvatarFile');
      if (fileInput) fileInput.value = '';
    }

    function _populateDocumentTab() {
      const docTabLi = document.getElementById('prefTabDocumentLi');
      if (!docTabLi) return;

      // Show Document tab only on the documents page
      if (typeof DOC_DEFAULT_FEATURES === 'undefined') return;
      docTabLi.style.display = '';

      // Read from saved prefs, falling back to DOC_DEFAULT_FEATURES
      const saved   = Auth.getPreference('docViewerPrefs', null) || {};
      const upload  = Object.assign({}, DOC_DEFAULT_FEATURES.upload,  saved.upload  || {});
      const del     = Object.assign({}, DOC_DEFAULT_FEATURES.delete,  saved.delete  || {});

      document.getElementById('docPrefUploadButton').checked  = upload.modalButton   !== false;
      document.getElementById('docPrefDropZone').checked      = upload.dropZone      !== false;
      document.getElementById('docPrefPromptOnDrop').checked  = upload.promptOnDrop  !== false;
      document.getElementById('docPrefDeleteEnabled').checked = del.enabled          !== false;
    }

    async function _populateAuditTab() {
      const auditTabLi = document.getElementById('prefTabAuditLi');
      if (!auditTabLi) return;
      if (!Auth.isAdmin()) return;
      auditTabLi.style.display = '';

      // Restore saved preference
      const savedInclude = Auth.getPreference('auditIncludeArchived', false);
      const toggle = document.getElementById('prefIncludeArchived');
      if (toggle) toggle.checked = !!savedInclude;

      // Set default cutoff to org retention months ago
      const cutoffEl = document.getElementById('prefArchiveCutoff');
      if (cutoffEl && !cutoffEl.value) {
        const d = new Date();
        const pad = n => String(n).padStart(2, '0');
        cutoffEl.value = d.getFullYear() + '-' + pad(d.getMonth()+1) + '-' + pad(d.getDate()) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
      }

      // Load counts
      const countsEl = document.getElementById('prefAuditCounts');
      if (countsEl) {
        countsEl.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Loading…';
        try {
          const orgId = Auth.getOrganisationId();
          const [liveRes, archiveRes] = await Promise.all([
            sb.from('audit_log').select('id', { count: 'exact', head: true }).eq('organisation_id', orgId),
            sb.from('audit_log_archive').select('id', { count: 'exact', head: true }).eq('organisation_id', orgId),
          ]);
          countsEl.innerHTML = '<table class="table table-sm">' +
            '<tr><td>Live audit records</td><td class="fw-semibold">' + (liveRes.count || 0).toLocaleString() + '</td></tr>' +
            '<tr><td>Archived audit records</td><td class="fw-semibold">' + (archiveRes.count || 0).toLocaleString() + '</td></tr>' +
            '</table>';
        } catch(e) {
          countsEl.innerHTML = '<span class="text-danger">Could not load counts</span>';
        }
      }

      // Preview button
      const previewBtn = document.getElementById('prefArchivePreview');
      const previewResult = document.getElementById('prefArchivePreviewResult');
      const archiveRunBtn = document.getElementById('prefArchiveRun');

      previewBtn?.addEventListener('click', async () => {
        const cutoff = document.getElementById('prefArchiveCutoff')?.value;
        if (!cutoff) { App.toast('Please select a date', 'warning'); return; }
        previewBtn.disabled = true;
        previewBtn.textContent = 'Counting…';
        const orgId = Auth.getOrganisationId();
        const { count } = await sb.from('audit_log')
          .select('id', { count: 'exact', head: true })
          .eq('organisation_id', orgId)
          .lte('created_at', cutoff + ':59');
        previewBtn.disabled = false;
        previewBtn.textContent = 'Preview count';
        previewResult.style.display = '';
        previewResult.innerHTML = '<i class="ti ti-info-circle me-1"></i><strong>' + (count || 0).toLocaleString() + '</strong> record' + (count !== 1 ? 's' : '') + ' would be archived.';
        archiveRunBtn.disabled = count === 0;
      });

      // Archive button
      const archiveResult = document.getElementById('prefArchiveResult');
      archiveRunBtn?.addEventListener('click', async () => {
        const cutoff = document.getElementById('prefArchiveCutoff')?.value;
        if (!cutoff) return;
        if (!await App.confirm({ title: 'Archive audit records?', message: 'This will move records older than ' + cutoff.replace('T', ' ') + ' to the archive. This cannot be undone.', confirmText: 'Archive', confirmClass: 'btn-warning' })) return;
        archiveRunBtn.disabled = true;
        archiveRunBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Archiving…';

        const { data, error } = await sb.rpc('archive_audit_log', { p_cutoff: new Date(cutoff + ':59').toISOString() });

        archiveRunBtn.disabled = false;
        archiveRunBtn.innerHTML = '<i class="ti ti-archive me-1"></i>Archive now';
        archiveResult.style.display = '';
        if (error) {
          archiveResult.className = 'small mt-2 text-danger';
          archiveResult.innerHTML = '<i class="ti ti-alert-circle me-1"></i>' + error.message;
        } else {
          const moved = data?.total_archived || 0;
          archiveResult.className = 'small mt-2 text-success';
          archiveResult.innerHTML = '<i class="ti ti-circle-check me-1"></i>' + moved.toLocaleString() + ' record' + (moved !== 1 ? 's' : '') + ' archived.';
          previewResult.style.display = 'none';
          await _populateAuditTab();
        }
      });
    }

    const openPreferences = e => {
      e?.preventDefault();
      const modalEl = document.getElementById('preferencesModal');
      if (!modalEl) return;

      const sidebarInput = document.getElementById('sidebarColourPicker');
      const accentInput  = document.getElementById('accentColourPicker');
      if (sidebarInput) sidebarInput.value = localStorage.getItem(sidebarKey) || '#182433';
      if (accentInput)  accentInput.value  = localStorage.getItem(accentKey)  || '#206bc4';

      const showFileTypeInput = document.getElementById('showFileTypeSwitch');
      if (showFileTypeInput) showFileTypeInput.checked = localStorage.getItem(showFileTypeKey) !== 'false';

      _populateProfile();
      _populateDocumentTab();
      _populateAuditTab();

      // Reset password fields and error
      ['prefNewPassword','prefConfirmPassword','prefCurrentPassword'].forEach(id => {
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

      // After the modal is visible, equalise all tab pane heights to the tallest one
      modalEl.addEventListener('shown.bs.modal', () => {
        const panes = modalEl.querySelectorAll('.tab-pane');
        // Temporarily show all panes to measure
        panes.forEach(p => { p.style.display = 'block'; p.style.visibility = 'hidden'; });
        const maxH = Math.max(...[...panes].map(p => p.scrollHeight));
        panes.forEach(p => { p.style.display = ''; p.style.visibility = ''; p.style.minHeight = maxH + 'px'; });
      }, { once: true });
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

      const showFileTypeInput = document.getElementById('showFileTypeSwitch');
      if (showFileTypeInput) {
        localStorage.setItem(showFileTypeKey, showFileTypeInput.checked ? 'true' : 'false');
        if (typeof renderDocList === 'function' && typeof filterDocs === 'function') {
          renderDocList(filterDocs());
        }
      }

      // Document viewer settings
      const uploadBtn = document.getElementById('docPrefUploadButton');
      if (uploadBtn !== null) {
        const saved = Auth.getPreference('docViewerPrefs', null) || {};
        const override = {
          upload: Object.assign({}, saved.upload, {
            modalButton:  document.getElementById('docPrefUploadButton').checked,
            dropZone:     document.getElementById('docPrefDropZone').checked,
            promptOnDrop: document.getElementById('docPrefPromptOnDrop').checked,
          }),
          delete: Object.assign({}, saved.delete, {
            enabled: document.getElementById('docPrefDeleteEnabled').checked,
          }),
        };
        await Auth.setPreference('docViewerPrefs', override);
        if (typeof loadDocFeatures === 'function') loadDocFeatures();
      }

      // Audit settings
      const auditToggle = document.getElementById('prefIncludeArchived');
      if (auditToggle !== null) {
        await Auth.setPreference('auditIncludeArchived', auditToggle.checked);
      }

      // Profile updates
      const session     = Auth.getSession();
      const profile     = Auth.getProfile();
      const displayName = document.getElementById('prefDisplayName')?.value.trim();
      const jobTitle    = document.getElementById('prefJobTitle')?.value.trim();
      const newPass     = document.getElementById('prefNewPassword')?.value;
      const confPass    = document.getElementById('prefConfirmPassword')?.value;
      const currPass    = document.getElementById('prefCurrentPassword')?.value;
      const avatarFile  = document.getElementById('prefAvatarFile')?.files[0];
      const userId      = session?.user?.id || profile?.id;

      if (!userId) { console.error('[Prefs] No user ID available'); }

      if (newPass || confPass || currPass) {
        if (!currPass) {
          if (errEl) { errEl.textContent = 'Please enter your current password.'; errEl.classList.remove('d-none'); }
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
        if (newPass !== confPass) {
          if (errEl) { errEl.textContent = 'New passwords do not match.'; errEl.classList.remove('d-none'); }
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
        if (!newPass) {
          if (errEl) { errEl.textContent = 'Please enter a new password.'; errEl.classList.remove('d-none'); }
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
        // Verify current password by re-signing in
        const { error: signErr } = await sb.auth.signInWithPassword({
          email: session?.user?.email || profile?.email,
          password: currPass,
        });
        if (signErr) {
          if (errEl) { errEl.textContent = 'Current password is incorrect.'; errEl.classList.remove('d-none'); }
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
        const { error: passErr } = await sb.auth.updateUser({ password: newPass });
        if (passErr) {
          if (errEl) { errEl.textContent = 'Password update failed: ' + passErr.message; errEl.classList.remove('d-none'); }
          document.querySelector('#prefTabs a[href="#prefTabProfile"]')?.click();
          return;
        }
        // Clear password fields and show success
        ['prefCurrentPassword','prefNewPassword','prefConfirmPassword'].forEach(id => {
          const el = document.getElementById(id); if (el) el.value = '';
        });
        App.toast('Password changed successfully');
      }

      if (userId) {
        const profileUpdate = {
          display_name: displayName || profile?.display_name,
          job_title:    jobTitle || null,
          updated_at:   new Date().toISOString(),
        };

        if (avatarFile) {
          const storagePath = `${userId}/avatar.png`;
          const fileData    = await avatarFile.arrayBuffer();
          const { error: upErr } = await sb.storage.from('user-avatars')
            .upload(storagePath, fileData, { contentType: avatarFile.type, upsert: true });
          if (upErr) {
            console.error('[Prefs] Avatar upload failed:', upErr.message);
          } else {
            const { data: { publicUrl } } = sb.storage.from('user-avatars').getPublicUrl(storagePath);
            profileUpdate.avatar_url = `${publicUrl}?t=${Date.now()}`;
          }
        }

        const { error: profErr } = await sb.from('profiles').update(profileUpdate).eq('id', userId);
        if (profErr) {
          console.error('[Prefs] Profile update failed:', profErr.message);
          if (errEl) { errEl.textContent = 'Save failed: ' + profErr.message; errEl.classList.remove('d-none'); return; }
        } else {
          // Update in-memory profile so avatar and name refresh immediately
          if (profile) {
            profile.display_name = profileUpdate.display_name;
            profile.job_title    = profileUpdate.job_title;
            if (profileUpdate.avatar_url) profile.avatar_url = profileUpdate.avatar_url;
          }
          Auth.refreshUI();
        }
      }

      // Persist dark mode
      const darkMode = document.getElementById('darkModeSwitch')?.checked;
      if (darkMode !== undefined) {
        localStorage.setItem('app_theme', darkMode ? 'dark' : 'light');
        document.documentElement.setAttribute('data-bs-theme', darkMode ? 'dark' : 'light');
      }

      lastPreferencesSnapshot = _snapshot();
      preferencesModalInstance?.hide();
      if (window.App) App.toast('Preferences saved');
    });
  }

  return { inject };
})();

window.SidebarHtml = SidebarHtml;
