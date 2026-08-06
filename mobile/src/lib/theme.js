/* ============================================================
   approveDoc mobile - theme.js

   Decision (ADR-mobile-app-capacitor.md, section 9):
   - App has its own light/dark setting, independent of the OS.
   - First install: follow system theme if it can be detected,
     otherwise fall back to light.
   - Once the person picks a theme explicitly in Profile, that
     choice persists and the app stops following system changes.
   ============================================================ */

import { Preferences } from '@capacitor/preferences';

const THEME_KEY = 'app_theme'; // 'light' | 'dark' | undefined (not yet set)

function systemPrefersDark() {
  try {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  } catch (e) {
    return null; // could not detect
  }
}

function applyTheme(mode) {
  document.documentElement.setAttribute('data-theme', mode);
}

export async function initTheme() {
  const { value } = await Preferences.get({ key: THEME_KEY });

  if (value === 'light' || value === 'dark') {
    applyTheme(value);
    return value;
  }

  // No explicit choice stored yet - follow system, fall back to light.
  const systemDark = systemPrefersDark();
  const initial = systemDark === true ? 'dark' : 'light';
  applyTheme(initial);
  return initial;
}

export async function setTheme(mode) {
  if (mode !== 'light' && mode !== 'dark') throw new Error('setTheme: mode must be "light" or "dark"');
  await Preferences.set({ key: THEME_KEY, value: mode });
  applyTheme(mode);
}

export async function getTheme() {
  const { value } = await Preferences.get({ key: THEME_KEY });
  return value === 'light' || value === 'dark' ? value : null;
}
