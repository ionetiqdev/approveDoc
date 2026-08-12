# localStorage Isolation

## Why Isolation Is Needed

approveDoc runs in multiple environments that share the same domain or differ only by path. Without scoping, user preferences (accent colour, sidebar colour) and the active organisation selection would bleed between environments.

## How It Works

All preference localStorage keys are suffixed with `hostname + absoluteRoot`:

```js
var suffix = ':' + window.location.hostname + absoluteRoot;
localStorage.getItem('app_accent' + suffix)
```

This gives each environment its own key namespace:

| Environment | Key suffix |
|---|---|
| `ionetiq.dev/approvedoc/dev/` | `:ionetiq.dev/approvedoc/dev/` |
| `ionetiq.dev/approvedoc/` | `:ionetiq.dev/approvedoc/` |
| `approvedoc.app/dev/` | `:approvedoc.app/dev/` |
| `approvedoc.app/` | `:approvedoc.app/` |

## Keys That Are Scoped

| Key | Where |
|---|---|
| `app_accent:{suffix}` | Inline theme script + `_scopedKey()` in `sidebar-html.js` |
| `app_sidebar_bg:{suffix}` | Same |
| `app_active_organisation:{suffix}` | `_activeOrganisationKey()` in `auth.js` |

## Keys That Are NOT Scoped

| Key | Reason |
|---|---|
| `app_theme` | Theme preference shared across all environments for the same browser |
| `app_session` | Browser already isolates by origin; no path scoping needed |

## window._appRootUrl

Computed in the inline theme script at the top of every page:

```js
window._appRootUrl = (new URL(root, window.location.href)).href;
// e.g. 'https://approvedoc.app/dev/'
```

Used by `auth.js` for login redirects and by `SidebarHtml.inject()` for building sidebar links, ensuring they resolve correctly regardless of the page's own location.
