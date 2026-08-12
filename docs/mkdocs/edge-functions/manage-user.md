# manage-user Edge Function

**Endpoint:** `POST /functions/v1/manage-user`  
**Auth:** JWT required (caller must be admin or super_admin)

Handles user lifecycle operations that require service role access, bypassing RLS.

## Actions

### create

Creates a new user by invitation.

```json
{
  "action": "create",
  "email": "user@example.com",
  "display_name": "Jane Smith",
  "role": "user",
  "job_title": "Analyst",
  "redirect_to": "https://approvedoc.app/dev/pages/auth/reset-password.html",
  "organisation_id": "..."
}
```

**What it does:**
1. Calls `supabase.auth.admin.inviteUserByEmail()` — sends invite email with link to `redirect_to`
2. Creates `profiles` row with display name, role, job title
3. Creates `ad_user` row for the organisation

### update_password

Updates a user's password (admin action).

```json
{
  "action": "update_password",
  "user_id": "...",
  "password": "..."
}
```

### delete

Deletes a user from `auth.users`. Cascades to `profiles` and `ad_user`.

```json
{
  "action": "delete",
  "user_id": "..."
}
```

## Notes

- The `organisation_id` defaults to the caller's own organisation if not specified
- The invite email link uses Supabase's built-in invite flow — the user clicks the link and is directed to `set-password.html` or `reset-password.html` to set their password
