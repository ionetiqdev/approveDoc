import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';

/* TODO: wire an actual biometric plugin (e.g. @capgo/capacitor-native-biometric).
   Not chosen yet - see ADR section 10 (deferred to v1.1+, UI designed now).
   Today this just re-confirms the existing Supabase session is valid and
   proceeds - it does not touch Face ID / fingerprint hardware. */
export async function mount(app) {
  const { data: { user } } = await sb.auth.getUser();
  const firstName = user?.user_metadata?.first_name || 'there';

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;justify-content:center;align-items:center;padding:0 24px;text-align:center;">
      <h1 style="margin:0 0 2px;font-size:20px;">Welcome back, ${firstName}</h1>
      <p style="font-size:13px;color:var(--text-secondary);margin:0 0 32px;">Tap to unlock</p>
      <button id="unlock-btn" style="width:72px;height:72px;border-radius:50%;border:1px solid var(--border);background:var(--bg-1);margin-bottom:24px;">🔓</button>
      <a id="use-password" href="#" style="font-size:12px;color:var(--accent);">Sign in with password instead</a>
    </div>
  `;

  app.querySelector('#unlock-btn').addEventListener('click', () => showScreen('dashboard'));
  app.querySelector('#use-password').addEventListener('click', async (e) => {
    e.preventDefault();
    await sb.auth.signOut();
    showScreen('signin');
  });
}
