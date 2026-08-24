/* ============================================================
   approveDoc - auth.js

   Fixed role model (do not extend without updating RLS policies
   that reference these role strings directly):
     super_admin - all organisations, ionetiq team only
     admin       - one organisation, includes admin functions
     user        - one organisation, editing capability
     view        - one organisation, read-only
   ============================================================ */

const Auth = (() => {
  let _session  = null;
  let _profile  = null;
  let _organisationId = null;     // the organisation currently in scope for this session
  let _allOrganisations = null;   // cached list of all organisations, used for the super-admin switcher

  async function requireAuth() {
    const saved = AppSession.load();
    if (!saved || !saved.access_token) { _redirectToLogin(); return null; }

    const { data, error } = await sb.auth.setSession({
      access_token:  saved.access_token,
      refresh_token: saved.refresh_token
    });

    if (error || !data.session) { AppSession.clear(); _redirectToLogin(); return null; }

    AppSession.save(data.session);
    _session = data.session;

    // Ensure the sb client uses the correct token for all subsequent queries.
    // On some domains/environments setSession doesn't propagate to the client's
    // internal query headers — explicitly set the auth header as a fallback.
    sb.realtime?.setAuth(data.session.access_token);
    const { createClient } = supabase;
    if (window._authenticatedSb) {
      // reuse existing authenticated client
    } else {
      window._authenticatedSb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: 'Bearer ' + data.session.access_token } },
        auth:   { persistSession: false, autoRefreshToken: false }
      });
      // Override sb queries to use authenticated client
      const origFrom = sb.from.bind(sb);
      sb.from = (table) => window._authenticatedSb.from(table);
    }

    _profile = await _loadProfile(_session.user.id);
    if (!_profile) {
      // No profile row exists for this authenticated user. Default to the
      // LEAST privileged role with no organisation access, never the most
      // privileged - a missing profile should never grant super admin.
      const name = _session.user.user_metadata?.full_name || _session.user.email.split('@')[0];
      _profile = { id: _session.user.id, display_name: name, role: 'view', organisation_id: null };
      console.warn('[Auth] No profile row found for this user - defaulting to least-privileged access. An admin should create a profile row for this account.');
    }

    await _resolveActiveOrganisation();

    _applyUserUI();
    return _session;
  }

  // Determines which single organisation is currently in scope.
  // Non-super-admins: always their fixed profile.organisation_id, no choice.
  // Super-admins: whichever organisation they last picked (stored in
  // localStorage, scoped to this deploy path), or the alphabetically-first
  // organisation if they've never picked one yet.
  async function _resolveActiveOrganisation() {
    if (!isSuperAdmin()) {
      _organisationId = _profile?.organisation_id || null;
      // Still need the organisation's name to display in the indicator,
      // even though it can't be changed - fetch just that one row.
      if (_organisationId) {
        const { data: org } = await sb.from('organisations').select('id, name').eq('id', _organisationId).maybeSingle();
        _allOrganisations = org ? [org] : [];
      } else {
        _allOrganisations = [];
      }
      return;
    }

    const { data: orgs } = await sb.from('organisations').select('id, name').order('name');
    _allOrganisations = orgs || [];

    const savedId = localStorage.getItem(_activeOrganisationKey());
    const savedIsValid = savedId && _allOrganisations.some(o => o.id === savedId);

    _organisationId = savedIsValid ? savedId : (_allOrganisations[0]?.id || null);

    if (_organisationId && _organisationId !== savedId) {
      localStorage.setItem(_activeOrganisationKey(), _organisationId);
    }
  }

  function _activeOrganisationKey() {
    try {
      const root = document.documentElement.dataset.appRoot || './';
      const absoluteRoot = new URL(root, window.location.href).pathname;
      // Use just the top-level app segment (e.g. 'approvedoc') so the key
      // is the same regardless of domain (ionetiq.dev vs approvedoc.app)
      // or environment (/dev/ vs /)
      return 'app_active_organisation:' + window.location.hostname + absoluteRoot;
    } catch (e) {
      return 'app_active_organisation';
    }
  }

  // Lets a super admin switch their active organisation. No-op for
  // non-super-admins, since their organisation is fixed. Returns true if
  // the switch took effect.
  async function setActiveOrganisation(organisationId) {
    if (!isSuperAdmin()) return false;
    if (!_allOrganisations) {
      const { data: orgs } = await sb.from('organisations').select('id, name').order('name');
      _allOrganisations = orgs || [];
    }
    if (!_allOrganisations.some(o => o.id === organisationId)) return false;

    _organisationId = organisationId;
    localStorage.setItem(_activeOrganisationKey(), organisationId);
    return true;
  }

  // Returns the list of all organisations (super admins only - used to
  // populate the organisation switcher). Empty array for non-super-admins.
  async function getAllOrganisations() {
    if (!isSuperAdmin()) return [];
    if (!_allOrganisations) {
      const { data: orgs } = await sb.from('organisations').select('id, name').order('name');
      _allOrganisations = orgs || [];
    }
    return _allOrganisations;
  }

  async function requireGuest() {
    const saved = AppSession.load();
    if (!saved || !saved.access_token) return;
    const { data } = await sb.auth.setSession({
      access_token:  saved.access_token,
      refresh_token: saved.refresh_token
    });
    if (data?.session) window.location.replace(_rootPath() + 'index.html');
    else AppSession.clear();
  }

  async function _loadProfile(userId) {
    // Get the access token directly from our session store
    const saved = AppSession.load();
    const token = saved?.access_token;

    if (!token) {
      console.warn('[Auth] _loadProfile - no access token available');
      return null;
    }

    // Pass the token explicitly in case sb client state isn't synced yet
    const { data, error } = await sb.from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (error) console.warn('[Auth] Profile load error:', error.message);
    if (data) return data;

    // If the client-level query returned nothing, try with explicit Authorization header
    console.warn('[Auth] Client query returned no profile - trying with explicit token');
    try {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=*`,
        {
          headers: {
            'apikey':        SUPABASE_ANON_KEY,
            'Authorization': 'Bearer ' + token,
            'Accept':        'application/vnd.pgrst.object+json',
          }
        }
      );
      if (res.ok) {
        const data2 = await res.json();
        console.log('[Auth] Explicit fetch profile result:', data2?.role);
        return data2 || null;
      } else {
        console.warn('[Auth] Explicit fetch failed:', res.status, await res.text());
      }
    } catch(e) {
      console.warn('[Auth] Explicit fetch error:', e.message);
    }
    return null;
  }

  function _applyUserUI() {
    if (!_session) return;
    const name      = _profile?.display_name || _session.user.email;
    const email     = _session.user.email;
    const role      = _profile?.role || 'view';
    const avatarUrl = _profile?.avatar_url || null;
    const words     = name.trim().split(/\s+/);
    const initials  = words.length >= 2
      ? (words[0][0] + words[words.length-1][0]).toUpperCase()
      : name.slice(0,2).toUpperCase();

    document.querySelectorAll('[data-user-initials]').forEach(el => {
      const safeAvatarUrl = avatarUrl && /^https?:\/\//.test(avatarUrl) ? avatarUrl : null;
      if (safeAvatarUrl) {
        const img = document.createElement('img');
        img.src = safeAvatarUrl;
        img.alt = initials;
        img.style.cssText = 'width:100%;height:100%;object-fit:cover;border-radius:50%';
        el.textContent = '';
        el.appendChild(img);
        _wireAvatarTooltip(el, safeAvatarUrl, name);
      } else {
        el.textContent = initials;
      }
    });
    document.querySelectorAll('[data-user-name]').forEach(el => el.textContent = name);
    document.querySelectorAll('[data-user-role]').forEach(el => el.textContent = _formatRole(role));
    document.querySelectorAll('[data-user-email]').forEach(el => el.textContent = email);

    // Reveal role-restricted elements
    if (['super_admin', 'admin'].includes(role)) {
      document.querySelectorAll('[data-require-role="admin"]').forEach(el => el.classList.remove('role-hidden'));
    }
    if (role === 'super_admin') {
      document.querySelectorAll('[data-require-role="super_admin"]').forEach(el => el.classList.remove('role-hidden'));
    }
    // "user" and above (i.e. not view-only) - controls editing capability
    if (['super_admin', 'admin', 'user'].includes(role)) {
      document.querySelectorAll('[data-require-role="user"]').forEach(el => el.classList.remove('role-hidden'));
    }
    // "user-only" - visible ONLY to user role, not admin/super_admin
    if (role === 'user') {
      document.querySelectorAll('[data-require-role="user-only"]').forEach(el => el.classList.remove('role-hidden'));
    }

    _renderOrganisationSwitcher();
  }

  // Renders the active-organisation name (and switcher, for super admins)
  // into any element marked with [data-active-organisation]. Non-super-admins
  // just see their fixed organisation name with no way to change it.
  function _renderOrganisationSwitcher() {
    const targets = document.querySelectorAll('[data-active-organisation]');
    if (!targets.length) return;

    const orgName = _allOrganisations?.find(o => o.id === _organisationId)?.name || '';

    targets.forEach(el => {
      if (!isSuperAdmin()) {
        el.innerHTML = orgName
          ? `<span class="org-switcher-label">${orgName}</span>`
          : `<span class="org-switcher-label org-switcher-warning"><i class="ti ti-alert-triangle me-1"></i>No organisation assigned</span>`;
        return;
      }

      const options = (_allOrganisations || []).map(o =>
        `<a class="dropdown-item${o.id === _organisationId ? ' active' : ''}" href="#" data-organisation-id="${o.id}">${o.name}</a>`
      ).join('');

      el.innerHTML = `
        <div class="dropdown">
          <button class="org-switcher-btn dropdown-toggle" data-bs-toggle="dropdown">
            <i class="ti ti-building"></i> <span>${orgName || 'Select organisation'}</span>
          </button>
          <div class="dropdown-menu">${options}</div>
        </div>`;
    });
  }

  document.addEventListener('click', async e => {
    const item = e.target.closest('[data-organisation-id]');
    if (item) {
      e.preventDefault();
      const ok = await setActiveOrganisation(item.dataset.organisationId);
      if (ok) window.location.reload();
    }
  });

  function _wireAvatarTooltip(el, avatarUrl, name) {
    let tooltip = null;

    el.addEventListener('mouseenter', () => {
      tooltip = document.createElement('div');
      tooltip.style.cssText = [
        'position:fixed',
        'z-index:9999',
        'background:#fff',
        'border-radius:12px',
        'box-shadow:0 8px 32px rgba(0,0,0,.22)',
        'padding:8px',
        'pointer-events:none',
        'transition:opacity .15s',
        'opacity:0',
      ].join(';');

      const img = document.createElement('img');
      img.src = avatarUrl;
      img.alt = name;
      img.style.cssText = 'width:120px;height:120px;object-fit:cover;border-radius:8px;display:block';
      tooltip.appendChild(img);

      const label = document.createElement('div');
      label.textContent = name;
      label.style.cssText = 'text-align:center;font-size:.8rem;font-weight:600;margin-top:6px;color:#374151';
      tooltip.appendChild(label);

      document.body.appendChild(tooltip);

      // Position tooltip - flip above if not enough room below, flip left if overflow right
      const rect = el.getBoundingClientRect();
      const tw = 136;
      const th = 160; // approx tooltip height (image + label + padding)

      let left = rect.right - tw;
      let top  = rect.bottom + 8;

      // Flip above if not enough room below
      if (top + th > window.innerHeight - 8) top = rect.top - th - 8;
      // Flip right-aligned if going off left edge
      if (left < 8) left = rect.left;
      // Clamp right edge
      if (left + tw > window.innerWidth - 8) left = window.innerWidth - tw - 8;
      // Clamp top edge
      if (top < 8) top = 8;
      tooltip.style.left = left + 'px';
      tooltip.style.top  = top  + 'px';

      // Fade in
      requestAnimationFrame(() => { tooltip.style.opacity = '1'; });
    });

    el.addEventListener('mouseleave', () => {
      if (tooltip) {
        tooltip.remove();
        tooltip = null;
      }
    });
  }

  function _formatRole(role) {
    const map = { super_admin: 'Super Admin', admin: 'Admin', user: 'User', view: 'View' };
    return map[role] || role;
  }

  function _redirectToLogin() {
    const root = window._appRootUrl || window._appRoot || './';
    window.location.replace(root + 'pages/auth/login.html');
  }

  function _rootPath() {
    return window._appRootUrl || window._appRoot || './';
  }

  async function signOut() {
    await sb.auth.signOut();
    AppSession.clear();
    _redirectToLogin();
  }

  function getSession()         { return _session; }
  function getProfile()         { return _profile; }
  function getOrganisationId()  { return _organisationId; }
  function isSuperAdmin()       { return _profile?.role === 'super_admin'; }
  function isAdmin()            { return ['super_admin', 'admin'].includes(_profile?.role); }
  function canEdit()            { return ['super_admin', 'admin', 'user'].includes(_profile?.role); }

  function getPreference(key, defaultVal) {
    const prefs = _profile?.preferences || {};
    return key in prefs ? prefs[key] : defaultVal;
  }

  async function setPreference(key, value) {
    if (!_profile) return;
    const prefs = { ...(_profile.preferences || {}), [key]: value };
    _profile.preferences = prefs;
    await sb.from('profiles').update({ preferences: prefs }).eq('id', _profile.id);
  }

  // Returns the currently-active organisation as a single-item array, for
  // compatibility with query code that does .in('organisation_id', ids).
  // Every user - super admin or not - operates within exactly one active
  // organisation at a time, so this is just [_organisationId] or [].
  async function getAccessibleOrganisationIds() {
    return _organisationId ? [_organisationId] : [];
  }

  document.addEventListener('click', e => {
    if (e.target.closest('[data-action="signout"]')) {
      e.preventDefault();
      signOut();
    }
  });

  return {
    requireAuth, requireGuest, signOut,
    getSession, getProfile, getOrganisationId,
    isSuperAdmin, isAdmin, canEdit, getAccessibleOrganisationIds,
    setActiveOrganisation, getAllOrganisations,
    getPreference, setPreference,
    // Re-runs the role-based [data-require-role] reveal and the user
    // name/initials/role text fill-in. requireAuth() already calls this
    // once internally, but at that point the sidebar/header markup
    // hasn't been injected into the page yet (SidebarHtml.inject() runs
    // AFTER requireAuth() returns, in every page's own inline script) -
    // so every page must call this again, explicitly, once injection has
    // actually happened, or role-gated nav items never get revealed.
    refreshUI: _applyUserUI
  };
})();

window.Auth = Auth;
