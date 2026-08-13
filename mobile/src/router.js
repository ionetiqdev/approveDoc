/* ============================================================
   approveDoc mobile - router.js

   v1: minimal function-based screen switcher (no history stack,
   no native back-button wiring yet). Fine for the current 8-screen
   flow, but flagged in the ADR follow-up discussion as something
   that may need ion-router or a proper nav stack once gestures
   and Android hardware back button need to match native behaviour.
   ============================================================ */

const screens = new Map();
let currentUnmount = null;

export function registerScreen(name, mountFn) {
  screens.set(name, mountFn);
}

export async function showScreen(name, params = {}) {
  const mountFn = screens.get(name);
  if (!mountFn) throw new Error(`router: unknown screen "${name}"`);

  const app = document.getElementById('app');

  if (typeof currentUnmount === 'function') {
    currentUnmount();
    currentUnmount = null;
  }

  app.innerHTML = '';
  const result = await mountFn(app, params);
  if (typeof result === 'function') currentUnmount = result;
}
