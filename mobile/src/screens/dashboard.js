import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';

export async function mount(app) {
  const { data: { user } } = await sb.auth.getUser();

  const { data: profile } = await sb
    .from('ad_user')
    .select('first_name, role_admin')
    .eq('user_id', user.id)
    .single();

  const today = new Date().toISOString().slice(0, 10);

  const { data: items } = await sb
    .from('ad_distribution_item')
    .select('distrib_item_id, due_date, acknowledged, rejected, ad_distribution(doc_id, ad_document(title))')
    .eq('user_id', user.id);

  const pending = (items || []).filter(i => !i.acknowledged && !i.rejected);
  const overdue = pending.filter(i => i.due_date && i.due_date < today);
  const done = (items || []).filter(i => i.acknowledged || i.rejected);

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;">
      <div style="padding:16px;display:flex;align-items:center;justify-content:space-between;">
        <div>
          <p style="font-size:12px;color:var(--text-secondary);margin:0;">Good morning</p>
          <h2 style="margin:0;font-size:18px;">${profile?.first_name || ''}</h2>
        </div>
      </div>

      <div style="padding:0 16px 16px;flex:1;">
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-bottom:20px;">
          <div style="background:var(--bg-1);border-radius:14px;padding:10px;text-align:center;">
            <p style="font-size:18px;font-weight:600;margin:0;">${overdue.length}</p>
            <p style="font-size:10px;color:var(--text-secondary);margin:0;">Overdue</p>
          </div>
          <div style="background:var(--bg-1);border-radius:14px;padding:10px;text-align:center;">
            <p style="font-size:18px;font-weight:600;margin:0;">${pending.length}</p>
            <p style="font-size:10px;color:var(--text-secondary);margin:0;">Pending</p>
          </div>
          <div style="background:var(--bg-1);border-radius:14px;padding:10px;text-align:center;">
            <p style="font-size:18px;font-weight:600;margin:0;">${done.length}</p>
            <p style="font-size:10px;color:var(--text-secondary);margin:0;">Done</p>
          </div>
        </div>

        <h3 style="margin:0 0 10px;font-size:15px;">Needs attention</h3>
        <div id="attention-list" style="display:flex;flex-direction:column;gap:8px;">
          ${overdue.length === 0 ? `<p style="font-size:13px;color:var(--text-secondary);">Nothing overdue.</p>` :
            overdue.map(i => `
              <div class="attn-item" data-id="${i.distrib_item_id}" style="background:var(--bg-1);border-radius:14px;padding:10px 12px;display:flex;justify-content:space-between;align-items:center;">
                <span style="font-size:14px;">${i.ad_distribution?.ad_document?.title || 'Untitled document'}</span>
                <span style="font-size:12px;color:var(--danger);">Overdue</span>
              </div>
            `).join('')}
        </div>
      </div>

      <div id="bottom-nav" style="display:flex;border-top:1px solid var(--border);">
        <button id="nav-home" style="flex:1;border:none;background:none;padding:10px;color:var(--accent);">Home</button>
        <button id="nav-docs" style="flex:1;border:none;background:none;padding:10px;color:var(--text-secondary);">Documents</button>
        ${profile?.role_admin ? `<button id="nav-admin" style="flex:1;border:none;background:none;padding:10px;color:var(--text-secondary);">Insights</button>` : ''}
        <button id="nav-profile" style="flex:1;border:none;background:none;padding:10px;color:var(--text-secondary);">Profile</button>
      </div>
    </div>
  `;

  app.querySelector('#nav-docs').addEventListener('click', () => showScreen('documents'));
  app.querySelector('#nav-profile').addEventListener('click', () => showScreen('profile'));
  const adminBtn = app.querySelector('#nav-admin');
  if (adminBtn) adminBtn.addEventListener('click', () => showScreen('admin-insights'));
}
