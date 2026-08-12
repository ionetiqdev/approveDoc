# Page Conventions

Every page in approveDoc follows the same structure and script load order.

## HTML head template

```html
<!DOCTYPE html>
<html lang="en" data-bs-theme="light" data-app-root="../../"> <!-- (1) -->
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Page Title - approveDoc</title>

  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/core@1.4.0/dist/css/tabler.min.css" />
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.44.0/dist/tabler-icons.min.css" />
  <link rel="stylesheet" href="../../assets/css/theme.css" />

  <!-- Inline pre-paint script — MUST be first, before any other scripts --> <!-- (2) -->
  <script>
    (function() {
      try {
        var root = document.documentElement.getAttribute('data-app-root') || './';
        var absoluteRoot = new URL(root, window.location.href).pathname;
        var suffix = ':' + window.location.hostname + absoluteRoot; // (3)
        window._appRootUrl = (new URL(root, window.location.href)).href; // (4)
        if (!window._appRootUrl.endsWith('/')) window._appRootUrl += '/';
        var savedTheme = localStorage.getItem('app_theme');
        var theme = savedTheme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
        document.documentElement.setAttribute('data-bs-theme', theme);
        var accent = localStorage.getItem('app_accent' + suffix);
        if (accent) { /* apply accent colour */ }
        var sidebarBg = localStorage.getItem('app_sidebar_bg' + suffix);
        if (sidebarBg) { _applySidebarColours(sidebarBg); }
      } catch(e) {}
    })();
  </script>
</head>
```

1. `data-app-root` is `"./"` for the root `index.html`, `"../../"` for `pages/xxx/index.html`
2. Runs before paint to prevent flash of wrong theme/colour
3. `suffix` scopes localStorage keys to this domain + path — see [localStorage Isolation](localstorage.md)
4. `_appRootUrl` is the absolute URL to the app root — used by auth redirects and sidebar links

## Script load order

Scripts must be loaded in this exact order on every page:

```html
<!-- 1. CDN libraries -->
<script src="https://cdn.jsdelivr.net/npm/@tabler/core@1.4.0/dist/js/tabler.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<!-- 2. App modules (order matters — each depends on the previous) -->
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
    Auth.refreshUI();   // Must come AFTER inject() so sidebar elements exist
    StatusWidget.init();
    // ... page-specific init
  })();
</script>
```

!!! warning "Auth.refreshUI() order"
    `Auth.refreshUI()` must be called **after** `SidebarHtml.inject()`. The sidebar doesn't exist in the DOM until it's injected, so role-gated nav items won't be revealed if `refreshUI()` runs first.

## Role-gated elements

Hide elements from users without the required role using `role-hidden` + `data-require-role`:

```html
<!-- Visible to admin and super_admin -->
<li class="nav-item role-hidden" data-require-role="admin">...</li>

<!-- Visible to super_admin only -->
<button class="role-hidden" data-require-role="super_admin">...</button>

<!-- Visible to user role only (NOT admin or super_admin) -->
<li class="nav-item role-hidden" data-require-role="user-only">...</li>
```

`Auth.refreshUI()` removes `role-hidden` from matching elements based on the current user's role.

!!! danger "d-none vs role-hidden"
    **Never use `d-none` for role-gated elements.** `d-none` is reserved for feature-controlled visibility (upload button, drop zone) managed by `applyDocFeatures()`. The two systems must not interfere — `auth.js` manages `role-hidden`; feature code manages `d-none`.
