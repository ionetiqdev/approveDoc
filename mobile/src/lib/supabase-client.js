/* ============================================================
   approveDoc mobile - supabase-client.js

   NOTE: mirrors assets/js/supabase-client.js from the web app,
   but sourced differently. The web app's placeholders get
   substituted by GitHub Actions at deploy time - that only works
   for the built/deployed artifact, not for local `npm run dev`
   (nothing substitutes anything on your machine, so the literal
   string "{{SUPABASE_URL}}" would reach createClient() and throw
   immediately). Mobile instead uses Vite's built-in env var
   support, loaded from .env.local (gitignored, never committed -
   see .env.example for the format).

   Decision (ADR-mobile-app-capacitor.md, section 6):
   Session storage uses @capacitor/preferences (Keychain on iOS,
   Keystore on Android) instead of localStorage, so sessions
   survive app updates and are encrypted at rest.
   ============================================================ */

import { createClient } from '@supabase/supabase-js';
import { Preferences } from '@capacitor/preferences';

const SUPABASE_URL      = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error(
    'Missing Supabase credentials. Copy mobile/.env.example to mobile/.env.local ' +
    'and fill in VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY (see README.md).'
  );
}

const SESSION_KEY = 'app_session';
const BIOMETRIC_ENABLED_KEY = 'biometric_enabled';

/* Storage adapter backed by Capacitor Preferences (async, matches
   Supabase v2's supported async storage interface) */
const _store = {
  async getItem(key) {
    const { value } = await Preferences.get({ key });
    return value ?? null;
  },
  async setItem(key, value) {
    await Preferences.set({ key, value });
  },
  async removeItem(key) {
    await Preferences.remove({ key });
  }
};

export const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storageKey:         SESSION_KEY,
    persistSession:     true,
    autoRefreshToken:   true,
    detectSessionInUrl: false,
    storage:            _store
  }
});

/* ============================================================
   Session + biometric helpers

   Drives the launch logic from ADR section 7:
   - valid session + biometric enabled  -> unlock screen
   - anything else                      -> sign-in screen
   ============================================================ */

export async function hasStoredSession() {
  const { data } = await sb.auth.getSession();
  return !!data.session;
}

export async function isBiometricEnabled() {
  const { value } = await Preferences.get({ key: BIOMETRIC_ENABLED_KEY });
  return value === 'true';
}

export async function setBiometricEnabled(enabled) {
  await Preferences.set({ key: BIOMETRIC_ENABLED_KEY, value: enabled ? 'true' : 'false' });
}

/* Decides which auth screen to show on launch. See screens/router.js. */
export async function resolveLaunchScreen() {
  const [session, biometric] = await Promise.all([hasStoredSession(), isBiometricEnabled()]);
  if (session && biometric) return 'unlock';
  return 'signin';
}
