# auth.js

The authentication and authorisation module. Everything auth-related goes through `Auth.*`.

## Role model

| Role | Access |
|---|---|
| `super_admin` | All organisations. ionetiq team only. |
| `admin` | One organisation. Full admin functions. |
| `user` | One organisation. Editing capability. |
| `view` | One organisation. Read-only. |

!!! danger "Fixed role strings"
    Role values are fixed — they are referenced directly in RLS policies. Do not rename or add roles without updating every RLS policy that checks `_my_role()`.

## Public API

### Authentication

```js
await Auth.requireAuth()
```
Call at the top of every protected page. Loads session, profile, and active organisation. Redirects to login if unauthenticated. Returns the Supabase session object or `null`.

```js
await Auth.requireGuest()
```
Call on the login page. Redirects to dashboard if already authenticated.

```js
await Auth.signOut()
```
Signs out and redirects to login.

### Session & profile

```js
Auth.getSession()           // Supabase session object
Auth.getProfile()           // profiles row for the current user
Auth.getOrganisationId()    // UUID of the currently active organisation
```

### Role checks

```js
Auth.isSuperAdmin()   // true if role === 'super_admin'
Auth.isAdmin()        // true if role is 'admin' or 'super_admin'
Auth.canEdit()        // true if role is 'user', 'admin', or 'super_admin'
```

### Organisation switcher (super_admin only)

```js
await Auth.setActiveOrganisation(orgId)   // Switch active org; returns bool
await Auth.getAllOrganisations()           // All org rows
```

### User preferences

Stored in `profiles.preferences` (JSONB column).

```js
Auth.getPreference(key, defaultValue)
await Auth.setPreference(key, value)
```

Example:
```js
// Save a preference
await Auth.setPreference('docViewerPrefs', { upload: { dropZone: false } });

// Read it back (with default)
const prefs = Auth.getPreference('docViewerPrefs', null);
```

### UI refresh

```js
Auth.refreshUI()
```

Re-runs role-based element reveal and user name/initials/role fill-in. Must be called after `SidebarHtml.inject()` on every page.

## requireAuth() flow

```mermaid
flowchart TD
    A[requireAuth called] --> B{AppSession.load()}
    B -- null --> C[Redirect to login]
    B -- session --> D[sb.auth.setSession]
    D -- error --> E[Clear session + redirect]
    D -- ok --> F[Patch sb.from]
    F --> G[_loadProfile]
    G -- no profile --> H[Default to view role]
    G -- profile --> I[_resolveActiveOrganisation]
    H --> I
    I --> J[_applyUserUI]
    J --> K[Return session]
```

## Cross-domain patch

After `setSession()` succeeds, `auth.js` patches `sb.from` to route all queries through an authenticated client with an explicit `Authorization` header. See [Cross-Domain Compatibility](../architecture/cross-domain.md) for full details.

## _applyUserUI() / Auth.refreshUI()

Updates the DOM with the current user's information:

- `[data-user-name]` — filled with display name
- `[data-user-email]` — filled with email
- `[data-user-role]` — filled with formatted role (e.g. "Super Admin")
- `[data-user-initials]` — avatar image or initials
- `[data-active-organisation]` — org name or switcher dropdown
- `[data-require-role="..."]` — `role-hidden` class removed for matching roles

## Organisation resolution

| User type | Resolution |
|---|---|
| Non-super-admin | Always `profiles.organisation_id` — fixed, can't be changed |
| Super-admin | Last-picked org from localStorage (scoped key), defaulting to alphabetically-first |
