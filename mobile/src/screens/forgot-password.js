import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';

/* TODO: RESET_REDIRECT_URL needs a real landing page - see ADR open
   question "Password reset landing page: Supabase default, or a
   branded page on ionetiq.dev?" - not decided yet. */
const RESET_REDIRECT_URL = import.meta.env.VITE_PASSWORD_RESET_REDIRECT_URL;

export function mount(app) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;justify-content:center;padding:0 24px;max-width:400px;margin:0 auto;width:100%;">
      <button id="back" style="align-self:flex-start;border:none;background:none;padding:4px;margin-bottom:16px;">&larr;</button>
      <h1 style="margin:0 0 4px;font-size:20px;">Reset your password</h1>
      <p style="font-size:13px;color:var(--text-secondary);margin:0 0 20px;">We'll email you a link to set a new one.</p>

      <div id="request-step">
        <label style="font-size:12px;color:var(--text-secondary);margin-bottom:4px;display:block;">Email</label>
        <input id="email" type="email" placeholder="name@company.com"
          style="width:100%;padding:10px;margin-bottom:16px;border:1px solid var(--border);border-radius:8px;background:var(--bg-1);color:var(--text-primary);" />
        <div id="error" style="display:none;font-size:12px;color:var(--danger);margin-bottom:12px;"></div>
        <button id="send" style="width:100%;padding:12px;font-size:14px;border:none;border-radius:8px;background:var(--accent);color:var(--on-accent);">
          Send reset link
        </button>
      </div>

      <div id="sent-step" style="display:none;text-align:center;">
        <p style="font-size:14px;margin:0 0 20px;">Check your inbox for the reset link.</p>
        <a id="back-to-signin" href="#" style="font-size:12px;color:var(--accent);">Back to sign in</a>
      </div>
    </div>
  `;

  app.querySelector('#back').addEventListener('click', () => showScreen('signin'));
  app.querySelector('#back-to-signin').addEventListener('click', (e) => { e.preventDefault(); showScreen('signin'); });

  app.querySelector('#send').addEventListener('click', async () => {
    const email = app.querySelector('#email').value.trim();
    const errorEl = app.querySelector('#error');
    errorEl.style.display = 'none';

    if (!email) {
      errorEl.textContent = 'Enter your email address.';
      errorEl.style.display = 'block';
      return;
    }

    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: RESET_REDIRECT_URL
    });

    if (error) {
      errorEl.textContent = error.message;
      errorEl.style.display = 'block';
      return;
    }

    app.querySelector('#request-step').style.display = 'none';
    app.querySelector('#sent-step').style.display = 'block';
  });
}
