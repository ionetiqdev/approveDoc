# Supabase Auth Setup — ionetiq Standard Process

This document covers the steps required to configure Supabase authentication
for any ionetiq app that uses email-based login, invites, and password reset.

Completed and validated on: **approveDoc** (project `nkwpqboslnbeifyaegos`)

---

## 1. Supabase URL Configuration

In the **Supabase Dashboard → Authentication → URL Configuration**:

### Site URL
Set this to the primary login page for the app:
```
https://ionetiq.dev/{app}/dev/pages/auth/login.html
```

### Redirect URLs
Add both the dev and production login page URLs. Remove `localhost:*` and any
wildcard entries — these are the Supabase defaults and should be replaced with
exact paths:

```
https://ionetiq.dev/{app}/dev/pages/auth/reset-password.html
https://ionetiq.dev/{app}/pages/auth/reset-password.html
```

> **Why `reset-password.html` and not `login.html`?**
> Supabase embeds the token in the URL hash (`#access_token=...&type=recovery`).
> The `reset-password.html` page detects this hash, shows the "set new password"
> form, and redirects to login on success. Using `login.html` as the redirect
> would also work if the login page handles the hash — but keeping them separate
> is cleaner.

> **Note on other apps:** Each Supabase project has its own URL Configuration
> — changing one project's settings has no effect on others.

---

## 2. Edge Function — `manage-user`

This function handles user creation (invite), password update, and deletion
using the service role key. It must be deployed and have its secret set.

### Deploy the function
From the project root:
```
supabase functions deploy manage-user --project-ref {project-ref}
```

Or deploy via the Claude/MCP Supabase tool.

### Set the secret
The function uses `PROJECT_SERVICE_ROLE_KEY` (not `SUPABASE_SERVICE_ROLE_KEY` —
the `SUPABASE_` prefix is reserved by Supabase CLI and cannot be used for
custom secrets).

**Supabase Dashboard → Edge Functions → manage-user → Secrets tab:**

| Key | Value |
|---|---|
| `PROJECT_SERVICE_ROLE_KEY` | `eyJhbG...` (service_role JWT from Settings → API) |

Or via CLI:
```
supabase secrets set PROJECT_SERVICE_ROLE_KEY=eyJhbG... --project-ref {project-ref}
```

> The secret may take 30–60 seconds to propagate after setting.

---

## 3. Auth Pages Required

These pages must exist in `pages/auth/`:

### `login.html`
Standard login page. Must also handle the `#access_token` hash for email
confirmation (`type=signup`) so confirmed users are redirected to the app
automatically.

### `reset-password.html`
Dual-purpose page:
- **Step 1 (no hash):** Email field — sends a password reset email via
  `sb.auth.resetPasswordForEmail()` with `redirectTo` pointing back to itself
- **Step 2 (hash present):** Detects `#access_token=...&type=recovery` or
  `type=invite`, shows new password + confirm fields, calls `sb.auth.updateUser()`

The `redirectTo` in `resetPasswordForEmail` must use the current page's URL
dynamically so it works across dev and production:
```js
const redirectTo = window.location.origin + _appRoot() + 'pages/auth/reset-password.html';
```

### `set-password.html` (optional)
A simpler standalone password-set page used if `login.html` intercepts the hash
and redirects here. Can be used instead of Step 2 in `reset-password.html`.

---

## 4. Inviting Users from the App

Users are invited from **Admin → Users → Add User** (admin/super_admin only).

The invite flow:
1. Admin fills in name, email, role — organisation defaults to the current
   admin's own organisation automatically
2. Clicking **Send invite** calls the `manage-user` edge function with
   `action: 'create'`
3. The function calls `auth.admin.inviteUserByEmail()`, then creates both a
   `profiles` row and an `ad_user` row (or equivalent app-level user table)
   with the correct `organisation_id`
4. User receives an email, clicks the link, lands on `reset-password.html`,
   sets their password, and is redirected to login

### Key points
- The `redirectTo` passed in the invite must be in the Supabase allowed
  redirect URLs list
- The edge function must have `PROJECT_SERVICE_ROLE_KEY` set — without it the
  `auth.admin.*` calls fail silently with a 400 error
- Both `profiles` and the app-level user table must be created at invite time
  so the user appears in pickers immediately, before they log in

---

## 5. Database Trigger (Optional but Recommended)

A trigger on `auth.users` insert can automatically create app-level rows when
any user is created (including via the Supabase dashboard or CLI), not just
through the managed invite flow:

```sql
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, display_name, role, organisation_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    coalesce(new.raw_user_meta_data->>'role', 'user'),
    (new.raw_user_meta_data->>'organisation_id')::uuid
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

Pass `organisation_id` and `role` in `user_metadata` when creating users:
```js
await sb.auth.admin.inviteUserByEmail(email, {
  data: {
    full_name: 'Jane Smith',
    organisation_id: '...',
    role: 'user'
  },
  redirectTo: '...'
})
```

---

## 6. Common Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| Invite link goes to `localhost:3000` | Site URL not updated in Supabase | Update URL Configuration |
| `Save failed: {}` | Edge function returning 400 with no message | Deploy improved error handling; check `PROJECT_SERVICE_ROLE_KEY` secret |
| `Save failed: Insufficient permissions` | Caller's `profiles.role` is not `admin` or `super_admin` | Check the user's role in the `profiles` table |
| User invited but not in any org | `organisationId` was empty when invite sent | Ensure the modal pre-fills org from `Auth.getOrganisationId()` |
| User invited but missing from app pickers | Edge function only created `profiles`, not app-level user table | Update edge function to also insert into `ad_user` (or equivalent) |
| Password reset link expired | User waited too long | Resend invite from Admin → Users |

---

## 7. Checklist for a New Project

- [ ] Supabase URL Configuration — Site URL set, `localhost` removed, correct redirect URLs added
- [ ] `manage-user` edge function deployed
- [ ] `PROJECT_SERVICE_ROLE_KEY` secret set on the edge function
- [ ] `login.html`, `reset-password.html` exist and handle hash tokens
- [ ] Admin → Users page defaults `organisation_id` to current user's org
- [ ] Edge function creates both `profiles` and app-level user rows on invite
- [ ] Test: send invite → receive email → set password → log in → correct org
