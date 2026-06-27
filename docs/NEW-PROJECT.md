# Building a new project from this template - step by step

This is the complete, ordered process for turning this template into
a real, working, deployed project for a new client. Follow it in
order - several steps depend on an earlier one having actually
finished (e.g. you can't set GitHub secrets that reference a Supabase
project before that project exists).

Each step says who does it - "Claude" steps happen by talking to
Claude in this same kind of conversation; "You" steps happen on your
own machine or in a web dashboard, because Claude has no way to do
them (no GitHub write access, no way to type into Supabase's billing
flow, etc).

---

## 1. The interview (Claude)

Tell Claude you want to start a new project from the template. Claude
will ask you for (and this is also the moment to double check nothing
is missing - see `docs/TEMPLATE-CHANGELOG.md` for anything added since
this list was last reviewed):

- **App name** - shown in page titles, sidebar brand, login screen
- **Project short code** - lowercase, no spaces, becomes the zip
  filename prefix and the FTP folder name
- **Company name** - shown in page footers
- **Downloads directory** - where Claude's build zips will land on
  your machine
- **Working directory** - where this project actually lives on disk
- **GitHub repo URL** - you create an empty repo first (step 2),
  then give Claude its URL
- **Which sub-systems to include** - Documents, Issues, and any
  others added since (see `docs/SUBSYSTEMS.md`)

Claude resolves every `{{PROJECT_NAME}}`/`{{PROJECT_CODE}}`/
`{{COMPANY_NAME}}`/`{{CURRENT_YEAR}}` token in the generated files to
real text at this point - there's no ongoing templating mechanism
left in the real project afterward.

**Check:** ask Claude to confirm the full list of values it used, and
that `TEMPLATE_VERSION_AT_CREATION` in `project.conf` was set to
match the current `TEMPLATE-VERSION.txt` in the template repo - this
is what lets you (or Claude, later) work out what's changed in the
template since this project was created.

## 2. Create the GitHub repository (You)

Create a new, empty repository on GitHub (no README, no .gitignore -
the template brings its own). Give Claude the URL.

From the project's working directory, once you have the first build
zip from Claude:

```
git init
git add -A
git commit -m "Initial project baseline"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

**Check:** the repo on GitHub shows all the template's files.

## 3. Create the Supabase project (You, or Claude - test first)

Claude can sometimes create the Supabase project and run migrations
directly via its own Supabase tool access - ask it to try this first
rather than assuming it will or won't work. If it can't, or you'd
rather do it yourself:

1. Create a new Supabase project.
2. In the SQL Editor, run the migrations in `/supabase/` **in this
   exact order**:
   - `01-core-schema.sql`
   - `02-documents.sql` (skip if this project doesn't use Documents)
   - `03-issues.sql` (skip if this project doesn't use Issues)
   - `04-sample-data.sql` (optional - gives the template a real
     `template_customer` table and 10 sample rows to look at
     immediately; run `04-sample-data-cleanup.sql` later to remove it)
3. Open `07-lookup-data.sql`, edit it with this project's real
   values (project areas, issue types if you want to override the
   defaults, document categories, the team members who'll work
   issues), then run your edited version.

**Check:** Table Editor shows `organisations`, `profiles`, and
whichever sub-system tables you ran. Storage shows `user-avatars`
(public) and, if Documents is in use, `documents` (private).

## 4. Create your first super_admin user (You)

There's no super_admin until you make one - the app has no way to
bootstrap this itself.

1. Supabase dashboard → Authentication → Users → Add user. Set a
   password directly (no need for the invite-email flow for this
   first user).
2. Copy that user's UID.
3. In the SQL Editor:
   ```sql
   insert into public.profiles (id, display_name, email, role, organisation_id)
   values ('PASTE-THE-USER-UID-HERE', 'Your Name', 'your@email.com', 'super_admin', null);
   ```
   `organisation_id` must be `null` for a `super_admin` - the schema
   enforces this as a hard constraint.

**Check:** you can log into the deployed site (once step 6 is done)
with this account and see the full Admin menu.

## 5. Set up GitHub Actions secrets and variables (You)

On the GitHub repo: **Settings → Secrets and variables → Actions**.

**Secrets** tab:

| Secret name | Value |
|---|---|
| `SUPABASE_URL` | Your Supabase project's URL, `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase dashboard → Settings → API Keys → anon/public key |
| `FTP_HOST` | Your FTP hostname |
| `FTP_USERNAME` | FTP username |
| `FTP_PASSWORD` | FTP password |
| `SLACK_WEBHOOK_URL` | (Optional) a Slack incoming webhook, for deploy notifications |

**Variables** tab:

| Variable name | Value |
|---|---|
| `PROJECT_CODE` | Same short code given to Claude in step 1 - controls the FTP folder name |
| `SLACK_NOTIFY` | `true` if you set `SLACK_WEBHOOK_URL` above, otherwise leave unset |

None of this ever appears in `project.conf` or git history.
`supabase-client.js` is committed with literal `{{SUPABASE_URL}}` /
`{{SUPABASE_ANON_KEY}}` text in it - correct and expected. GitHub
Actions substitutes the real values only on the checked-out runner
copy, right before the FTP upload step.

**Check:** both tabs show all the rows above.

## 6. Deploy the manage-user Edge Function (You)

**Do this before testing the Users page** - creating, deleting, or
changing a user's password all depend on it, and skipping this step
produces a confusing CORS error that looks unrelated to the real
cause (the function simply doesn't exist yet).

From the project's working directory (needs the
[Supabase CLI](https://supabase.com/docs/guides/cli) installed):

```
supabase login
supabase link --project-ref <your-project-ref>
supabase secrets set PROJECT_SERVICE_ROLE_KEY=<your-service-role-key>
supabase functions deploy manage-user
```

- `<your-project-ref>` is the short ID in your Supabase URL.
- `<your-service-role-key>` is in Supabase dashboard → Settings →
  API Keys → Secret Keys section (never the anon key, never
  committed anywhere).
- The secret name is `PROJECT_SERVICE_ROLE_KEY`, not
  `SUPABASE_SERVICE_ROLE_KEY` - the Supabase CLI rejects any secret
  starting with the reserved `SUPABASE_` prefix.
- `SUPABASE_URL`/`SUPABASE_ANON_KEY` don't need setting here -
  Supabase auto-injects those into every Edge Function already.

**Check:** Supabase dashboard → Edge Functions shows `manage-user` as
active.

## 7. First deploy (You)

Save the build zip Claude gives you to the Downloads directory from
step 1, then from the working directory:

```
deploy.bat dev
```

This finds the zip, extracts it, regenerates cache-busting/
`version.js`, commits, and pushes to `dev` - which triggers GitHub
Actions to build and FTP-deploy it.

**Check:** GitHub → Actions tab shows a successful run; the site is
live at `public_html/{{PROJECT_CODE}}/dev/`; you can log in with the
super_admin account from step 4 and the dashboard/sidebar render
correctly.

## 8. Promote to production (You, when ready)

Once `dev` looks right, see `PROMOTE.md` for moving it to `main`
(production) - never run `deploy.bat main` directly except for this
very first deploy if you want to skip dev entirely, which isn't
recommended.

---

## After all of this

Every future build is just: Claude hands you a zip, you run
`deploy.bat dev`, test, promote when ready. Steps 5 and 6 above are
one-time, per-project setup - you won't repeat them unless you rotate
a secret or change hosting/Supabase providers.
