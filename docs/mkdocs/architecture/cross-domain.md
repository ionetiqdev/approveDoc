# Cross-Domain Compatibility

approveDoc is hosted at `ionetiq.dev/approvedoc/` but also accessible at `approvedoc.app/` — a DNS alias pointing to the same server and folder.

## The problem

Supabase JS v2's `sb.auth.setSession()` does not always propagate the access token to the client's internal query state when called on a new origin. This causes `sb.from('profiles').select('*')` to run as anonymous and return nothing — even though the session was successfully restored — resulting in:

- Missing profile → role defaults to `view`
- Missing organisation → no data loads
- Sidebar nav items all hidden

## The fix

After `setSession()` succeeds, `auth.js` creates a second Supabase client with the access token hardcoded in a global `Authorization` header, then patches `sb.from` to route all table queries through it:

```js
window._authenticatedSb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  global: { headers: { Authorization: 'Bearer ' + data.session.access_token } },
  auth:   { persistSession: false, autoRefreshToken: false }
});

// All sb.from(...) calls now use the authenticated client
sb.from = (table) => window._authenticatedSb.from(table);
```

This patch is applied once and persisted on `window`. All subsequent `sb.from(...)` calls throughout the app automatically carry the correct token, regardless of domain.

## Profile fetch fallback

`_loadProfile()` also has a raw `fetch()` fallback with the access token in the `Authorization` header directly, for cases where even the patched client query returns nothing during the brief window before the patch applies:

```js
const res = await fetch(
  `${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=*`,
  {
    headers: {
      'apikey':        SUPABASE_ANON_KEY,
      'Authorization': 'Bearer ' + saved.access_token,
      'Accept':        'application/vnd.pgrst.object+json',
    }
  }
);
```

## Supabase configuration required

For `approvedoc.app` to work fully, the following must be configured in Supabase Dashboard → Authentication → URL Configuration:

```
https://approvedoc.app/pages/auth/reset-password.html
https://approvedoc.app/dev/pages/auth/reset-password.html
https://ionetiq.dev/approvedoc/pages/auth/reset-password.html
https://ionetiq.dev/approvedoc/dev/pages/auth/reset-password.html
```

See [Supabase Auth Setup](../guides/supabase-auth-setup.md) for full details.
