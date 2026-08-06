/* Shared bottom nav - used on every top-level screen (Dashboard, Documents,
   Profile, Admin Insights). Deliberately NOT used on document-detail, which
   is a genuine drill-down screen - the space that frees up there goes to
   the PDF viewer instead. Also not used pre-auth (sign-in/unlock/forgot). */

export function bottomNavHtml(activeTab, isAdmin) {
  const tab = (id, label) => {
    const active = activeTab === id;
    return `
      <button class="bottom-nav-btn" data-tab="${id}" style="flex:1;border:none;background:none;padding:10px;color:${active ? 'var(--accent)' : 'var(--text-secondary)'};font-weight:${active ? '600' : '400'};">
        ${label}
      </button>
    `;
  };

  return `
    <div style="display:flex;border-top:1px solid var(--border);">
      ${tab('home', 'Home')}
      ${tab('documents', 'Documents')}
      ${isAdmin ? tab('admin', 'Insights') : ''}
      ${tab('profile', 'Profile')}
    </div>
  `;
}

const TAB_SCREENS = {
  home: 'dashboard',
  documents: 'documents',
  admin: 'admin-insights',
  profile: 'profile'
};

export function wireBottomNav(app, showScreen) {
  app.querySelectorAll('.bottom-nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = TAB_SCREENS[btn.dataset.tab];
      if (target) showScreen(target);
    });
  });
}
