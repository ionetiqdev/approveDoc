// ════════════════════════════════════════════════════════════════════
// Profile modal - shared across every page (loaded via the same
// <script> chain as sidebar-html.js/app.js, not page-specific).
//
// This is a self-edit-only version of the Edit User modal that
// already exists on the admin Users page - it reuses the same
// general shape (avatar upload, display name, job title, password
// change) but role and email are always locked, since this is the
// "edit yourself" entry point reachable by every role from the
// header dropdown, not the admin "edit anyone" modal.
// ════════════════════════════════════════════════════════════════════

const ProfileModal = (() => {
  let modalInstance = null;
  let avatarFile = null;
  let avatarRemoved = false;

  const AVATAR_COLOURS = ['#206bc4','#7c3aed','#db2777','#ea580c','#16a34a','#0891b2','#9333ea','#dc2626'];

  function _inject() {
    if (document.getElementById('profileModal')) return;
    const modal = document.createElement('div');
    modal.className = 'modal modal-blur fade';
    modal.id = 'profileModal';
    modal.tabIndex = -1;
    modal.innerHTML = `
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">My Profile</h5>
            <button type="button" class="modal-close-btn" data-bs-dismiss="modal" aria-label="Close"><i class="ti ti-x"></i></button>
          </div>
          <div class="modal-body">
            <div id="profileModalError" class="alert alert-danger d-none py-2 small mb-3"></div>

            <div class="avatar-upload-wrap">
              <div class="avatar-preview" id="profileAvatarPreview" onclick="document.getElementById('profileAvatarFileInput').click()">
                <span id="profileAvatarInitials">?</span>
                <div class="avatar-overlay"><i class="ti ti-camera"></i></div>
              </div>
              <input type="file" id="profileAvatarFileInput" accept="image/*" />
              <div>
                <div class="fw-semibold small mb-1">Profile photo</div>
                <div class="text-secondary small">Click the avatar to upload. JPG, PNG or GIF, max 2MB.</div>
                <button type="button" class="btn btn-sm btn-outline-secondary mt-2" id="profileRemoveAvatarBtn" style="display:none">
                  <i class="ti ti-trash me-1"></i>Remove photo
                </button>
              </div>
            </div>

            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Display name <span class="text-danger">*</span></label>
                <input type="text" id="profileDisplayName" class="form-control" placeholder="Full name" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Email address</label>
                <input type="email" id="profileEmail" class="form-control" disabled />
                <div class="form-text">Contact an administrator to change your email.</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Role</label>
                <input type="text" id="profileRoleDisplay" class="form-control" disabled />
                <div class="form-text">Contact an administrator to change your role.</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Job title</label>
                <input type="text" id="profileJobTitle" class="form-control" placeholder="e.g. Operations Manager" />
              </div>

              <div class="col-12">
                <hr class="my-2" />
                <label class="form-label">Change password</label>
                <div class="row g-2">
                  <div class="col-md-6">
                    <div class="position-relative">
                      <input type="password" id="profilePassword" class="form-control" placeholder="New password" autocomplete="new-password" />
                      <button type="button" class="pw-toggle-btn" data-toggle-pw="profilePassword"><i class="ti ti-eye"></i></button>
                    </div>
                  </div>
                  <div class="col-md-6">
                    <div class="position-relative">
                      <input type="password" id="profilePasswordConfirm" class="form-control" placeholder="Confirm password" autocomplete="new-password" />
                      <button type="button" class="pw-toggle-btn" data-toggle-pw="profilePasswordConfirm"><i class="ti ti-eye"></i></button>
                    </div>
                  </div>
                </div>
                <div class="form-text">Leave blank to keep your current password.</div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn" data-bs-dismiss="modal">Cancel</button>
            <button type="button" class="btn btn-primary" id="profileSaveBtn">
              <span id="profileSaveLabel">Save changes</span>
              <span id="profileSaveSpinner" class="spinner-border spinner-border-sm ms-2 d-none"></span>
            </button>
          </div>
        </div>
      </div>`;
    document.body.appendChild(modal);
  }

  function _bind() {
    document.getElementById('profileSaveBtn').addEventListener('click', _save);
    document.getElementById('profileModal').addEventListener('hidden.bs.modal', _reset);

    document.getElementById('profileAvatarFileInput').addEventListener('change', e => {
      const file = e.target.files[0];
      if (!file) return;
      if (file.size > 2 * 1024 * 1024) { App.toast('Image must be under 2MB', 'warning'); return; }
      avatarFile = file;
      const reader = new FileReader();
      reader.onload = ev => {
        _setAvatarPreviewImage(ev.target.result);
        document.getElementById('profileRemoveAvatarBtn').style.display = '';
      };
      reader.readAsDataURL(file);
    });

    document.getElementById('profileRemoveAvatarBtn').addEventListener('click', () => {
      avatarFile = null;
      avatarRemoved = true;
      document.getElementById('profileRemoveAvatarBtn').style.display = 'none';
      _setAvatarPreviewInitials(document.getElementById('profileDisplayName').value);
    });

    document.getElementById('profileDisplayName').addEventListener('input', e => {
      if (!avatarFile && !document.querySelector('#profileAvatarPreview img')) {
        _setAvatarPreviewInitials(e.target.value);
      }
    });

    document.querySelectorAll('[data-toggle-pw]').forEach(btn => {
      btn.addEventListener('click', () => {
        const inp = document.getElementById(btn.dataset.togglePw);
        const icon = btn.querySelector('i');
        inp.type = inp.type === 'password' ? 'text' : 'password';
        icon.className = inp.type === 'password' ? 'ti ti-eye' : 'ti ti-eye-off';
      });
    });
  }

  function open() {
    _inject();
    if (!document.getElementById('profileSaveBtn').dataset.bound) {
      _bind();
      document.getElementById('profileSaveBtn').dataset.bound = '1';
    }

    const profile = Auth.getProfile();
    if (!profile) return;

    avatarFile = null;
    avatarRemoved = false;

    document.getElementById('profileDisplayName').value = profile.display_name || '';
    document.getElementById('profileEmail').value        = Auth.getSession()?.user?.email || '';
    document.getElementById('profileRoleDisplay').value  = _formatRole(profile.role);
    document.getElementById('profileJobTitle').value     = profile.job_title || '';
    document.getElementById('profilePassword').value     = '';
    document.getElementById('profilePasswordConfirm').value = '';

    if (profile.avatar_url) {
      _setAvatarPreviewImage(profile.avatar_url);
      document.getElementById('profileRemoveAvatarBtn').style.display = '';
    } else {
      _setAvatarPreviewInitials(profile.display_name);
    }

    modalInstance = bootstrap.Modal.getOrCreateInstance(document.getElementById('profileModal'));
    modalInstance.show();
  }

  function _reset() {
    document.getElementById('profileModalError').classList.add('d-none');
    avatarFile = null;
    avatarRemoved = false;
  }

  async function _save() {
    const errorEl = document.getElementById('profileModalError');
    errorEl.classList.add('d-none');

    const profile = Auth.getProfile();
    if (!profile) return;

    const name        = document.getElementById('profileDisplayName').value.trim();
    const jobTitle    = document.getElementById('profileJobTitle').value.trim();
    const password    = document.getElementById('profilePassword').value;
    const passwordCfm = document.getElementById('profilePasswordConfirm').value;

    const errors = [];
    if (!name) errors.push('Display name is required.');
    if (password && password.length < 8) errors.push('Password must be at least 8 characters.');
    if (password && password !== passwordCfm) errors.push('Passwords do not match.');

    if (errors.length) {
      errorEl.textContent = errors.join(' ');
      errorEl.classList.remove('d-none');
      return;
    }

    document.getElementById('profileSaveLabel').textContent = 'Saving…';
    document.getElementById('profileSaveSpinner').classList.remove('d-none');
    document.getElementById('profileSaveBtn').disabled = true;

    try {
      let avatarUrl = avatarRemoved ? null : (profile.avatar_url || null);
      if (avatarFile) avatarUrl = await _uploadAvatar(profile.id, avatarFile);

      // Deliberately NOT including role or organisation_id here at
      // all - this is the self-edit path, those two fields are
      // locked in the UI and excluded from the payload entirely
      // rather than relying on the disabled inputs to "not really"
      // change anything. RLS also independently enforces that a
      // user can never change their own role/organisation_id (see
      // "Users: update own profile only" policy in
      // 01-core-schema.sql) - this is belt-and-braces, not the only
      // protection.
      const { error } = await sb.from('profiles').update({
        display_name: name,
        job_title:    jobTitle || null,
        avatar_url:   avatarUrl,
        updated_at:   new Date().toISOString()
      }).eq('id', profile.id);
      if (error) throw error;

      if (password) {
        const res = await _callEdgeFunction({ action: 'update_password', user_id: profile.id, password });
        if (res.error) throw new Error(res.error);
      }

      // Update the in-memory profile so the header avatar/name reflect
      // the change immediately, without needing a full page reload.
      profile.display_name = name;
      profile.job_title     = jobTitle || null;
      profile.avatar_url    = avatarUrl;
      Auth.refreshUI();

      modalInstance.hide();
      App.toast('Profile updated');

    } catch (err) {
      errorEl.textContent = 'Save failed: ' + (err.message || 'Unknown error');
      errorEl.classList.remove('d-none');
    } finally {
      document.getElementById('profileSaveLabel').textContent = 'Save changes';
      document.getElementById('profileSaveSpinner').classList.add('d-none');
      document.getElementById('profileSaveBtn').disabled = false;
    }
  }

  async function _uploadAvatar(userId, file) {
    const ext  = file.name.split('.').pop();
    const path = `${userId}/avatar.${ext}`;
    const { error } = await sb.storage.from('user-avatars').upload(path, file, { upsert: true });
    if (error) { console.warn('Avatar upload failed:', error.message); return null; }
    const { data } = sb.storage.from('user-avatars').getPublicUrl(path);
    return data.publicUrl + '?t=' + Date.now();
  }

  async function _callEdgeFunction(body) {
    const saved = AppSession.load();
    const token = saved?.access_token;
    if (!token) throw new Error('No session token available');

    const res = await fetch(SUPABASE_URL + '/functions/v1/manage-user', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'apikey': SUPABASE_ANON_KEY },
      body: JSON.stringify(body)
    });
    return await res.json();
  }

  function _setAvatarPreviewImage(src) {
    const preview = document.getElementById('profileAvatarPreview');
    preview.innerHTML = `<img src="${src}" alt="avatar" /><div class="avatar-overlay"><i class="ti ti-camera"></i></div>`;
    preview.style.background = '';
  }

  function _setAvatarPreviewInitials(name) {
    const preview  = document.getElementById('profileAvatarPreview');
    const initials = _initials(name);
    preview.style.background = _avatarColour(name);
    preview.innerHTML = `<span style="color:#fff;font-size:1.25rem;font-weight:500">${initials}</span><div class="avatar-overlay"><i class="ti ti-camera"></i></div>`;
  }

  function _initials(name) {
    if (!name) return '?';
    const words = name.trim().split(/\s+/);
    return words.length >= 2 ? (words[0][0] + words[words.length-1][0]).toUpperCase() : name.slice(0,2).toUpperCase();
  }

  function _avatarColour(name) {
    let hash = 0;
    for (let i = 0; i < (name||'').length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
    return AVATAR_COLOURS[Math.abs(hash) % AVATAR_COLOURS.length];
  }

  function _formatRole(role) {
    const map = { super_admin: 'Super Admin', admin: 'Admin', user: 'User', view: 'View' };
    return map[role] || role || '';
  }

  return { open };
})();

window.ProfileModal = ProfileModal;
