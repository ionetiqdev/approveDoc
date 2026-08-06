import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';
import { getTheme, setTheme } from '../lib/theme.js';

/* TODO: identity block (name/title/manager, read-only), notification
   toggles, biometric toggle (placeholder ahead of the feature),
   change password, app version. Theme control wired below as the
   one piece already fully decided (ADR section 9). */
export async function mount(app) {
  const theme = await getTheme();

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;padding:16px;">
      <button id="back" style="align-self:flex-start;border:none;background:none;padding:4px;margin-bottom:16px;">&larr;</button>
      <h2 style="margin:0 0 16px;">Profile</h2>

      <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--border);">
        <span style="font-size:14px;">Theme</span>
        <select id="theme-select" style="padding:6px;border-radius:6px;border:1px solid var(--border);background:var(--bg-1);color:var(--text-primary);">
          <option value="light" ${theme === 'light' ? 'selected' : ''}>Light</option>
          <option value="dark" ${theme === 'dark' ? 'selected' : ''}>Dark</option>
        </select>
      </div>

      <p style="font-size:13px;color:var(--text-secondary);margin-top:16px;">TODO: notifications, biometric toggle, change password, sign out, app version.</p>

      <button id="sign-out" style="margin-top:auto;width:100%;padding:12px;font-size:14px;border:1px solid var(--danger);border-radius:8px;background:transparent;color:var(--danger);">
        Sign out
      </button>
    </div>
  `;

  app.querySelector('#back').addEventListener('click', () => showScreen('dashboard'));
  app.querySelector('#theme-select').addEventListener('change', (e) => setTheme(e.target.value));
  app.querySelector('#sign-out').addEventListener('click', async () => {
    await sb.auth.signOut();
    showScreen('signin');
  });
}
