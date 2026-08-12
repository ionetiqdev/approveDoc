# Users (Admin)

**File:** `pages/admin/users.html`

Admin user management — create (invite), edit, and delete users within the active organisation.

## Invite flow

Calls the `manage-user` Edge Function with `action: 'create'`:

1. Creates `auth.users` entry (Supabase sends the invite email)
2. Creates `profiles` row with the specified display name, role, job title
3. Creates `ad_user` row for the organisation
4. Email includes a link to `pages/auth/reset-password.html` where the user sets their password

## Manager field

Type-ahead picker for `ad_user.manager_id`. Searches by display name or email.

## Top-level manager toggle

When "Top-level manager" is checked:
- `is_top_level = true` is saved to `ad_user`
- `manager_id` is cleared and set to `null`
- The manager picker field is hidden

When unchecked, the manager picker is shown and `is_top_level = false`.
