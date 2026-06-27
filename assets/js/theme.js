/* ============================================================
   approveDoc - theme.js
   Dark/light mode toggle + accent colour picker

   IMPORTANT: this sets Tabler's own theming hooks directly -
   data-bs-theme="dark"|"light" on <html> (Bootstrap 5.3's native
   colour-mode attribute, which Tabler's dark-mode CSS is built on)
   and the --tblr-primary / --tblr-primary-rgb custom properties
   (Tabler's actual accent-colour variables). This is NOT the same
   mechanism Risk used (a custom data-theme attribute and a
   custom --accent variable that only worked because Risk's
   hand-rolled CSS specifically read them) - Risk's approach will
   NOT work against real Tabler, which has no idea what --accent
   means. --tblr-primary-rgb must be kept in sync with
   --tblr-primary because various Tabler utility classes (focus
   shadows etc.) read the RGB triplet directly rather than the hex.
   ============================================================ */

const Theme = (() => {
  const STORAGE_THEME  = 'app_theme';
  const STORAGE_ACCENT = 'app_accent';
  const DEFAULT_ACCENT = '#206bc4'; // Tabler's own default --tblr-primary

  // Scope storage keys to the current deploy's root path (e.g. /{project}/
  // vs /{project}/dev/), so display preferences like accent colour can
  // differ between branches sharing the same domain. Reads the app root
  // from a data-app-root attribute set directly on <html> by each page, so
  // this works immediately with no dependency on sidebar injection timing.
  function _scopedKey(baseKey) {
    try {
      const root = document.documentElement.dataset.appRoot || './';
      const absoluteRoot = new URL(root, window.location.href).pathname;
      return baseKey + ':' + absoluteRoot;
    } catch (e) {
      return baseKey;
    }
  }

  function init() {
    const accentKey = _scopedKey(STORAGE_ACCENT);
    const sidebarBgKey = _scopedKey('app_sidebar_bg');
    const saved = localStorage.getItem(STORAGE_THEME);
    const preferred = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    _apply(saved || preferred);
    _applyAccent(localStorage.getItem(accentKey) || DEFAULT_ACCENT);

    try {
      const savedSidebarBg = localStorage.getItem(sidebarBgKey);
      if (savedSidebarBg && typeof window._applySidebarColours === 'function') {
        window._applySidebarColours(savedSidebarBg);
      }
    } catch (e) {}

    document.querySelectorAll('[data-theme-toggle]').forEach(btn => {
      btn.addEventListener('click', toggle);
    });

    const accentInput = document.getElementById('accentColourPicker');
    if (accentInput) {
      accentInput.value = localStorage.getItem(accentKey) || DEFAULT_ACCENT;
      accentInput.addEventListener('input', e => _applyAccent(e.target.value));
      accentInput.addEventListener('change', e => {
        localStorage.setItem(accentKey, e.target.value);
      });
    }
  }

  function toggle() {
    const current = document.documentElement.getAttribute('data-bs-theme') || 'light';
    const next = current === 'dark' ? 'light' : 'dark';
    _apply(next);
    localStorage.setItem(STORAGE_THEME, next);
  }

  function _apply(theme) {
    document.documentElement.setAttribute('data-bs-theme', theme);
    document.querySelectorAll('[data-theme-toggle]').forEach(btn => {
      const icon = btn.querySelector('i');
      if (icon) {
        icon.className = theme === 'dark' ? 'ti ti-sun' : 'ti ti-moon';
      }
    });
  }

  function _applyAccent(colour) {
    document.documentElement.style.setProperty('--tblr-primary', colour);
    document.documentElement.style.setProperty('--tblr-primary-rgb', _hexToRgbTriplet(colour));
  }

  function _hexToRgbTriplet(hex) {
    let c = hex.replace('#','');
    if (c.length === 3) c = c.split('').map(x=>x+x).join('');
    const r = parseInt(c.slice(0,2),16);
    const g = parseInt(c.slice(2,4),16);
    const b = parseInt(c.slice(4,6),16);
    return `${r}, ${g}, ${b}`;
  }

  return { init, toggle, setAccent: _applyAccent };
})();

document.addEventListener('DOMContentLoaded', () => Theme.init());
window.Theme = Theme;
