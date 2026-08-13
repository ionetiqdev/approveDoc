# Mobile dev workflow - npm run dev explained

## Do you need to stop and restart it after every zip drop?

No. Leave it running the whole time.

`npm run dev` (via Vite) watches your files. The moment `deploy-mobile.bat`
overwrites files on disk, Vite notices and automatically reloads the page
in your browser - no need to touch the terminal or re-run anything.

**Practical routine:**
1. Leave `npm run dev` running in its own terminal window, permanently,
   while iterating on the app.
2. Run `deploy-mobile.bat` in a *separate* terminal/window.
3. Glance back at the browser tab - it should refresh itself within a
   second or two.
4. If it ever doesn't auto-refresh (rare), a manual browser refresh
   (Ctrl+F5) always works as a fallback.

## The one real exception - when you DO need to restart

If a change touches either of these, Vite only reads them at startup, so
a restart is genuinely needed:

- `mobile/package.json` (new dependencies added)
- `mobile/.env.local` (environment variables changed)

A plain code change to a `.js` file never needs a restart.

## What `npm run dev` is actually doing

It runs the `dev` script defined in `mobile/package.json`, which launches
**Vite** - a local development web server. Concretely:

- Serves your `src/` files at `localhost:5173`, transforming modern JS on
  the fly as the browser requests it (all in-memory, nothing written to
  disk)
- Watches every file for changes and pushes updates to the browser
  automatically (the auto-refresh behaviour above)
- Local preview only - this server exists purely on your PC, nothing
  here is deployed or accessible to anyone else

## npm run dev vs. npm run build - different purposes

| | `npm run dev` | `npm run build` |
|---|---|---|
| Purpose | Fast iteration loop while building | Produces the real, deployable artifact |
| Output | Nothing written to disk - served live from memory | Optimized files written to `mobile/dist/` |
| Speed | Instant reload on save | Takes a few seconds, run on demand |
| What it's for | Previewing changes as we build screens | What eventually gets bundled into the real iOS/Android app via Capacitor (`npx cap sync` reads from `dist/`) |

Short version: `dev` is for looking at it right now; `build` is for
making the thing that actually ships.
