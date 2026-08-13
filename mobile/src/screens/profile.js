import { sb, isBiometricEnabled, setBiometricEnabled } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';
import { getTheme, setTheme } from '../lib/theme.js';
import { passwordFieldHtml, wirePasswordEye } from '../lib/password-field.js';
import { bottomNavHtml, wireBottomNav } from '../lib/bottom-nav.js';

const APP_VERSION = '0.1.0';

export async function mount(app) {
  const theme = await getTheme();
  const biometricOn = await isBiometricEnabled();

  const { data: { user } } = await sb.auth.getUser();

  const { data: profile } = await sb
    .from('ad_user')
    .select('first_name, last_name, job_title, manager_id, role_admin')
    .eq('user_id', user.id)
    .single();

  const { data: profileMeta } = await sb
    .from('profiles')
    .select('avatar_url')
    .eq('id', user.id)
    .single();

  let managerName = null;
  if (profile?.manager_id) {
    const { data: manager } = await sb
      .from('ad_user')
      .select('first_name, last_name')
      .eq('user_id', profile.manager_id)
      .single();
    if (manager) managerName = `${manager.first_name || ''} ${manager.last_name || ''}`.trim();
  }

  const fullName = `${profile?.first_name || ''} ${profile?.last_name || ''}`.trim();
  const initials = (profile?.first_name?.[0] || '') + (profile?.last_name?.[0] || '');

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;">
      <div style="padding:16px;flex:1;display:flex;flex-direction:column;">
        <button id="back" style="align-self:flex-start;border:none;background:none;padding:8px;font-size:22px;color:var(--text-primary);line-height:1;margin-bottom:16px;">&larr;</button>

        <div style="display:flex;align-items:center;gap:12px;margin-bottom:24px;">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--accent);color:var(--on-accent);display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:600;overflow:hidden;">
            ${profileMeta?.avatar_url
              ? `<img src="${profileMeta.avatar_url}" alt="${initials || 'avatar'}" style="width:100%;height:100%;object-fit:cover;" />`
              : (initials || '?')}
          </div>
          <div>
            <p style="margin:0;font-size:16px;font-weight:600;">${fullName || 'Unknown'}</p>
            ${profile?.job_title ? `<p style="margin:0;font-size:12px;color:var(--text-secondary);">${profile.job_title}</p>` : ''}
            ${managerName ? `<p style="margin:0;font-size:12px;color:var(--text-secondary);">Reports to ${managerName}</p>` : ''}
          </div>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;">
          <span style="font-size:14px;">Theme</span>
          <select id="theme-select" style="padding:6px;border-radius:6px;border:1px solid var(--border);background:var(--bg-1);color:var(--text-primary);">
            <option value="light" ${theme === 'light' ? 'selected' : ''}>Light</option>
            <option value="dark" ${theme === 'dark' ? 'selected' : ''}>Dark</option>
          </select>
        </div>

        <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;">
          <span style="font-size:14px;">Biometric unlock</span>
          <input id="biometric-toggle" type="checkbox" ${biometricOn ? 'checked' : ''} style="width:20px;height:20px;" />
        </div>
        <p style="font-size:11px;color:var(--text-secondary);margin:0 0 8px;">Requires native Face ID/fingerprint integration - not yet wired to real device hardware. Toggling this only affects the sign-in flow's UI at this stage.</p>

        <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;opacity:0.5;">
          <span style="font-size:14px;">Push notifications</span>
          <span style="font-size:12px;color:var(--text-secondary);">Coming soon</span>
        </div>

        <div style="padding:16px 0;">
          <p style="font-size:14px;margin:0 0 8px;">Change password</p>
          <div style="margin-bottom:8px;">${passwordFieldHtml('new-password', 'New password', 'new-password')}</div>
          <div style="margin-bottom:8px;">${passwordFieldHtml('confirm-password', 'Confirm new password', 'new-password')}</div>
          <div id="password-error" style="display:none;font-size:12px;color:var(--danger);margin-bottom:8px;"></div>
          <div id="password-success" style="display:none;font-size:12px;color:var(--success);margin-bottom:8px;">Password updated.</div>
          <button id="save-password" style="width:100%;padding:10px;font-size:13px;border-radius:8px;border:1px solid var(--accent);background:transparent;color:var(--accent);font-weight:600;">Update password</button>
        </div>

        <button id="sign-out" style="margin-top:32px;width:100%;padding:12px;font-size:14px;border:1px solid var(--danger);border-radius:8px;background:transparent;color:var(--danger);">
          Sign out
        </button>

        <p style="font-size:11px;color:var(--text-muted);text-align:center;margin-top:auto;padding-top:24px;">approveDoc mobile v${APP_VERSION}</p>
      </div>

      ${bottomNavHtml('profile', profile?.role_admin)}
    </div>
  `;

  wirePasswordEye(app, 'new-password');
  wirePasswordEye(app, 'confirm-password');
  wireBottomNav(app, showScreen);

  app.querySelector('#back').addEventListener('click', () => showScreen('dashboard'));
  app.querySelector('#theme-select').addEventListener('change', (e) => setTheme(e.target.value));
  app.querySelector('#biometric-toggle').addEventListener('change', (e) => setBiometricEnabled(e.target.checked));

  app.querySelector('#save-password').addEventListener('click', async () => {
    const newPw = app.querySelector('#new-password').value;
    const confirmPw = app.querySelector('#confirm-password').value;
    const errorEl = app.querySelector('#password-error');
    const successEl = app.querySelector('#password-success');
    errorEl.style.display = 'none';
    successEl.style.display = 'none';

    if (newPw.length < 8) {
      errorEl.textContent = 'Password must be at least 8 characters.';
      errorEl.style.display = 'block';
      return;
    }
    if (newPw !== confirmPw) {
      errorEl.textContent = 'Passwords do not match.';
      errorEl.style.display = 'block';
      return;
    }

    const btn = app.querySelector('#save-password');
    btn.disabled = true;
    btn.textContent = 'Updating...';
    const { error } = await sb.auth.updateUser({ password: newPw });
    btn.disabled = false;
    btn.textContent = 'Update password';

    if (error) {
      errorEl.textContent = error.message;
      errorEl.style.display = 'block';
      return;
    }
    app.querySelector('#new-password').value = '';
    app.querySelector('#confirm-password').value = '';
    successEl.style.display = 'block';
  });

  app.querySelector('#sign-out').addEventListener('click', async () => {
    await sb.auth.signOut();
    showScreen('signin');
  });
}
