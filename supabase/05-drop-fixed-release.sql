-- ============================================================
-- {{PROJECT_NAME}} - One-off migration
--
-- Removes the fixed_release column from issues_issue. This column
-- was added in an earlier version of 03-issues.sql and turned out to
-- duplicate resolved_release - 03-issues.sql itself has already been
-- updated to never create this column on a fresh database, but if
-- you ran an earlier version of that script (before this fix), run
-- this once to bring your existing database in line.
--
-- Safe to re-run - drop column if exists is a no-op if already gone.
-- ============================================================

alter table public.issues_issue drop column if exists fixed_release;
