import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';
import { passwordFieldHtml, wirePasswordEye } from '../lib/password-field.js';

export function mount(app) {
  app.innerHTML = `
    <div style="position:relative;min-height:100vh;display:flex;flex-direction:column;justify-content:flex-end;overflow:hidden;">
      <div style="position:absolute;inset:0;background-image:url('/images/login-hero.jpg');background-size:cover;background-position:center 15%;"></div>
      <div style="position:absolute;inset:0;background:linear-gradient(to bottom, rgba(0,0,0,0.15) 0%, rgba(0,0,0,0.35) 55%, rgba(0,0,0,0.7) 100%);"></div>

      <div style="position:relative;padding:0 24px 40px;">
        <div style="max-width:400px;margin:0 auto;width:100%;">
          <div style="margin-bottom:24px;">
            <h1 style="margin:0 0 2px;font-size:24px;color:#ffffff;text-shadow:0 1px 4px rgba(0,0,0,0.4);">approveDoc</h1>
            <p style="font-size:13px;color:rgba(255,255,255,0.85);margin:0;text-shadow:0 1px 3px rgba(0,0,0,0.4);">Sign in to continue</p>
          </div>

          <label style="font-size:12px;color:rgba(255,255,255,0.85);margin-bottom:4px;display:block;">Email</label>
          <input id="email" type="email" autocomplete="username" placeholder="name@company.com"
            style="width:100%;padding:10px;margin-bottom:14px;border:none;border-radius:8px;background:rgba(255,255,255,0.94);color:#1a1917;" />

          <label style="font-size:12px;color:rgba(255,255,255,0.85);margin-bottom:4px;display:block;">Password</label>
          <div style="margin-bottom:8px;">
            ${passwordFieldHtml('password', 'Enter your password', 'current-password')}
          </div>

          <div style="text-align:right;margin-bottom:20px;">
            <a id="forgot" href="#" style="font-size:12px;color:#ffffff;text-decoration:underline;">Forgot password?</a>
          </div>

          <div id="error" style="display:none;font-size:12px;color:#ffffff;background:rgba(163,45,45,0.85);padding:8px 10px;border-radius:8px;margin-bottom:12px;"></div>

          <button id="submit" style="width:100%;padding:12px;font-size:14px;border:none;border-radius:8px;background:var(--accent);color:var(--on-accent);">
            Sign in
          </button>
        </div>
      </div>
    </div>
  `;

  wirePasswordEye(app, 'password');

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
