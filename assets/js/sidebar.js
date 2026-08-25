/* ============================================================
   approveDoc - sidebar.js
   Call Sidebar.init() AFTER SidebarHtml.inject()
   ============================================================ */

const Sidebar = (() => {
  const COLLAPSED_KEY = 'app_sidebar_collapsed';
  const OPEN_KEY      = 'app_sidebar_open'; // JSON array of open submenu IDs

  function _save(key, val) { try { localStorage.setItem(key, val); } catch(e) {} }
  function _load(key)      { try { return localStorage.getItem(key); } catch(e) { return null; } }

  function _getOpenIds() {
    try { return JSON.parse(_load(OPEN_KEY) || '[]'); } catch(e) { return []; }
  }

  function _saveOpenIds(ids) {
    _save(OPEN_KEY, JSON.stringify(ids));
  }

  function init() {
    const sidebar = document.getElementById('sidebar');
    const toggle  = document.getElementById('sidebarToggle');
    const overlay = document.getElementById('sidebarOverlay');
    if (!sidebar) return;

    // Restore collapsed state
    if (window.innerWidth >= 992) {
      try { if (_load(COLLAPSED_KEY) === 'true') sidebar.classList.add('collapsed'); } catch(e) {}
    }

    // Restore ALL open submenus
    const openIds = _getOpenIds();
    openIds.forEach(id => {
      const sub = document.getElementById(id);
      const lnk = sidebar.querySelector(`[data-submenu="${id}"]`);
      if (sub) sub.classList.add('open');
      if (lnk) lnk.classList.add('submenu-open');
    });

    // Toggle sidebar collapse
    if (toggle) {
      toggle.addEventListener('click', () => {
        if (window.innerWidth < 992) {
          sidebar.classList.toggle('mobile-open');
          overlay && overlay.classList.toggle('visible');
        } else {
          sidebar.classList.toggle('collapsed');
          _save(COLLAPSED_KEY, sidebar.classList.contains('collapsed'));
        }
      });
    }

    overlay && overlay.addEventListener('click', () => {
      sidebar.classList.remove('mobile-open');
      overlay.classList.remove('visible');
    });

    // Submenus - close siblings only, preserve parent state
    sidebar.querySelectorAll('.nav-link[data-submenu]').forEach(link => {
      link.addEventListener('click', e => {
        e.preventDefault();

        if (sidebar.classList.contains('collapsed')) {
          sidebar.classList.remove('collapsed');
          _save(COLLAPSED_KEY, 'false');
        }

        const id      = link.dataset.submenu;
        const submenu = document.getElementById(id);
        if (!submenu) return;
        const opening = !submenu.classList.contains('open');

        if (opening) {
          submenu.classList.add('open');
          link.classList.add('submenu-open');
        } else {
          // Close this submenu and all children
          submenu.querySelectorAll('.nav-submenu.open').forEach(m => m.classList.remove('open'));
          submenu.querySelectorAll('.nav-link.submenu-open').forEach(l => l.classList.remove('submenu-open'));
          submenu.classList.remove('open');
          link.classList.remove('submenu-open');
        }

        // Save ALL currently open submenu IDs
        const nowOpen = [...sidebar.querySelectorAll('.nav-submenu.open')].map(m => m.id).filter(Boolean);
        _saveOpenIds(nowOpen);
      });
    });

    // Active links - exact match, opens all parent submenus
    const current = window.location.pathname;
    sidebar.querySelectorAll('.nav-link[href]').forEach(link => {
      const href = link.getAttribute('href');
      if (!href || href === '#') return;
      try {
        const lp = new URL(href, window.location.origin).pathname;
        if (lp === current) {
          link.classList.add('active');
          // Walk up opening all parent submenus
          let el = link.closest('.nav-submenu');
          while (el) {
            el.classList.add('open');
            const parentLink = el.previousElementSibling;
            if (parentLink && parentLink.dataset.submenu) {
              parentLink.classList.add('submenu-open');
            }
            el = el.parentElement?.closest('.nav-submenu');
          }
          // Save the open state from active page detection
          const nowOpen = [...sidebar.querySelectorAll('.nav-submenu.open')].map(m => m.id).filter(Boolean);
          _saveOpenIds(nowOpen);
        }
      } catch(e) {}
    });
  }

  return { init };
})();

window.Sidebar = Sidebar;
