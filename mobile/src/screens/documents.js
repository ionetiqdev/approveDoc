import { sb } from '../lib/supabase-client.js';
import { showScreen } from '../router.js';

let allItems = [];

export async function mount(app, params = {}) {
  const { data: { user } } = await sb.auth.getUser();

  const { data: items, error } = await sb
    .from('ad_distribution_item')
    .select('distrib_item_id, due_date, acknowledged, rejected, ad_distribution(doc_id, ad_document(doc_id, name))')
    .eq('user_id', user.id)
    .order('due_date', { ascending: true });

  allItems = items || [];

  const statusFilter = params.statusFilter || null;

  if (statusFilter) {
    renderFocusedView(app, statusFilter, error);
  } else {
    renderBrowseView(app, error);
  }
}

/* Opened from a dashboard stat card (Overdue/Pending/Done) - a single
   focused list with no toggle, since the filter was already chosen. */
function renderFocusedView(app, statusFilter, error) {
  const labels = { overdue: 'Overdue', pending: 'Pending', done: 'Completed' };

  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;">
      <div style="padding:16px 16px 0;display:flex;align-items:center;gap:8px;">
        <button id="back" style="border:none;background:none;padding:4px;color:var(--text-primary);">&larr;</button>
        <h2 style="margin:0;font-size:18px;">${labels[statusFilter] || 'Documents'}</h2>
      </div>

      ${error ? `<p style="padding:16px 16px 0;font-size:13px;color:var(--danger);">Couldn't load documents: ${error.message}</p>` : ''}

      <div id="doc-list" style="padding:12px 16px 16px;display:flex;flex-direction:column;gap:8px;flex:1;"></div>
    </div>
  `;

  app.querySelector('#back').addEventListener('click', () => showScreen('dashboard'));
  renderList(app, filterByStatus(statusFilter));
}

/* Opened from the bottom nav - the general Pending/All browser. */
function renderBrowseView(app, error) {
  app.innerHTML = `
    <div style="flex:1;display:flex;flex-direction:column;">
      <div style="padding:16px 16px 0;display:flex;align-items:center;gap:8px;">
        <button id="back" style="border:none;background:none;padding:4px;color:var(--text-primary);">&larr;</button>
        <h2 style="margin:0;font-size:18px;">Documents</h2>
      </div>

      <div style="padding:12px 16px;">
        <div style="display:inline-flex;background:var(--bg-1);border-radius:20px;padding:3px;">
          <button id="filter-pending" style="border:none;padding:6px 16px;font-size:13px;border-radius:17px;background:var(--accent);color:var(--on-accent);">Pending</button>
          <button id="filter-all" style="border:none;padding:6px 16px;font-size:13px;border-radius:17px;background:transparent;color:var(--text-secondary);">All</button>
        </div>
      </div>

      ${error ? `<p style="padding:0 16px;font-size:13px;color:var(--danger);">Couldn't load documents: ${error.message}</p>` : ''}

      <div id="doc-list" style="padding:0 16px 16px;display:flex;flex-direction:column;gap:8px;flex:1;"></div>
    </div>
  `;

  app.querySelector('#back').addEventListener('click', () => showScreen('dashboard'));
  app.querySelector('#filter-pending').addEventListener('click', (e) => setToggle(app, filterByStatus('pending'), e.target));
  app.querySelector('#filter-all').addEventListener('click', (e) => setToggle(app, allItems, e.target));

  renderList(app, filterByStatus('pending'));
}

function setToggle(app, items, activeBtn) {
  app.querySelectorAll('#filter-pending, #filter-all').forEach(btn => {
    btn.style.background = 'transparent';
    btn.style.color = 'var(--text-secondary)';
  });
  activeBtn.style.background = 'var(--accent)';
  activeBtn.style.color = 'var(--on-accent)';
  renderList(app, items);
}

function filterByStatus(status) {
  const today = new Date().toISOString().slice(0, 10);
  if (status === 'overdue') return allItems.filter(i => !i.acknowledged && !i.rejected && i.due_date && i.due_date < today);
  if (status === 'pending') return allItems.filter(i => !i.acknowledged && !i.rejected);
  if (status === 'done') return allItems.filter(i => i.acknowledged || i.rejected);
  return allItems;
}

function renderList(app, items) {
  const today = new Date().toISOString().slice(0, 10);
  const list = app.querySelector('#doc-list');

  if (items.length === 0) {
    list.innerHTML = `<p style="font-size:13px;color:var(--text-secondary);">Nothing here.</p>`;
    return;
  }

  list.innerHTML = items.map(i => {
    const overdue = !i.acknowledged && !i.rejected && i.due_date && i.due_date < today;
    const title = i.ad_distribution?.ad_document?.name || 'Untitled document';
    const status = i.acknowledged ? 'Acknowledged' : i.rejected ? 'Rejected' : (overdue ? 'Overdue' : 'Pending');
    const statusColor = i.acknowledged ? 'var(--success)' : i.rejected || overdue ? 'var(--danger)' : 'var(--text-secondary)';

    return `
      <div class="doc-item" data-id="${i.distrib_item_id}" data-title="${title.replace(/"/g, '&quot;')}"
        style="background:var(--bg-1);padding:10px 12px;display:flex;justify-content:space-between;align-items:center;cursor:pointer;
          ${overdue ? 'border-left:3px solid var(--danger);border-radius:0 14px 14px 0;' : 'border-radius:14px;'}">
        <div style="flex:1;min-width:0;">
          <p style="font-size:14px;margin:0;">${title}</p>
          ${i.due_date ? `<p style="font-size:11px;color:var(--text-secondary);margin:0;">Due ${i.due_date}</p>` : ''}
        </div>
        <span style="font-size:12px;color:${statusColor};white-space:nowrap;margin-left:8px;">${status}</span>
      </div>
    `;
  }).join('');

  list.querySelectorAll('.doc-item').forEach(el => {
    el.addEventListener('click', () => {
      showScreen('document-detail', { itemId: el.dataset.id, title: el.dataset.title, from: 'documents' });
    });
  });
}
