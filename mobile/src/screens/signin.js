import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';

export function mount(app) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;justify-content:center;padding:0 24px;max-width:400px;margin:0 auto;width:100%;">
      <div style="display:flex;flex-direction:column;align-items:center;margin-bottom:28px;">
        <h1 style="margin:0 0 2px;font-size:22px;">approveDoc</h1>
        <p style="font-size:13px;color:var(--text-secondary);margin:0;">Sign in to continue</p>
      </div>

      <label style="font-size:12px;color:var(--text-secondary);margin-bottom:4px;display:block;">Email</label>
      <input id="email" type="email" autocomplete="username" placeholder="name@company.com"
        style="width:100%;padding:10px;margin-bottom:14px;border:1px solid var(--border);border-radius:8px;background:var(--bg-1);color:var(--text-primary);" />

      <label style="font-size:12px;color:var(--text-secondary);margin-bottom:4px;display:block;">Password</label>
      <input id="password" type="password" autocomplete="current-password" placeholder="Enter your password"
        style="width:100%;padding:10px;margin-bottom:8px;border:1px solid var(--border);border-radius:8px;background:var(--bg-1);color:var(--text-primary);" />

      <div style="text-align:right;margin-bottom:20px;">
        <a id="forgot" href="#" style="font-size:12px;color:var(--accent);">Forgot password?</a>
      </div>

      <div id="error" style="display:none;font-size:12px;color:var(--danger);margin-bottom:12px;"></div>

      <button id="submit" style="width:100%;padding:12px;font-size:14px;border:none;border-radius:8px;background:var(--accent);color:var(--on-accent);">
        Sign in
      </button>
    </div>
  `;

  const emailInput = app.querySelector('#email');
  const pwInput = app.querySelector('#password');
  const errorEl = app.querySelector('#error');
  const submitBtn = app.querySelector('#submit');

  app.querySelector('#forgot').addEventListener('click', (e) => {
    e.preventDefault();
    showScreen('forgot-password');
  });

  submitBtn.addEventListener('click', async () => {
    errorEl.style.display = 'none';
    submitBtn.disabled = true;
    submitBtn.textContent = 'Signing in...';

    const { error } = await sb.auth.signInWithPassword({
      email: emailInput.value.trim(),
      password: pwInput.value
    });

    submitBtn.disabled = false;
    submitBtn.textContent = 'Sign in';

    if (error) {
      errorEl.textContent = error.message;
      errorEl.style.display = 'block';
      return;
    }

    showScreen('dashboard');
  });
}
