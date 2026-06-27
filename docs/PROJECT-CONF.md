# project.conf - field reference

`project.conf` holds this specific project's local settings for
`deploy.bat`. Copy `project.conf.example` to `project.conf` (drop the
`.example`) and fill in real values - or just run `deploy.bat` once
and it'll ask you for anything missing and save your answers, so you
only get asked per value, ever.

**`project.conf` is gitignored** - never committed, never pushed,
never uploaded by FTP. It only ever lives on your machine.

**Nothing in this file is a secret.** FTP password, FTP username,
Supabase URL, Supabase keys, and any Supabase service-role key live
ONLY as GitHub Actions repo secrets (set once via GitHub's web UI -
see `docs/NEW-PROJECT.md`) and never appear here or in git history.

## Fields

| Field | Meaning |
|---|---|
| `APP_NAME` | Full display name - page titles, sidebar brand, login screen. e.g. `Acme Risk Register` |
| `PROJECT_CODE` | Lowercase, no spaces. Prefix on every build zip (`PROJECT_CODE_DDMMYYYY_HHmm.zip`) and the FTP folder name (`public_html/PROJECT_CODE/`) |
| `TEMPLATE_VERSION_AT_CREATION` | Which template version (see `TEMPLATE-VERSION.txt`/`docs/TEMPLATE-CHANGELOG.md`) this project was originally built from. Set once, never auto-updates - a historical record for deciding what to pull in later, see `docs/UPDATING-PROJECTS.md`. **Not currently read or written by `deploy.bat` itself** - tracked by hand. |
| `COMPANY_NAME` | Shown in page footers, e.g. `ionetiq` |
| `DOWNLOADS_DIR` | Where Claude's build zips land when you save them. Blank defaults to your Windows Downloads folder. |
| `WORKING_DIR` | This project's actual root on disk - where `deploy.bat` runs from. Blank defaults to wherever `deploy.bat` is currently run from (the normal case). |
| `GITHUB_REPO_URL` | e.g. `https://github.com/ionetiqdev/acme-risk.git` |
| `SUPABASE_PROJECT_NAME` | Reference label only, e.g. `acme-risk` - not used to connect to anything, not a secret. |

## What's deliberately NOT here

FTP and Supabase credentials are set once per repo as GitHub Actions
secrets (Settings → Secrets and variables → Actions) - see
`docs/NEW-PROJECT.md` for exact steps. `deploy.bat` will remind you
of this the first time you run it for a new project, and never asks
you to type them here. The required secret names:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `FTP_HOST`
- `FTP_USERNAME`
- `FTP_PASSWORD`
- `SLACK_WEBHOOK_URL` (optional - omit to skip Slack notify)
