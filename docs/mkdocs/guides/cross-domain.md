# Cross-Domain Authentication

## The Problem

approveDoc is deployed at `ionetiq.dev/approvedoc/` but is also accessible at `approvedoc.app/` (same server, same folder). Each domain is a different browser origin, so localStorage is completely isolated — a user logged in on `ionetiq.dev` is not logged in on `approvedoc.app`.

More critically: `sb.auth.setSession()` in Supabase JS v2 does not always propagate the access token to the client's internal query state on a new origin. This means `sb.from('profiles').select('*')` runs as anonymous and returns nothing, even though the session was successfully restored from localStorage.

Symptoms:
- "No profile row found" warning in console
- All nav items hidden (role not loaded)
- No organisation shown

## The Fix

In `auth.js`, after `setSession()` succeeds:

```js
// Create a second Supabase client with the token hardcoded in Authorization header
window._authenticatedSb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  global: { headers: { Authorization: 'Bearer ' + data.session.access_token } },
  auth:   { persistSession: false, autoRefreshToken: false }
});

// Override sb.from to route all table queries through the authenticated client
sb.from = (table) => window._authenticatedSb.from(table);
```

This patch is applied once and persisted on `window`. All subsequent `sb.from(...)` calls throughout the app automatically carry the correct token.

## Profile Load Fallback

`_loadProfile()` has a second level of fallback:

```js
// Level 1: patched sb.from (should work in most cases)
const { data } = await sb.from('profiles').select('*').eq('id', userId).maybeSingle();
if (data) return data;

// Level 2: raw fetch with explicit Authorization header
const res = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=*`, {
  headers: {
    'apikey':        SUPABASE_ANON_KEY,
    'Authorization': 'Bearer ' + saved.access_token,
    'Accept':        'application/vnd.pgrst.object+json',
  }
});
```

## Supabase Configuration Required

Add these redirect URLs in Supabase Dashboard → Authentication → URL Configuration:

```
https://approvedoc.app/pages/auth/reset-password.html
https://approvedoc.app/dev/pages/auth/reset-password.html
https://ionetiq.dev/approvedoc/pages/auth/reset-password.html
https://ionetiq.dev/approvedoc/dev/pages/auth/reset-password.html
```
