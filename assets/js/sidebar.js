/* ============================================================
   ionetiq — sidebar.js  v2.0
   Features:
   - Collapse / expand with localStorage persistence
   - Submenu open/close with localStorage persistence
   - Tooltips on icons in collapsed state
   - Floating submenu panel in collapsed state
   - Mobile overlay
   - Active link detection with parent submenu open
   Call Sidebar.init() AFTER SidebarHtml.inject()
   ============================================================ */

const Sidebar = (() => {
  const COLLAPSED_KEY = 'app_sidebar_collapsed';
  const OPEN_KEY      = 'app_sidebar_open';

  function _save(key, val) { try { localStorage.setItem(key, val); } catch(e) {} }
  function _load(key)      { try { return localStorage.getItem(key); } catch(e) { return null; } }
  function _getOpenIds()   { try { return JSON.parse(_load(OPEN_KEY) || '[]'); } catch(e) { return []; } }
  function _saveOpenIds(ids) { _save(OPEN_KEY, JSON.stringify(ids)); }

  // ── Floating submenu ────────────────────────────────────────────────────
  let _floatEl  = null;
  let _floatTgt = null;
  let _floatTimer = null;

  function _createFloatMenu() {
    if (_floatEl) return;
    _floatEl = document.createElement('div');
    _floatEl.className = 'sidebar-float-menu';
    document.body.appendChild(_floatEl);

    _floatEl.addEventListener('mouseenter', () => clearTimeout(_floatTimer));
    _floatEl.addEventListener('mouseleave', () => {
      _floatTimer = setTimeout(_hideFloat, 120);
    });
  }

  function _showFloat(link, submenuId) {
    clearTimeout(_floatTimer);
    _createFloatMenu();

    const submenu = document.getElementById(submenuId);
    if (!submenu) return;

    const title = link.querySelector('.nav-link-text')?.textContent?.trim() || '';

    // Build items — detect nested submenus and render as expandable rows
    let html = `<div class="float-menu-title">${title}</div>`;

    submenu.querySelectorAll(':scope > li').forEach(li => {
      const subTrigger = li.querySelector(':scope > a[data-submenu]');
      if (subTrigger) {
        // Nested submenu — render as item with arrow
        const subText = subTrigger.querySelector('.nav-link-text')?.textContent?.trim() || '';
        const subId   = subTrigger.dataset.submenu;
        html += `<div class="nav-link float-submenu-trigger" data-submenu-id="${subId}" style="justify-content:space-between">
          <span>${subText}</span><i class="ti ti-chevron-right" style="font-size:.75rem;opacity:.6"></i>
        </div>`;
        // Also render nested items inline below with indent
        const nested = document.getElementById(subId);
        if (nested) {
          nested.querySelectorAll('a[href]').forEach(a => {
            const text   = a.querySelector('.nav-link-text')?.textContent?.trim() || a.textContent.trim();
            const icon   = a.querySelector('i')?.outerHTML || '';
            const active = a.classList.contains('active') ? ' active' : '';
            html += `<a href="${a.href}" class="nav-link${active}" style="padding-left:1.5rem;font-size:.8rem">${icon}${text}</a>`;
          });
        }
      } else {
        // Regular link
        const a = li.querySelector('a[href]');
        if (!a) return;
        const text   = a.querySelector('.nav-link-text')?.textContent?.trim() || a.textContent.trim();
        const icon   = a.querySelector('i')?.outerHTML || '';
        const active = a.classList.contains('active') ? ' active' : '';
        html += `<a href="${a.href}" class="nav-link${active}">${icon}${text}</a>`;
      }
    });

    _floatEl.innerHTML = html;

    // Position vertically aligned to the link
    const rect  = link.getBoundingClientRect();
    const menuH = _floatEl.offsetHeight || 200;
    let top     = rect.top;
    if (top + menuH > window.innerHeight - 8) top = window.innerHeight - menuH - 8;
    _floatEl.style.top = top + 'px';

    _floatEl.classList.add('visible');
    _floatTgt = link;
  }

  function _hideFloat() {
    if (_floatEl) _floatEl.classList.remove('visible');
    _floatTgt = null;
  }

  // ── Tooltips ────────────────────────────────────────────────────────────
  function _initTooltips(sidebar) {
    // Add Bootstrap tooltips to all nav links that have text
    sidebar.querySelectorAll('.nav-link').forEach(link => {
      const text = link.querySelector('.nav-link-text')?.textContent?.trim();
      if (!text) return;
      link.setAttribute('data-bs-toggle', 'tooltip');
      link.setAttribute('data-bs-placement', 'right');
      link.setAttribute('data-bs-title', text);
      link.setAttribute('data-bs-trigger', 'hover');
    });
  }

  function _enableTooltips(sidebar) {
    sidebar.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
      const existing = bootstrap.Tooltip.getInstance(el);
      if (!existing) new bootstrap.Tooltip(el, { trigger: 'hover' });
    });
  }

  function _disableTooltips(sidebar) {
    sidebar.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
      const tt = bootstrap.Tooltip.getInstance(el);
      if (tt) { tt.hide(); tt.disable(); }
    });
  }

  function _onCollapsedChange(sidebar, collapsed) {
    if (collapsed) {
      _enableTooltips(sidebar);
    } else {
      _disableTooltips(sidebar);
      _hideFloat();
    }
  }

  // ── Init ────────────────────────────────────────────────────────────────
  function init() {
    const sidebar = document.getElementById('sidebar');
    const toggle  = document.getElementById('sidebarToggle');
    const overlay = document.getElementById('sidebarOverlay');
    if (!sidebar) return;

    // Restore collapsed state
    const isCollapsed = window.innerWidth >= 992 && _load(COLLAPSED_KEY) === 'true';
    if (isCollapsed) sidebar.classList.add('collapsed');

    // Init tooltips
    _initTooltips(sidebar);
    if (isCollapsed) _enableTooltips(sidebar);

    // Restore open submenus
    const openIds = _getOpenIds();
    openIds.forEach(id => {
      const sub = document.getElementById(id);
      const lnk = sidebar.querySelector(`[data-submenu="${id}"]`);
      if (sub) sub.classList.add('open');
      if (lnk) lnk.classList.add('submenu-open');
    });

    // Toggle collapse
    if (toggle) {
      toggle.addEventListener('click', () => {
        if (window.innerWidth < 992) {
          sidebar.classList.toggle('mobile-open');
          overlay?.classList.toggle('visible');
        } else {
          const nowCollapsed = sidebar.classList.toggle('collapsed');
          _save(COLLAPSED_KEY, nowCollapsed);
          _onCollapsedChange(sidebar, nowCollapsed);
        }
      });
    }

    overlay?.addEventListener('click', () => {
      sidebar.classList.remove('mobile-open');
      overlay.classList.remove('visible');
    });

    // Submenu links
    sidebar.querySelectorAll('.nav-link[data-submenu]').forEach(link => {
      link.addEventListener('click', e => {
        e.preventDefault();

        // Collapsed — show floating submenu instead of expanding
        if (sidebar.classList.contains('collapsed')) {
          const id = link.dataset.submenu;
          if (_floatTgt === link && _floatEl?.classList.contains('visible')) {
            _hideFloat();
          } else {
            _showFloat(link, id);
          }
          return;
        }

        const id      = link.dataset.submenu;
        const submenu = document.getElementById(id);
        if (!submenu) return;
        const opening = !submenu.classList.contains('open');

        if (opening) {
          submenu.classList.add('open');
          link.classList.add('submenu-open');
        } else {
          submenu.querySelectorAll('.nav-submenu.open').forEach(m => m.classList.remove('open'));
          submenu.querySelectorAll('.nav-link.submenu-open').forEach(l => l.classList.remove('submenu-open'));
          submenu.classList.remove('open');
          link.classList.remove('submenu-open');
        }

        const nowOpen = [...sidebar.querySelectorAll('.nav-submenu.open')].map(m => m.id).filter(Boolean);
        _saveOpenIds(nowOpen);
      });

      // Hover float menu when collapsed
      link.addEventListener('mouseenter', () => {
        if (!sidebar.classList.contains('collapsed')) return;
        clearTimeout(_floatTimer);
        _floatTimer = setTimeout(() => _showFloat(link, link.dataset.submenu), 80);
      });
      link.addEventListener('mouseleave', () => {
        if (!sidebar.classList.contains('collapsed')) return;
        _floatTimer = setTimeout(_hideFloat, 120);
      });
    });

    // Close float menu when clicking elsewhere
    document.addEventListener('click', e => {
      if (_floatEl && !_floatEl.contains(e.target) && !e.target.closest('[data-submenu]')) {
        _hideFloat();
      }
    });

    // Active links
    const current = window.location.pathname;
    sidebar.querySelectorAll('.nav-link[href]').forEach(link => {
      const href = link.getAttribute('href');
      if (!href || href === '#') return;
      try {
        const lp = new URL(href, window.location.origin).pathname;
        if (lp === current) {
          link.classList.add('active');
          let el = link.closest('.nav-submenu');
          while (el) {
            el.classList.add('open');
            const parentLink = el.previousElementSibling;
            if (parentLink?.dataset.submenu) parentLink.classList.add('submenu-open');
            el = el.parentElement?.closest('.nav-submenu');
          }
          const nowOpen = [...sidebar.querySelectorAll('.nav-submenu.open')].map(m => m.id).filter(Boolean);
          _saveOpenIds(nowOpen);
        }
      } catch(e) {}
    });
  }

  return { init };
})();

window.Sidebar = Sidebar;
