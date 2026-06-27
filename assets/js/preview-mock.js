/* ============================================================
   PREVIEW BUILD ONLY - not part of the real template.

   Replaces real Supabase auth with a fake signed-in session so
   every page can be opened directly in a browser with no backend,
   for visual review purposes only. Must load BEFORE auth.js and
   supabase-client.js are referenced by each page, and effectively
   replaces both.
   ============================================================ */

window.sb = {
  auth: {
    setSession: async () => ({ data: { session: { user: { id: 'preview', email: 'jane@acme.co.uk' } } }, error: null }),
    signOut: async () => ({}),
    signInWithPassword: async () => ({ data: { session: null }, error: { message: 'Preview mode - sign in is disabled.' } }),
    resetPasswordForEmail: async () => ({ error: null }),
    updateUser: async () => ({ error: null })
  },
  from(table) {
    const PREVIEW_ORGS = [
      { id: 'org-1', name: 'Acme Corporation', reference: 'ACME', contact_name: 'Jane Whitfield', contact_email: 'jane@acme.co.uk', description: 'Main UK holding company', active: true },
      { id: 'org-2', name: 'Blackwood Logistics', reference: 'BLKW', contact_name: null, contact_email: null, description: null, active: true },
      { id: 'org-3', name: 'Sutherland Manufacturing', reference: null, contact_name: 'Tom Reilly', contact_email: 'tom@sutherland.co.uk', description: null, active: false }
    ];
    const PREVIEW_USERS = [
      { id: 'u1', display_name: 'Maya Rodriguez', email: 'm.rodriguez@acme.co.uk', role: 'super_admin', job_title: 'Operations Manager', organisation_id: null, avatar_url: null },
      { id: 'u2', display_name: 'Tom Reilly', email: 'tom@acme.co.uk', role: 'admin', job_title: null, organisation_id: 'org-1', avatar_url: null },
      { id: 'u3', display_name: 'Jane Whitfield', email: 'jane@acme.co.uk', role: 'user', job_title: null, organisation_id: 'org-1', avatar_url: null },
      { id: 'u4', display_name: 'Sam Hu', email: 'sam@acme.co.uk', role: 'view', job_title: null, organisation_id: 'org-1', avatar_url: null }
    ];
    const data = table === 'organisations' ? PREVIEW_ORGS : table === 'profiles' ? PREVIEW_USERS : [];

    const builder = {
      select() { return builder; },
      order() { return Promise.resolve({ data, error: null }); },
      eq(col, val) {
        const row = data.find(r => r[col] === val) || null;
        return {
          maybeSingle: async () => ({ data: row, error: null }),
          single: async () => ({ data: row, error: null }),
          then: (res) => res({ data: row ? [row] : [], error: null })
        };
      },
      maybeSingle() { return Promise.resolve({ data: data[0] || null, error: null }); },
      update() {
        // Preview mode - accept the write but don't persist it anywhere
        // real, then resolve like a successful Supabase call would.
        return { eq: async () => ({ error: null }) };
      },
      insert: async () => ({ error: null }),
      delete() { return { eq: async () => ({ error: null }) }; },
      then(resolve) { return resolve({ data, error: null }); }
    };
    return builder;
  },
  storage: { from: () => ({ upload: async () => ({ error: null }), getPublicUrl: () => ({ data: { publicUrl: '' } }) }) }
};

window.AppSession = {
  save() {}, clear() {},
  load() { return { access_token: 'preview-token', refresh_token: 'preview-refresh' }; }
};

window.Auth = {
  requireAuth: async () => ({ user: { id: 'preview', email: 'jane@acme.co.uk' } }),
  requireGuest: async () => {},
  signOut: async () => { window.location.reload(); },
  getSession: () => ({ user: { id: 'preview', email: 'jane@acme.co.uk' } }),
  getProfile: () => ({ id: 'preview', display_name: 'Jane Whitfield', role: 'super_admin', organisation_id: 'org-1', preferences: {} }),
  getOrganisationId: () => 'org-1',
  isSuperAdmin: () => true,
  isAdmin: () => true,
  canEdit: () => true,
  getAccessibleOrganisationIds: async () => ['org-1'],
  setActiveOrganisation: async () => true,
  getAllOrganisations: async () => [
    { id: 'org-1', name: 'Acme Corporation' },
    { id: 'org-2', name: 'Blackwood Logistics' },
    { id: 'org-3', name: 'Sutherland Manufacturing' }
  ],
  getPreference: (key, def) => def,
  setPreference: async () => {}
};

document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('[data-user-initials]').forEach(el => el.textContent = 'JW');
  document.querySelectorAll('[data-user-name]').forEach(el => el.textContent = 'Jane Whitfield (preview)');
  document.querySelectorAll('[data-user-email]').forEach(el => el.textContent = 'jane@acme.co.uk');
  document.querySelectorAll('[data-user-role]').forEach(el => el.textContent = 'Super Admin');
  document.querySelectorAll('[data-require-role]').forEach(el => el.classList.remove('role-hidden'));
});
