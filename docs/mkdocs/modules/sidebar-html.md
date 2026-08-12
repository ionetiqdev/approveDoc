# sidebar-html.js

Injects the sidebar HTML and Preferences modal, and manages per-user display preferences.

## SidebarHtml.inject()

```js
SidebarHtml.inject(root)
```

Call this after `Auth.requireAuth()` and before `Auth.refreshUI()` on every page.

- `root` — use `window._appRootUrl || '../../'`
- Injects the full sidebar nav, footer, and Preferences modal into `<aside id="sidebar">`
- Sets `window._appRoot = root` for auth.js redirect compatibility

## _scopedKey()

Internal function that builds localStorage keys scoped to the current deploy environment:

```js
_scopedKey('app_accent')
// → 'app_accent:ionetiq.dev/approvedoc/dev/'
```

See [localStorage Isolation](../architecture/localstorage.md) for full details.

## Preferences modal

The Preferences modal has three tabs:

=== "Display"
    - Accent colour (120×30px swatch)
    - Sidebar background colour
    - Dark mode toggle

=== "Document"
    - Upload button visibility
    - Drop zone visibility
    - Prompt on drop
    - Delete button visibility

    !!! note
        Only `upload` and `delete` sections are saved to user preferences. `pdfViewer` and `pdfButtons` are app-level config in `config.js` — never overridden by user preferences.

=== "Current User"
    - Avatar (click to upload → `user-avatars` bucket)
    - Display name
    - Job title
    - Password change (requires current password verification)

## Subsystem markers

Optional subsystems (Documents, Issues) in the nav are wrapped in comment markers:

```html
<!-- SUBSYSTEM:documents:start -->
<li class="nav-item role-hidden" data-require-role="admin">...</li>
<!-- SUBSYSTEM:documents:end -->
```

To remove a subsystem from a project, delete everything between its markers. See `docs/SUBSYSTEMS.md`.
