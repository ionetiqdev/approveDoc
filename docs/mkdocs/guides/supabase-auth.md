# Supabase Auth Setup

See `docs/SUPABASE-AUTH-SETUP.md` in the project root for the full guide.

## Key Configuration

In Supabase Dashboard → Authentication → URL Configuration:

**Site URL:**
```
https://ionetiq.dev/approvedoc/
```

**Additional Redirect URLs:**
```
https://ionetiq.dev/approvedoc/pages/auth/reset-password.html
https://ionetiq.dev/approvedoc/dev/pages/auth/reset-password.html
https://approvedoc.app/pages/auth/reset-password.html
https://approvedoc.app/dev/pages/auth/reset-password.html
```

## profiles RLS — Critical Policy

The `profiles` table needs a policy that lets users read their own row by `auth.uid()`:

```sql
create policy "Users: view own profile"
  on public.profiles for select
  using (auth.uid() = id);
```

Without this, super_admin users (whose `organisation_id` is null) can't load their profile from cross-domain origins, causing the "no profile row found" error.
