# Authentication

## Login flow

1. User submits email + password on `pages/auth/login.html`
2. Calls `sb.auth.signInWithPassword()`
3. On success, `AppSession.save(session)` stores the session in localStorage under `'app_session'`
4. Redirects to `index.html`

## Session restoration

On every protected page, `Auth.requireAuth()`:

1. Calls `AppSession.load()` to retrieve the stored session
2. If no session → redirects to `pages/auth/login.html`
3. Calls `sb.auth.setSession({ access_token, refresh_token })`
4. If `setSession` fails (token expired) → clears session, redirects to login
5. Patches `sb.from` to use authenticated client ([cross-domain fix](../architecture/cross-domain.md))
6. Loads profile via `_loadProfile()` (with explicit fetch fallback)
7. Resolves active organisation
8. Returns session object

## Password reset

`pages/auth/reset-password.html` is dual-purpose:

- **Without URL token:** Shows "Request password reset email" form
- **With `#access_token` hash:** Shows "Set new password" form

## First-time password set (invite)

`pages/auth/set-password.html` is used after an admin invites a new user. The invite email links here with the Supabase access token in the URL hash.

## Sign out

```js
await Auth.signOut()
// Calls sb.auth.signOut(), clears AppSession, redirects to login
```

Or via any element with `[data-action="signout"]` in the DOM — auth.js wires this automatically.
