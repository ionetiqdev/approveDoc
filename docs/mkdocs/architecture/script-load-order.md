# Script Load Order

Every page loads scripts in this exact order:

```html
<!-- 1. CDN libraries -->
<script src="https://cdn.jsdelivr.net/npm/@tabler/core@1.4.0/dist/js/tabler.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<!-- 2. Core app modules (order matters) -->
<script src="../../assets/js/version.js"></script>
<script src="../../assets/js/supabase-client.js"></script>  <!-- sb, AppSession -->
<script src="../../assets/js/auth.js"></script>             <!-- Auth -->
<script src="../../assets/js/app.js"></script>              <!-- App -->
<script src="../../assets/js/theme.js"></script>
<script src="../../assets/js/sidebar-html.js"></script>     <!-- SidebarHtml -->
<script src="../../assets/js/sidebar.js"></script>          <!-- Sidebar -->
<script src="../../assets/js/profile-modal.js"></script>
<script src="../../assets/js/status-widget.js"></script>    <!-- StatusWidget -->

<!-- 3. Page init -->
<script>
  (async () => {
    const session = await Auth.requireAuth();
    if (!session) return;
    SidebarHtml.inject(window._appRootUrl || '../../');
    Sidebar.init();
    Auth.refreshUI();  // (1)
    StatusWidget.init();
    // ... page-specific init
  })();
</script>
```

1. Must be called **after** `SidebarHtml.inject()` — the sidebar DOM elements must exist before `refreshUI()` can reveal role-gated items.

!!! warning "Auth.refreshUI() timing"
    `requireAuth()` calls `_applyUserUI()` internally, but at that point the sidebar hasn't been injected yet. Always call `Auth.refreshUI()` explicitly after `SidebarHtml.inject()`.
