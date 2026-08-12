# supabase-client.js

Sets up the Supabase JS client and session management. Loaded first among the app modules.

## Exports (all on `window`)

| Export | Type | Description |
|---|---|---|
| `sb` | Supabase client | Main client instance — use everywhere |
| `AppSession` | Object | Session persistence helpers |
| `SUPABASE_URL` | String | Project URL (substituted at deploy time) |
| `SUPABASE_ANON_KEY` | String | Anon key (substituted at deploy time) |

!!! warning "Placeholder values"
    `SUPABASE_URL` and `SUPABASE_ANON_KEY` are `{{SUPABASE_URL}}` / `{{SUPABASE_ANON_KEY}}` in source. `deploy.bat` substitutes real values. Never hardcode these.

## AppSession

```js
AppSession.save(session)   // Persist Supabase session to localStorage
AppSession.load()          // Returns parsed session object or null
AppSession.clear()         // Removes session from localStorage
```

Session is stored under the key `'app_session'` — a plain name chosen to avoid browser extension pattern matching on common patterns like `supabase.auth.token`.

## Storage adapter

The Supabase client is configured with a custom storage adapter that wraps `localStorage` with try/catch blocks. This prevents errors in private browsing modes or when localStorage is blocked.

```js
const _store = {
  getItem(key)        { try { return localStorage.getItem(key); }   catch(e) { return null; } },
  setItem(key, value) { try { localStorage.setItem(key, value); }   catch(e) {} },
  removeItem(key)     { try { localStorage.removeItem(key); }        catch(e) {} }
};
```

## Session format

Sessions are stored as JSON with the structure Supabase expects:

```json
{
  "access_token": "...",
  "token_type": "bearer",
  "expires_in": 3600,
  "expires_at": 1234567890,
  "refresh_token": "...",
  "user": { ... }
}
```
