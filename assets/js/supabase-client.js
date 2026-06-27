/* ============================================================
   approveDoc - supabase-client.js

   NOTE FOR NEW PROJECTS: the two constants below are placeholders.
   They get substituted for real values by the project-creation
   process (see /docs/NEW-PROJECT.md) - this file should never be
   hand-edited per-project; it stays identical to the template
   except for these two lines.
   ============================================================ */

const SUPABASE_URL      = '{{SUPABASE_URL}}';
const SUPABASE_ANON_KEY = '{{SUPABASE_ANON_KEY}}';

const { createClient } = supabase;

const SESSION_KEY = 'app_session';

/* Storage adapter - plain key name avoids browser-extension pattern matching */
const _store = {
  getItem(key)        { try { return localStorage.getItem(key); }        catch(e) { return null; } },
  setItem(key, value) { try { localStorage.setItem(key, value); }        catch(e) {} },
  removeItem(key)     { try { localStorage.removeItem(key); }            catch(e) {} }
};

window.sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storageKey:         SESSION_KEY,
    persistSession:     true,
    autoRefreshToken:   true,
    detectSessionInUrl: false,
    storage:            _store
  }
});

/* AppSession - reads/writes using Supabase's own storage format
   so the client can find and use the session correctly for API calls */
window.AppSession = {
  save(session) {
    /* Supabase v2 stores sessions as JSON under the storageKey directly */
    try {
      const val = JSON.stringify({
        access_token:  session.access_token,
        token_type:    'bearer',
        expires_in:    session.expires_in || 3600,
        expires_at:    session.expires_at,
        refresh_token: session.refresh_token,
        user:          session.user
      });
      localStorage.setItem(SESSION_KEY, val);
    } catch(e) {}
  },
  load() {
    try {
      const raw = localStorage.getItem(SESSION_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch(e) { return null; }
  },
  clear() {
    try { localStorage.removeItem(SESSION_KEY); } catch(e) {}
  }
};
