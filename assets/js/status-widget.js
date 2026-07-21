/**
 * status-widget.js
 *
 * Injects a document-status dropdown button into the navbar, left of the
 * dark mode toggle. Shows counts for the currently selected user (persisted
 * in localStorage under STORAGE_KEY). Clicking an item navigates to the
 * Testing > User View page with the relevant section pre-expanded.
 *
 * For now the "current user" is whoever was last selected in Testing > User
 * View. When this moves to real authentication the STORAGE_KEY value will
 * be set automatically on login instead.
 */
(function() {

const STORAGE_KEY = 'approvedoc_status_user_id';
const USER_VIEW_PATH = '../../pages/testing/user-view.html';

// Status colours matching user-view.html STATUS_COLOURS
const STATUS_META = [
  { key: 'awaiting',     label: 'Awaiting Action', colour: '#009432', section: 'awaiting' },
  { key: 'overdue',      label: 'Overdue',          colour: '#EA2027', section: 'awaiting' },  // opens awaiting section
  null, // divider
  { key: 'approved',     label: 'Acknowledged',     colour: '#8BC34A', section: 'acknowledged' },
  { key: 'rejected',     label: 'Rejected',         colour: '#B33771', section: 'rejected' },
  null, // divider
  { key: 'reference',    label: 'Reference',        colour: '#b2bec3', section: 'reference' },
];

let counts = { awaiting: 0, overdue: 0, approved: 0, rejected: 0, reference: 0 };
let currentUserId = null;
let currentUserName = null;

// ── Public API ────────────────────────────────────────────────────────────

window.StatusWidget = {
  init,
  setUser,
  refresh,
};

async function init() {
  _injectButton();
  currentUserId = localStorage.getItem(STORAGE_KEY) || null;
  if (currentUserId) await _loadCounts();
  _render();
}

async function setUser(userId) {
  currentUserId = userId || null;
  if (userId) {
    localStorage.setItem(STORAGE_KEY, userId);
  } else {
    localStorage.removeItem(STORAGE_KEY);
  }
  await refresh();
}

async function refresh() {
  if (currentUserId) await _loadCounts();
  else counts = { awaiting: 0, overdue: 0, approved: 0, rejected: 0, reference: 0 };
  if (!currentUserId) currentUserName = null;
  _render();
}

// ── DOM injection ─────────────────────────────────────────────────────────

function _injectButton() {
  const themeBtn = document.querySelector('[data-theme-toggle]');
  if (!themeBtn) return;

  const wrapper = document.createElement('div');
  wrapper.className = 'dropdown';
  wrapper.id = 'statusWidgetDropdown';
  wrapper.innerHTML = `
    <button class="btn btn-icon" id="statusWidgetBtn" aria-expanded="false">
      <i class="ti ti-list-check"></i>
    </button>
    <div class="dropdown-menu dropdown-menu-end" id="statusWidgetMenu" style="min-width:240px;padding-top:0"></div>`;

  themeBtn.parentNode.insertBefore(wrapper, themeBtn);

  // Bootstrap won't auto-initialise dynamically injected dropdowns so we
  // do it manually. autoClose:'outside' means clicking anywhere outside
  // the menu closes it without any extra wiring needed.
  const btn  = wrapper.querySelector('#statusWidgetBtn');
  const bsDd = new bootstrap.Dropdown(btn, { autoClose: 'outside' });
  btn.addEventListener('click', () => bsDd.toggle());
}

// ── Data loading ──────────────────────────────────────────────────────────

async function _loadCounts() {
  if (!currentUserId || typeof sb === 'undefined') return;

  const [itemsRes, userRes] = await Promise.all([
    sb.from('ad_distribution_item')
      .select('status, acknowledged, rejected, due_date, warning1, warning2')
      .eq('user_id', currentUserId),
    sb.from('ad_user')
      .select('first_name, last_name, email')
      .eq('user_id', currentUserId)
      .single(),
  ]);

  if (userRes.data) {
    const u = userRes.data;
    currentUserName = [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email || null;
  }

  if (itemsRes.error) { console.error('[StatusWidget]', itemsRes.error); return; }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  counts = { awaiting: 0, overdue: 0, approved: 0, rejected: 0, reference: 0 };

  (itemsRes.data || []).forEach(item => {
    if (item.rejected) { counts.rejected++; return; }
    if (item.acknowledged) { counts.approved++; return; }

    // Not actioned — check if overdue
    if (item.due_date && new Date(item.due_date) < today) {
      counts.overdue++;
    } else {
      counts.awaiting++;
    }
    // Reference: placeholder, always 0 for now
  });
}

// ── Rendering ─────────────────────────────────────────────────────────────

function _render() {
  const menu = document.getElementById('statusWidgetMenu');
  if (!menu) return;

  const nameHeader = currentUserName
    ? `<div class="px-3 py-2 text-secondary" style="background:var(--tblr-bg-surface-secondary);border-bottom:1px solid var(--tblr-border-color)">${currentUserName}</div>`
    : `<div class="px-3 py-2 text-secondary" style="background:var(--tblr-bg-surface-secondary);border-bottom:1px solid var(--tblr-border-color)">No user selected</div>`;

  menu.innerHTML = nameHeader + STATUS_META.map(meta => {
    if (meta === null) return '<hr class="dropdown-divider my-1" />';

    const count = counts[meta.key] ?? 0;
    return `<a class="dropdown-item d-flex align-items-center justify-content-between py-2 ps-3 status-widget-item"
        href="#" data-section="${meta.section}" data-expand="${meta.key === 'overdue' ? 'awaiting' : meta.section}">
      <span>${meta.label}</span>
      <span class="badge rounded-pill ms-3" style="background:${meta.colour};color:#fff;min-width:1.5rem">${count}</span>
    </a>`;
  }).join('');

  menu.querySelectorAll('.status-widget-item').forEach(item => {
    item.addEventListener('click', e => {
      e.preventDefault();
      _navigate(item.dataset.section, item.dataset.expand);
    });
  });
}

function _navigate(section, expandSection) {
  // Work out the path to user-view.html relative to the current page.
  // We store the current page's depth via data-app-root on <html>.
  const appRoot = document.documentElement.dataset.appRoot || '../../';
  const url = `${appRoot}pages/testing/user-view.html?expand=${expandSection}`;
  window.location.href = url;
}

})();
