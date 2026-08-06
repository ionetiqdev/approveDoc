# approveDoc mobile

Capacitor + Ionic web components (framework-agnostic, not the React/Vue/Angular flavour) on plain JS. See `../docs/adr/ADR-mobile-app-capacitor.md` (or wherever the ADR ends up living) for the architectural decisions behind these choices.

## What's real vs. stub right now

**Wired up:**
- `src/lib/supabase-client.js` — Supabase client using `@capacitor/preferences` for session storage (Keychain/Keystore, not localStorage)
- `src/lib/theme.js` — light/dark theme, follows system on first install, falls back to light, persists once set explicitly
- `src/screens/signin.js` — real `signInWithPassword`
- `src/screens/forgot-password.js` — real `resetPasswordForEmail` (redirect URL is a placeholder, see below)
- `src/screens/dashboard.js` — real greeting + real overdue/pending/done counts from `ad_distribution_item`, admin-only Insights nav item driven by `ad_user.role_admin`

**Stubs (layout/interaction already decided in the mockups, not yet wired to data):**
- `src/screens/unlock.js` — biometric UI shell; no native biometric plugin chosen yet
- `src/screens/documents.js`, `document-detail.js`, `profile.js`, `admin-insights.js`

## Placeholders that need real values before this runs against your project

- Copy `.env.example` to `.env.local` (gitignored) and fill in `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`. **This is required even for `npm run dev`** — `createClient()` throws immediately on an invalid URL, which is why the app shows a blank page if this step is skipped (check the browser console — you'll see "Invalid supabaseUrl" if so).
- `VITE_PASSWORD_RESET_REDIRECT_URL` in the same file — open ADR question, needs a decision on Supabase's default hosted reset page vs. a branded page on `ionetiq.dev`

## Running it

```
cd mobile
cp .env.example .env.local   # then fill in real values
npm install
npm run dev        # browser preview at localhost, screens work but no native APIs (Preferences/etc. fall back to web implementations)
```

## Adding native platforms

`npx cap add ios` / `npx cap add android` need Xcode / Android Studio respectively — **can't be run from this sandboxed build environment**, needs to happen on your machine:

```
npm run build       # produces dist/
npx cap add ios
npx cap add android
npx cap sync
npm run cap:ios      # opens Xcode
npm run cap:android  # opens Android Studio
```

## Known gaps / next decisions

- Router is a minimal function-based screen switcher (no history stack, no native back-button wiring) — fine for now, may need `ion-router` once gesture/back-button parity with native matters
- Biometric plugin not chosen (e.g. `@capgo/capacitor-native-biometric`)
- Push notification provider not chosen (native APNs/FCM vs. OneSignal)
- Remaining open questions tracked in the ADR
