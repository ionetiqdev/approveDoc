# Template tokens - what substitutes when

This template uses two completely different kinds of `{{TOKEN}}`
placeholder, resolved at two different times, by two different
mechanisms. Mixing these up would either leak nothing (fine) or bake
in stale values forever (not fine) - worth being precise about which
is which before building any tooling (a SKILL.md, a script, anything)
that does substitution across this repo.

## Category 1: resolved ONCE, at project-creation time, by the interview

These get replaced with real, permanent plain text the moment a new
project is created from this template. They never appear again in the
real project - not in git history, not in deployed files, not
anywhere. There's no ongoing templating mechanism; once substituted,
they're just text.

| Token | Resolved from | Appears in |
|---|---|---|
| `{{PROJECT_NAME}}` | App name interview answer | Every HTML page title/brand, JS file header comments, theme.css header comment |
| `{{PROJECT_CODE}}` | Project short code interview answer | PROMOTE.md, deploy.bat's zip-naming convention reference, docs |
| `{{COMPANY_NAME}}` | Company name interview answer | Page footers (login, reset-password) |
| `{{CURRENT_YEAR}}` | The actual year the project is created | Page footers (login, reset-password) |

A safe substitution pass replaces ALL occurrences of these four exact
tokens, repo-wide, with the interview's answers. There's no file where
leaving one of these four unresolved would be correct.

## Category 2: resolved EVERY DEPLOY, by GitHub Actions, from repo secrets

These are NEVER touched by the project-creation interview and NEVER
written to a file on disk with their real value, by Claude or
deploy.bat or anyone else. They stay as literal `{{TOKEN}}` text in
the committed file forever - that's correct, not a bug.

| Token | Resolved from | Appears in |
|---|---|---|
| `{{SUPABASE_URL}}` | GitHub Actions secret `SUPABASE_URL` | `assets/js/supabase-client.js` only |
| `{{SUPABASE_ANON_KEY}}` | GitHub Actions secret `SUPABASE_ANON_KEY` | `assets/js/supabase-client.js` only |

The substitution happens in `.github/workflows/deploy.yml`'s "Inject
Supabase credentials" step, on the checked-out runner copy, immediately
before the FTP upload step. The real values exist only on the live
deployed site - never in git, never in a zip, never in `project.conf`.

**If you're writing a substitution script: exclude these two tokens
explicitly.** A naive "replace every `{{...}}` in the repo" pass would
either fail (no real value available at project-creation time) or,
worse, if someone mistakenly fed it real credentials at that stage,
would commit secrets straight into git history.

## Not a token at all

`docs/NEW-PROJECT.md` and this file both contain the literal text
`{{PLACEHOLDER}}` in explanatory prose, describing the general concept
of a template token - not an actual token meant to be substituted.
Any substitution tooling should match the exact four Category 1 token
names and the exact two Category 2 token names, not a generic
`{{ANYTHING}}` pattern, or it will mangle this documentation.
