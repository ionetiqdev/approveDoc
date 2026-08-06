import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';
import { bottomNavHtml, wireBottomNav } from '../lib/bottom-nav.js';
import { iconChip } from '../lib/icons.js';

export async function mount(app) {
  const { data: { user } } = await sb.auth.getUser();

  const { data: profile } = await sb
    .from('ad_user')
    .select('first_name, role_admin')
    .eq('user_id', user.id)
    .single();

  const today = new Date().toISOString().slice(0, 10);

  const { data: items, error: itemsError } = await sb
    .from('ad_distribution_item')
    .select('distrib_item_id, due_date, acknowledged, rejected, ad_distribution(doc_id, ad_document(name))')
    .eq('user_id', user.id);

  const pending = (items || []).filter(i => !i.acknowledged && !i.rejected);
  const overdue = pending.filter(i => i.due_date && i.due_date < today);
  const done = (items || []).filter(i => i.acknowledged || i.rejected);
  const total = (items || []).length;
  const compliancePct = total > 0 ? Math.round((done.length / total) * 100) : null;

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;">
      <div style="padding:16px;display:flex;align-items:center;justify-content:space-between;">
        <div>
          <p style="font-size:12px;color:var(--text-secondary);margin:0;">Good morning</p>
          <h2 style="margin:0;font-size:18px;">${profile?.first_name || ''}</h2>
        </div>
      </div>

      ${itemsError ? `<p style="padding:0 16px;font-size:13px;color:var(--danger);">Couldn't load documents: ${itemsError.message}</p>` : ''}

      <div style="padding:0 16px 16px;flex:1;">
        ${compliancePct !== null ? `
          <div style="background:var(--accent);border-radius:16px;padding:16px;margin-bottom:16px;">
            <p style="font-size:12px;color:var(--on-accent);opacity:0.85;margin:0 0 2px;">Compliance</p>
            <p style="font-size:28px;font-weight:600;color:var(--on-accent);margin:0 0 8px;">${compliancePct}%</p>
            <div style="height:6px;background:rgba(255,255,255,0.3);border-radius:3px;overflow:hidden;">
              <div style="height:100%;width:${compliancePct}%;background:var(--on-accent);border-radius:3px;"></div>
            </div>
          </div>
        ` : ''}

        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-bottom:20px;">
          <button id="stat-overdue" style="border:none;background:var(--bg-1);border-radius:14px;padding:12px 8px;text-align:center;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:6px;">
            ${iconChip('alertTriangle', 'danger', 30)}
            <p style="font-size:18px;font-weight:600;margin:0;color:var(--text-primary);">${overdue.length}</p>
            <p style="font-size:10px;color:var(--text-secondary);margin:0;">Overdue</p>
          </button>
          <button id="stat-pending" style="border:none;background:var(--bg-1);border-radius:14px;padding:12px 8px;text-align:center;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:6px;">
            ${iconChip('clock', 'warning', 30)}
            <p style="font-size:18px;font-weight:600;margin:0;color:var(--text-primary);">${pending.length}</p>
            <p style="font-size:10px;color:var(--text-secondary);margin:0;">Pending</p>
          </button>
          <button id="stat-done" style="border:none;background:var(--bg-1);border-radius:14px;padding:12px 8px;text-align:center;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:6px;">
            ${iconChip('check', 'success', 30)}
            <p style="font-size:18px;font-weight:600;margin:0;color:var(--text-primary);">${done.length}</p>
            <p style="font-size:10px;color:var(--text-secondary);margin:0;">Done</p>
          </button>
        </div>

        <h3 style="margin:0 0 10px;font-size:15px;">Needs attention</h3>
        <div id="attention-list" style="display:flex;flex-direction:column;gap:8px;">
          ${overdue.length === 0 ? `<p style="font-size:13px;color:var(--text-secondary);">Nothing overdue.</p>` :
            overdue.map(i => `
              <div class="attn-item" data-id="${i.distrib_item_id}" data-title="${(i.ad_distribution?.ad_document?.name || 'Untitled document').replace(/"/g, '&quot;')}"
                style="background:var(--bg-1);border-radius:0 14px 14px 0;border-left:3px solid var(--danger);padding:10px 12px;display:flex;align-items:center;gap:10px;cursor:pointer;">
                ${iconChip('alertTriangle', 'danger', 32)}
                <div style="flex:1;min-width:0;">
                  <p style="font-size:14px;margin:0;">${i.ad_distribution?.ad_document?.name || 'Untitled document'}</p>
                  <p style="font-size:11px;color:var(--danger);margin:0;">Overdue</p>
                </div>
              </div>
            `).join('')}
        </div>
      </div>

      ${bottomNavHtml('home', profile?.role_admin)}
    </div>
  `;

  wireBottomNav(app, showScreen);

  app.querySelector('#stat-overdue').addEventListener('click', () => showScreen('documents', { statusFilter: 'overdue' }));
  app.querySelector('#stat-pending').addEventListener('click', () => showScreen('documents', { statusFilter: 'pending' }));
  app.querySelector('#stat-done').addEventListener('click', () => showScreen('documents', { statusFilter: 'done' }));
  app.querySelectorAll('.attn-item').forEach(el => {
    el.addEventListener('click', () => {
      showScreen('document-detail', { itemId: el.dataset.id, title: el.dataset.title, from: 'dashboard' });
    });
  });
}
