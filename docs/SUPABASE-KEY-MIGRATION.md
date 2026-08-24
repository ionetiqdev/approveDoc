# Supabase API Key Migration Guide

## Background

Supabase is deprecating JWT-based `anon` and `service_role` keys by end of 2026.
The new keys are:

| Old | New | Used in |
|---|---|---|
| `anon` key | `sb_publishable_...` | Browser / client code |
| `service_role` key | `sb_secret_...` | Server / Edge Functions only |

Both work simultaneously during migration. Creating new keys does not revoke old ones.

## Is an exposed anon / publishable key a security issue?

No — it is designed to be public. RLS (Row Level Security) controls what it can access.
Do NOT rotate just because a scanner found it in JavaScript.

What IS a security issue:
- A `service_role` / `sb_secret_` key in browser code or committed to git
- Any key committed to git (rotation headache, even if low risk)

---

## Steps to migrate any ionetiq project

### 1. Create new keys in Supabase dashboard

For each Supabase project (production AND dev):

1. Go to **Settings → API Keys**
2. Click **Create new API Keys**
3. Copy the **Publishable key** (`sb_publishable_...`) — replaces anon key
4. Copy the **Secret key** (`sb_secret_...`) — replaces service_role key (Edge Functions only)

### 2. Update project.conf

Replace anon key values with publishable keys:

```
SUPABASE_ANON_KEY_MAIN=sb_publishable_...
SUPABASE_ANON_KEY_DEV=sb_publishable_...
```

No code changes needed — the variable name stays the same, just the value changes.

### 3. Update GitHub Secrets

Go to GitHub repo → **Settings → Secrets and variables → Actions**:

| Secret | New value |
|---|---|
| `SUPABASE_ANON_KEY` | `sb_publishable_...` (production) |
| `SUPABASE_ANON_KEY_DEV` | `sb_publishable_...` (dev) |

The `supabase-client.js` placeholder `{{SUPABASE_ANON_KEY}}` stays unchanged.

### 4. Update Edge Function environment (if applicable)

In Supabase dashboard → **Edge Functions → Secrets**:
- `PROJECT_SERVICE_ROLE_KEY` → replace with `sb_secret_...`

### 5. Fix committed secrets (security findings)

These files should NEVER be committed:

```gitignore
project.conf
mobile/.env.local
mobile/dist/
mobile/android/app/build/
supabase/create-real-users.js
```

Remove from git tracking (without deleting the files):
```cmd
git rm --cached project.conf
git rm --cached mobile/.env.local
git rm --cached supabase/create-real-users.js
git rm -r --cached mobile/dist/
git rm -r --cached mobile/android/app/build/
git commit -m "Remove committed secrets from git tracking"
```

### 6. Disable legacy keys (optional, when ready)

Once all deployments are using new keys:
1. Supabase dashboard → **Settings → API Keys → Legacy API Keys**
2. Disable the anon key
3. Disable the service_role key

This is reversible — you can re-enable them if needed.

---

## Files to check in any ionetiq project

| File | Should contain |
|---|---|
| `assets/js/supabase-client.js` | `{{SUPABASE_ANON_KEY}}` placeholder only — never a real key |
| `project.conf` | Real keys — gitignored, never committed |
| `project.conf.example` | Placeholder values only — safe to commit |
| `.github/workflows/deploy.yml` | References `${{ secrets.SUPABASE_ANON_KEY }}` — never hardcoded |
| `mobile/.env.local` | Real keys — gitignored, never committed |

---

## .gitignore additions for all ionetiq projects

Add these to `.gitignore` if not already present:

```
project.conf
mobile/.env.local
mobile/dist/
mobile/android/app/build/
mobile/android/app/src/main/assets/
supabase/create-real-users.js
*.env
*.env.local
```
