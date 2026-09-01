# Development Workflow

## Environments

| Environment | URL | Branch | Supabase project |
|---|---|---|---|
| Production | `approvedoc.app` / `ionetiq.dev/approvedoc/` | `main` | `nkwpqboslnbeifyaegos` |
| Development | `approvedoc.app/dev/` / `ionetiq.dev/approvedoc/dev/` | `dev` | dev project (separate) |

## Day-to-day development

```
1. Work on code changes locally
2. Repackage zip (update BUILD_TIMESTAMP.txt and CHANGES.txt)
3. deploy.bat dev
   → deploys to dev URL
   → uses dev Supabase project
   → commits to dev branch on GitHub
4. Test on dev URL
5. When happy, promote to production — see [PROMOTE.md](PROMOTE.md). **Never run `deploy.bat main`** after initial project setup; it must go through `git reset --hard dev` + `git push origin main --force-with-lease` instead.
   → deploys to production URL
   → uses production Supabase project
   → commits to main branch on GitHub
```

## Database changes (migrations)

!!! IMPORTANT — READ BEFORE RUNNING ANY MIGRATION ON PRODUCTION

When a feature requires a database schema change:

1. **Write the migration SQL** as a new numbered file:
   ```
   supabase/25-your-feature-name.sql
   ```

2. **Run it on dev first** — in the dev Supabase project SQL Editor.
   Test thoroughly. Make sure nothing breaks.

3. **When ready to promote to production:**
   - Open the production Supabase project SQL Editor
   - Run the same migration SQL manually
   - Then run `deploy.bat main` to deploy the matching code

4. **Add the file to `00-FULL-SCHEMA.sql`** so new project setups include it.

### Rule: never run a migration on production that hasn't been tested on dev first.

### Rule: always deploy the code and the migration together — don't deploy code 
### that depends on a schema change before the schema change has been applied.

## Setting up a new dev project from scratch

1. Create new Supabase project (EU West, free plan)
2. Run `supabase/00-FULL-SCHEMA.sql` in its SQL Editor
3. Run `supabase/dev-data-migration.sql` in its SQL Editor
4. Create your user: Authentication → Users → Add user
5. Run in SQL Editor:
   ```sql
   insert into profiles (id, email, display_name, role, organisation_id)
   select id, email, 'Mike Ball', 'super_admin', null
   from auth.users where email = 'mike.ball@ionetiq.dev';

   insert into ad_user (user_id, organisation_id, email, first_name, last_name)
   select id, '0b116913-5b27-4c19-8eb9-bf5c4787e780', email, 'Mike', 'Ball'
   from auth.users where email = 'mike.ball@ionetiq.dev';

   update ad_distribution
   set owner = (select user_id from ad_user where email = 'mike.ball@ionetiq.dev')
   where owner is null;
   ```
6. Add GitHub Secrets: `SUPABASE_URL_DEV` and `SUPABASE_ANON_KEY_DEV`
7. `deploy.bat dev`
