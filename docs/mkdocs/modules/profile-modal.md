# profile-modal.js

Helper for the avatar upload flow in the Preferences modal (Current User tab).

## What it does

- Handles file selection via the avatar click target in the Preferences modal
- Validates the selected file (image type, size)
- Uploads to the `user-avatars` Supabase storage bucket
- Path: `{userId}/avatar.png`
- Adds cache-busting `?t={timestamp}` to the URL after upload
- Updates `profiles.avatar_url` in the database
- Refreshes the avatar display in the header without a page reload

No public API — initialised automatically when `sidebar-html.js` is loaded.
