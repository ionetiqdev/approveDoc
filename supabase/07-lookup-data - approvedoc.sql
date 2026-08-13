-- ============================================================
-- {{PROJECT_NAME}} - Lookup table starting data
--
-- MANUAL, EDIT-BEFORE-RUNNING script. This is not part of the
-- automatic schema build (01-06) - it exists purely so a new
-- project doesn't start with every lookup table completely empty,
-- and so there's an obvious, central place to put real client-
-- specific values instead of generic placeholders.
--
-- This script is ONLY about data - it never creates or alters any
-- table structure. Every table here already exists from
-- 02-documents.sql / 03-issues.sql before this runs.
--
-- HOW TO USE THIS FILE:
--   1. An ionetiq team member opens this file before running it on
--      a new project's database.
--   2. Replace every placeholder value below with whatever's
--      actually right for that specific client/project. Delete any
--      placeholder rows that don't apply; add more by copying the
--      pattern.
--   3. For the Document Categories section specifically, replace
--      the organisation name placeholder with the new project's
--      real organisation name (see the note in that section).
--   4. Run the edited script once, in the Supabase SQL Editor.
--
-- Safe to re-run as edited - every insert uses "on conflict do
-- nothing" or an equivalent guard, so re-running won't duplicate
-- rows you've already added, though it also won't UPDATE rows
-- you've since edited by hand in the app - this is a starting-data
-- script, not a sync mechanism.
-- ============================================================


-- ── issues_status ─────────────────────────────────────────────────
-- 03-issues.sql already seeds a sensible generic default set
-- (Open/In Progress/On Hold/Resolved/Closed/Rejected). Edit below
-- only if this specific project wants a different set - delete this
-- whole block to just keep the schema's defaults as-is.

insert into public.issues_status (name, sort_order) values
  ('Open',        1),
  ('In Progress', 2),
  ('On Hold',      3),
  ('Resolved',     4),
  ('Closed',       5),
  ('Rejected',     6)
on conflict (name) do nothing;


-- ── issues_priority ───────────────────────────────────────────────
-- Same note as above - 03-issues.sql already seeds Critical/High/
-- Medium/Low. Edit below only to override.

insert into public.issues_priority (name, sort_order) values
  ('Critical', 1),
  ('High',     2),
  ('Medium',   3),
  ('Low',      4)
on conflict (name) do nothing;


-- ── issues_type ───────────────────────────────────────────────────
-- Same note as above - 03-issues.sql already seeds Bug/Feature
-- Request/Task/Question/Improvement. Edit below only to override.

insert into public.issues_type (name, sort_order) values
  ('Bug',             1),
  ('Feature Request', 2),
  ('Task',            3),
  ('Question',        4),
  ('Improvement',     5)
on conflict (name) do nothing;


-- ── issues_project ────────────────────────────────────────────────
-- No defaults exist anywhere yet for this one - genuinely empty
-- until you fill this in. issues_project is "which product/codebase
-- area this issue belongs to" - replace with whatever's real for
-- this client.

insert into public.issues_project (name, sort_order) values
  ('approveDoc', 1),
  ('Document management', 2)
on conflict (name) do nothing;


-- ── issues_area ───────────────────────────────────────────────────
-- "Which functional area of the system" - also genuinely empty by
-- default. Replace with real values.

insert into public.issues_area (name, sort_order) values
  ('Documents', 1),
  ('Audiences', 2),
  ('Notifications', 3),
  ('Approval', 4),
  ('User management', 5),
  ('Audit', 6)
on conflict (name) do nothing;


-- ── issues_user ───────────────────────────────────────────────────
-- People who can be set as Reported By / Assigned To / Resolved By
-- on an issue. Deliberately separate from profiles (see
-- 03-issues.sql's own header comment) - these don't need to be real
-- app users, just names. Replace with the actual people who'll be
-- working issues for this project (typically the ionetiq team, not
-- the client's own users, since Issues is super_admin-only).

insert into public.issues_user (first_name, last_name, email, sort_order) values
  ('Mike', 'Ball', 'mike.ball@ionetiq.dev', 1)
on conflict (email) do nothing;
-- NOTE: the on conflict above only de-duplicates rows that have an
-- email set - issues_user.email is the only unique constraint on
-- this table. If you leave email null for everyone (fine - it's
-- optional), re-running this script WILL create duplicate rows for
-- any name-only entries. Either fill in email, or only run this
-- section once.


-- ── document_category_lookup ─────────────────────────────────────
-- UNLIKE every table above, this one is organisation-scoped
-- (organisation_id is NOT NULL) - it needs to know which
-- organisation these categories belong to. Replace
-- 'REPLACE ME - Organisation Name' below with this project's real
-- organisation name (must already exist in the organisations table
-- - create it first via the Organisations admin page if it doesn't).

insert into public.document_category_lookup (organisation_id, name, document_category_order)
select o.id, c.name, c.sort_order
from public.organisations o
cross join (values
  ('Policy', 1),
  ('Procedure', 2),
  ('Other', 3)
) as c(name, sort_order)
where o.name = 'REPLACE ME - Organisation Name'
on conflict (organisation_id, name) do nothing;
