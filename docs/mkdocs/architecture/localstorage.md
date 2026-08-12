# localStorage Isolation

approveDoc uses `localStorage` for session storage, theme preferences, accent colour, and sidebar colour. These must be isolated between environments and domains.

## Why isolation is needed

| Environment | Path |
|---|---|
| Dev (ionetiq.dev) | `ionetiq.dev/approvedoc/dev/` |
| Production (ionetiq.dev) | `ionetiq.dev/approvedoc/` |
| Dev (approvedoc.app) | `approvedoc.app/dev/` |
| Production (approvedoc.app) | `approvedoc.app/` |

Without isolation, changing the accent colour on dev would change it on production (same origin, same key).

## Strategy

All preference keys are suffixed with `hostname + absoluteRoot`:

```
app_accent:ionetiq.dev/approvedoc/dev/      ← dev on ionetiq.dev
app_accent:ionetiq.dev/approvedoc/          ← prod on ionetiq.dev
app_accent:approvedoc.app/dev/              ← dev on approvedoc.app
app_accent:approvedoc.app/                  ← prod on approvedoc.app
```

## Session key

`app_session` is **not** suffixed. The browser already isolates localStorage by origin (`ionetiq.dev` vs `approvedoc.app` are different origins with separate stores). Within the same origin, environments share the session key — this is intentional so logging into dev doesn't log you out of production.

## Where suffix is applied

| Location | Key |
|---|---|
| Inline theme script (every page) | `app_accent`, `app_sidebar_bg` |
| `sidebar-html.js` → `_scopedKey()` | Preferences save/load |
| `auth.js` → `_activeOrganisationKey()` | Active organisation per env |

## `window._appRootUrl`

Computed in the inline theme script, `_appRootUrl` is the absolute URL to the app root (e.g. `https://approvedoc.app/dev/`). It is used by:

- `auth.js` — for login redirects (`_redirectToLogin()`)
- `SidebarHtml.inject()` — so sidebar links resolve correctly regardless of the page's location
- Page init scripts — `SidebarHtml.inject(window._appRootUrl || '../../')`
