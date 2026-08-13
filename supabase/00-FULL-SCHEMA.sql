-- ============================================================================
-- approveDoc — Full schema + seed data
-- Auto-combined from all migrations. Run this on a fresh Supabase project.
-- Generated: 13/08/2026
-- ============================================================================


-- ============================================================================
-- 01-core-schema.sql
-- ============================================================================

-- ============================================================
-- {{PROJECT_NAME}} - Core schema
--
-- Run this FIRST, before any sub-system migration (Documents,
-- Issues, etc). Creates: organisations, profiles, the role-model
-- helper functions, RLS on both tables, and the user-avatars
-- storage bucket.
--
-- Safe to re-run: every statement is idempotent (drop-if-exists
-- before create, enable RLS is a no-op if already enabled).
--
-- Role model (fixed, do not extend without revisiting every
-- policy below that references these role strings directly):
--   super_admin - all organisations, ionetiq team only
--   admin       - one organisation, includes admin functionality
--                 for that organisation (can manage users within
--                 their own org, but never grant super_admin and
--                 never touch another org's data)
--   user        - one organisation, editing capability
--   view        - one organisation, read-only
-- ============================================================


-- ── 1. organisations ─────────────────────────────────────────────

create table if not exists public.organisations (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  reference       text,
  contact_name    text,
  contact_email   text,
  description     text,
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.organisations is
  'One row per tenant organisation. The unit of multi-tenancy for this whole app - every org-scoped table joins back to this, directly via organisation_id or indirectly via a parent table.';


-- ── 2. profiles ───────────────────────────────────────────────────
-- One row per authenticated user, id = auth.users.id. Created via
-- the manage-user edge function's inviteUserByEmail flow, never
-- directly by the user themselves.

create table if not exists public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  display_name     text not null,
  email            text not null,
  role             text not null default 'view' check (role in ('super_admin', 'admin', 'user', 'view')),
  organisation_id  uuid references public.organisations(id) on delete set null,
  job_title        text,
  avatar_url       text,
  preferences      jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  -- super_admin operates across all organisations and must never be
  -- tied to a single one - enforced here as a hard constraint, not
  -- just convention, so a bad UPDATE can't silently create a
  -- super_admin scoped to one org by accident.
  constraint super_admin_has_no_organisation
    check (role <> 'super_admin' or organisation_id is null)
);

comment on table public.profiles is
  'One row per authenticated user. role and organisation_id together define the access boundary that every RLS policy in this database is ultimately built on.';


-- ── 3. Helper functions ──────────────────────────────────────────
-- SECURITY DEFINER is required here: a policy on profiles cannot
-- use a plain subquery back into profiles to find "my own role" -
-- that subquery is itself subject to the same RLS policy, which
-- recurses and effectively returns nothing for everyone (symptom:
-- every user, even ones with a correct organisation_id, appears to
-- have "no organisation assigned"). SECURITY DEFINER runs with the
-- privileges of the function owner and bypasses RLS for its own
-- internal lookup, breaking the recursion.
--
-- IMPORTANT (privilege escalation note): these functions only ever
-- SELECT, never write, and only ever look up the CALLING user's own
-- row (auth.uid()) - they cannot be used by a caller to read or
-- infer anything about another user's role/org. This is the safe
-- shape for a SECURITY DEFINER function; if you ever add a similar
-- helper that takes a user_id parameter instead of using auth.uid()
-- internally, you've created a privilege escalation path and need
-- to add an explicit caller-permission check inside the function.

create or replace function public._my_role()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public._my_organisation_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select organisation_id from public.profiles where id = auth.uid();
$$;


-- ── 4. RLS: organisations ────────────────────────────────────────

alter table public.organisations enable row level security;

drop policy if exists "Super admins: full access to organisations" on public.organisations;
create policy "Super admins: full access to organisations"
  on public.organisations for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view own organisation" on public.organisations;
create policy "Users: view own organisation"
  on public.organisations for select
  using (id = public._my_organisation_id());

-- Note: only super_admin can INSERT/UPDATE/DELETE organisations,
-- matching the Organisations admin page being super_admin-only.
-- admin/user/view all get SELECT of their own org row only, via the
-- policy above.


-- ── 5. RLS: profiles ──────────────────────────────────────────────

alter table public.profiles enable row level security;

drop policy if exists "Super admins: full access to profiles" on public.profiles;
create policy "Super admins: full access to profiles"
  on public.profiles for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view profiles in own organisation" on public.profiles;
create policy "Users: view profiles in own organisation"
  on public.profiles for select
  using (organisation_id = public._my_organisation_id());

-- Org-level admins may UPDATE any profile within their own
-- organisation (this is what lets the Users admin page work for
-- admin, not just super_admin) - but the with check clause is the
-- actual security boundary, not the client-side JS:
--   - the row being written must still belong to the admin's own
--     organisation (an admin can never move a user OUT of their org,
--     or edit a user who was never in it)
--   - the new role value must never be 'super_admin' - only a
--     super_admin (covered by the separate policy above) can ever
--     grant that role
drop policy if exists "Admins: manage profiles in own organisation" on public.profiles;
create policy "Admins: manage profiles in own organisation"
  on public.profiles for update
  using (
    public._my_role() = 'admin'
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() = 'admin'
    and organisation_id = public._my_organisation_id()
    and role <> 'super_admin'
  );

drop policy if exists "Users: update own profile only" on public.profiles;
create policy "Users: update own profile only"
  on public.profiles for update
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    -- Never let a user change their own role or organisation via
    -- this self-update path - those columns may only ever change
    -- through the admin-scoped policy above or the super_admin
    -- policy, never by the user acting on themselves.
    and role = (select role from public.profiles where id = auth.uid())
    and organisation_id is not distinct from (select organisation_id from public.profiles where id = auth.uid())
  );

-- Note: regular users (role = 'user' or 'view') have no INSERT/DELETE
-- policy on profiles, so those operations remain blocked for them -
-- profile rows are created via the manage-user edge function /
-- service role, not by users themselves. Admins also have no
-- INSERT/DELETE policy here for the same reason - user creation and
-- deletion always goes through the edge function (which enforces
-- its own, separate org/role checks - see
-- supabase/functions/manage-user/index.ts), never a direct insert/
-- delete from the client.


-- ── 6. Storage: user-avatars bucket ──────────────────────────────
-- Public bucket (avatar images are not sensitive) - readable by
-- anyone, but only writable into a path whose first folder segment
-- is the uploading user's own auth.uid() (path convention:
-- {user_id}/avatar.{ext} - this is the standard Supabase storage
-- pattern, see storage.foldername() in the Supabase docs), or by an
-- admin/super_admin acting on behalf of someone else via the Users
-- admin page.

insert into storage.buckets (id, name, public)
values ('user-avatars', 'user-avatars', true)
on conflict (id) do nothing;

drop policy if exists "Avatar images are publicly readable" on storage.objects;
create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'user-avatars');

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'user-avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public._my_role() in ('super_admin', 'admin')
    )
  );

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'user-avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public._my_role() in ('super_admin', 'admin')
    )
  );

-- ============================================================================
-- 02-documents.sql
-- ============================================================================

-- ============================================================
-- {{PROJECT_NAME}} - Documents sub-system
--
-- Run AFTER 01-core-schema.sql. Self-contained: every table, index,
-- and policy this sub-system needs lives in this one file, so it
-- can be skipped entirely for a project that doesn't want Documents,
-- or added later to a project that didn't run it at creation time
-- (see docs/SUBSYSTEMS.md).
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================


-- ── 1. document_category_lookup ──────────────────────────────────
-- Categories are per-organisation (not a global shared lookup) -
-- each org manages its own category list, e.g. "Policy", "Contract",
-- "Certificate". A brand new organisation starts with none; an
-- admin adds their own via the Documents page.

create table if not exists public.document_category_lookup (
  id                       uuid primary key default gen_random_uuid(),
  organisation_id          uuid not null references public.organisations(id) on delete cascade,
  name                     text not null,
  document_category_order  integer not null default 0,
  created_at               timestamptz not null default now(),

  constraint document_category_lookup_org_name_key unique (organisation_id, name)
);

create index if not exists idx_document_category_lookup_org
  on public.document_category_lookup(organisation_id);


-- ── 2. documents ───────────────────────────────────────────────────
-- One row per document record. The actual file content lives in
-- document_files (a document can have more than one file attached -
-- e.g. versions, or a cover page plus an appendix).

create table if not exists public.documents (
  id                   uuid primary key default gen_random_uuid(),
  organisation_id      uuid not null references public.organisations(id) on delete cascade,
  document_category_id uuid references public.document_category_lookup(id) on delete set null,
  title                text not null,
  description          text,
  created_by           uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists idx_documents_org on public.documents(organisation_id);
create index if not exists idx_documents_category on public.documents(document_category_id);


-- ── 3. document_files ────────────────────────────────────────────
-- File metadata; the actual bytes live in Supabase Storage under
-- the 'documents' bucket (created below), one storage object per row
-- here. organisation_id is intentionally duplicated onto this table
-- rather than scoped purely via a join back to documents - unlike a
-- pure junction table, document_files is itself the target of direct
-- Storage RLS checks (see bucket policies below), which need a fast,
-- direct column to check without an extra join into documents.

create table if not exists public.document_files (
  id                  uuid primary key default gen_random_uuid(),
  organisation_id     uuid not null references public.organisations(id) on delete cascade,
  document_id         uuid not null references public.documents(id) on delete cascade,
  file_name           text not null,
  download_file_name  text,
  storage_path        text not null,
  file_size_bytes      bigint,
  mime_type            text,
  uploaded_by          uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now()
);

create index if not exists idx_document_files_org on public.document_files(organisation_id);
create index if not exists idx_document_files_document on public.document_files(document_id);


-- ── 4. RLS ─────────────────────────────────────────────────────────
-- Same shape as organisations/profiles: super_admin gets full access
-- across every organisation, everyone else is scoped to their own
-- organisation via the _my_organisation_id() helper from
-- 01-core-schema.sql. view-role users get read-only (no with check,
-- so they have no write policy at all and INSERT/UPDATE/DELETE stay
-- blocked for them by the default-deny behaviour of RLS).

-- document_category_lookup
alter table public.document_category_lookup enable row level security;

drop policy if exists "Super admins: full access to document categories" on public.document_category_lookup;
create policy "Super admins: full access to document categories"
  on public.document_category_lookup for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view document categories in own organisation" on public.document_category_lookup;
create policy "Users: view document categories in own organisation"
  on public.document_category_lookup for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage document categories in own organisation" on public.document_category_lookup;
create policy "Editors: manage document categories in own organisation"
  on public.document_category_lookup for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );

-- documents
alter table public.documents enable row level security;

drop policy if exists "Super admins: full access to documents" on public.documents;
create policy "Super admins: full access to documents"
  on public.documents for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view documents in own organisation" on public.documents;
create policy "Users: view documents in own organisation"
  on public.documents for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage documents in own organisation" on public.documents;
create policy "Editors: manage documents in own organisation"
  on public.documents for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );

-- document_files
alter table public.document_files enable row level security;

drop policy if exists "Super admins: full access to document files" on public.document_files;
create policy "Super admins: full access to document files"
  on public.document_files for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view document files in own organisation" on public.document_files;
create policy "Users: view document files in own organisation"
  on public.document_files for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage document files in own organisation" on public.document_files;
create policy "Editors: manage document files in own organisation"
  on public.document_files for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );


-- ── 5. Storage: documents bucket ──────────────────────────────────
-- PRIVATE bucket (unlike avatars) - document content is genuinely
-- sensitive business data, not something to expose by guessable URL.
-- Access goes through signed URLs generated at request time, gated
-- by the same organisation/role check as the documents table itself.
-- Path convention: {organisation_id}/{document_id}/{file_name}.

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

drop policy if exists "Users: read documents in own organisation" on storage.objects;
create policy "Users: read documents in own organisation"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and (
      (storage.foldername(name))[1] = public._my_organisation_id()::text
      or public._my_role() = 'super_admin'
    )
  );

drop policy if exists "Editors: upload documents in own organisation" on storage.objects;
create policy "Editors: upload documents in own organisation"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (
      (
        public._my_role() in ('admin', 'user')
        and (storage.foldername(name))[1] = public._my_organisation_id()::text
      )
      or public._my_role() = 'super_admin'
    )
  );

drop policy if exists "Editors: delete documents in own organisation" on storage.objects;
create policy "Editors: delete documents in own organisation"
  on storage.objects for delete
  using (
    bucket_id = 'documents'
    and (
      (
        public._my_role() in ('admin', 'user')
        and (storage.foldername(name))[1] = public._my_organisation_id()::text
      )
      or public._my_role() = 'super_admin'
    )
  );

-- ============================================================================
-- 03-issues.sql
-- ============================================================================

-- ============================================================
-- {{PROJECT_NAME}} - Issues sub-system
--
-- Run AFTER 01-core-schema.sql. Self-contained: every table, index,
-- trigger, and policy this sub-system needs lives in this one file.
--
-- Deliberately NOT multi-tenant - this is a single, global issue
-- tracker (intended for the development/support team managing this
-- project itself, not a customer-facing feature), restricted to
-- super_admin only. Regular users (any role other than super_admin)
-- get zero rows from any operation on any issues_ table - this is
-- a single global access tier, not scoped by organisation_id.
--
-- Depends on _my_role() from 01-core-schema.sql - if that hasn't
-- been run yet, this script fails at the policy-creation step with
-- "function _my_role() does not exist", which is the correct
-- failure mode (run 01-core-schema.sql first).
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================


-- ── Lookup tables ──────────────────────────────────────────────

create table if not exists public.issues_status (
  id         integer primary key generated always as identity,
  name       text    not null unique,
  sort_order integer not null default 0
);

insert into public.issues_status (name, sort_order) values
  ('Open',        1),
  ('In Progress', 2),
  ('On Hold',     3),
  ('Resolved',    4),
  ('Closed',      5),
  ('Rejected',    6)
on conflict (name) do nothing;


create table if not exists public.issues_priority (
  id         integer primary key generated always as identity,
  name       text    not null unique,
  sort_order integer not null default 0
);

insert into public.issues_priority (name, sort_order) values
  ('Critical', 1),
  ('High',     2),
  ('Medium',   3),
  ('Low',      4)
on conflict (name) do nothing;


create table if not exists public.issues_type (
  id         integer primary key generated always as identity,
  name       text    not null unique,
  sort_order integer not null default 0
);

insert into public.issues_type (name, sort_order) values
  ('Bug',             1),
  ('Feature Request', 2),
  ('Task',            3),
  ('Question',        4),
  ('Improvement',     5)
on conflict (name) do nothing;


create table if not exists public.issues_project (
  id         integer primary key generated always as identity,
  name       text    not null unique,
  sort_order integer not null default 0
);

-- No default seed - projects/areas are deployment-specific, set
-- these up for real once the project is named and structured.

create table if not exists public.issues_area (
  id         integer primary key generated always as identity,
  name       text    not null unique,
  sort_order integer not null default 0
);


-- issues_user is deliberately separate from profiles - issues can be
-- reported by or assigned to people who aren't necessarily app users
-- at all (e.g. an external stakeholder relaying a bug report).
create table if not exists public.issues_user (
  id         integer primary key generated always as identity,
  first_name text    not null,
  last_name  text    not null,
  email      text unique,
  phone      text,
  sort_order integer not null default 0
);


-- ── Main issues table ──────────────────────────────────────────

create table if not exists public.issues_issue (
  id                uuid    primary key default gen_random_uuid(),
  issue_ref         text    not null unique,

  title             text    not null,
  description       text,
  type_id           integer references public.issues_type(id),
  status_id         integer references public.issues_status(id),
  priority_id       integer references public.issues_priority(id),
  area_id           integer references public.issues_area(id),
  project_id        integer references public.issues_project(id),

  reported_by_id    integer references public.issues_user(id),
  reported_date     date    not null default current_date,
  reported_release  text,

  assigned_to_id    integer references public.issues_user(id),
  assigned_date     date,

  resolved_by_id    integer references public.issues_user(id),
  resolved_date     date,
  resolved_release  text,
  resolved_comments text,

  related_issue_id  uuid    references public.issues_issue(id),

  documentation_notes text,
  notes             text,

  created_at        timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);


-- ── Auto-ref trigger (ISS-001, ISS-002, ...) ──────────────────

create sequence if not exists public.issues_ref_seq start 1;

create or replace function public.issues_set_ref()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.issue_ref is null or new.issue_ref = '' then
    new.issue_ref := 'ISS-' || lpad(nextval('public.issues_ref_seq')::text, 3, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_issues_set_ref on public.issues_issue;
create trigger trg_issues_set_ref
  before insert on public.issues_issue
  for each row execute function public.issues_set_ref();


-- ── updated_at trigger ─────────────────────────────────────────

create or replace function public.issues_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_issues_updated_at on public.issues_issue;
create trigger trg_issues_updated_at
  before update on public.issues_issue
  for each row execute function public.issues_set_updated_at();


-- ── Indexes ────────────────────────────────────────────────────

create index if not exists idx_issues_status_id   on public.issues_issue(status_id);
create index if not exists idx_issues_priority_id on public.issues_issue(priority_id);
create index if not exists idx_issues_project_id  on public.issues_issue(project_id);
create index if not exists idx_issues_area_id     on public.issues_issue(area_id);
create index if not exists idx_issues_type_id     on public.issues_issue(type_id);


-- ── RLS: super_admin only, every table ────────────────────────
-- No organisation scoping anywhere in this sub-system - deliberate,
-- see header comment. No grants to anon anywhere - only
-- 'authenticated' sessions reach these tables at all, and RLS then
-- restricts that further to super_admin specifically.

alter table public.issues_issue    enable row level security;
alter table public.issues_status   enable row level security;
alter table public.issues_priority enable row level security;
alter table public.issues_type     enable row level security;
alter table public.issues_project  enable row level security;
alter table public.issues_area     enable row level security;
alter table public.issues_user     enable row level security;

drop policy if exists "Super admins only: issues_issue" on public.issues_issue;
create policy "Super admins only: issues_issue"
  on public.issues_issue for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Super admins only: issues_status" on public.issues_status;
create policy "Super admins only: issues_status"
  on public.issues_status for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Super admins only: issues_priority" on public.issues_priority;
create policy "Super admins only: issues_priority"
  on public.issues_priority for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Super admins only: issues_type" on public.issues_type;
create policy "Super admins only: issues_type"
  on public.issues_type for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Super admins only: issues_project" on public.issues_project;
create policy "Super admins only: issues_project"
  on public.issues_project for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Super admins only: issues_area" on public.issues_area;
create policy "Super admins only: issues_area"
  on public.issues_area for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Super admins only: issues_user" on public.issues_user;
create policy "Super admins only: issues_user"
  on public.issues_user for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

grant usage on sequence public.issues_ref_seq to authenticated;

-- ============================================================================
-- 05-drop-fixed-release.sql
-- ============================================================================

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

-- ============================================================================
-- 06-add-download-filename.sql
-- ============================================================================

-- ============================================================
-- {{PROJECT_NAME}} - One-off migration
--
-- Adds download_file_name to document_files. 02-documents.sql has
-- already been updated to create this column on a fresh database -
-- run this once if you ran an earlier version of that script first.
--
-- Safe to re-run - add column if not exists is a no-op if already there.
-- ============================================================

alter table public.document_files add column if not exists download_file_name text;

-- ============================================================================
-- 07-lookup-data - approvedoc.sql
-- ============================================================================

-- Insert organisation first so all FK references resolve
INSERT INTO organisations (id, name, created_at) 
VALUES ('0b116913-5b27-4c19-8eb9-bf5c4787e780', 'gardenSOL', '2026-06-27 14:21:41.674144+00')
ON CONFLICT DO NOTHING;

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

-- ============================================================================
-- 08-approvedoc-schema.sql
-- ============================================================================

-- ============================================================================
-- approveDoc v1.0 — Compliance / Acknowledgement Schema
-- Migration: 04-approvedoc-schema.sql
-- Project: nkwpqboslnbeifyaegos (approveDoc v1.0)
-- Repo: github.com/ionetiqdev/approveDoc.git
-- Generated: 27/06/2026
--
-- Follows on from existing migrations already applied to this project:
--   01-core-schema.sql
--   02-documents.sql
--   03-issues.sql
--
-- This migration adds the user/audience/assignment/compliance-tracking layer
-- (ad_* tables) plus audit_log. It assumes 01-03 have already run, in
-- particular that public.organisations already exists (created in
-- 01-core-schema.sql) and that public.profiles already exists and owns the
-- user's avatar (also from 01-core-schema.sql or equivalent).
--
-- IMPORTANT: if any table below (e.g. ad_document, ad_category) was already
-- partially created by 02-documents.sql, review for naming collisions before
-- running — this migration uses "create table if not exists" so it will NOT
-- overwrite an existing table's columns, it will just silently skip creating
-- it. Diff against 02-documents.sql first if unsure.
--
-- ASSUMPTIONS / DECISIONS (confirmed with Mike):
--   1. ad_department: duplicate definition in source CSV removed; using the
--      fuller version (department_id PK, organisation_id FK, name).
--   2. ad_audience.audience_id is the PK of ad_audience.
--   3. ad_approval_type is a NEW table (not in original CSV) to support
--      ad_audience.approval_type_id as a proper FK.
--   4. ad_related_document.doc_id / related_doc_id both reference ad_document
--      (CSV listed doc_id -> ad_audience, treated as a copy-paste error since
--      this is clearly a document-to-document "related document" link).
--   5. ad_user.avatar is DROPPED. Avatar is owned by the existing `profiles`
--      table (which, like ad_user, extends auth.users). Apps should join
--      profiles.avatar for display rather than duplicating it on ad_user.
--   6. organisations table is assumed to ALREADY EXIST — referenced via FK
--      only, not created here. If it does not exist yet, run
--      00_organisations_prereq.sql first.
--   7. ad_user.user_id FKs to auth.users(id), consistent with Supabase
--      convention for tables that extend the built-in user.
--   8. datetime -> timestamptz, json -> jsonb (Postgres/Supabase best practice).
--   9. RLS: organisation-scoped policies applied to every table that carries
--      an organisation_id column, based on the requesting user's own
--      organisation_id (resolved via ad_user). See section 4.
--
-- Run this whole script in the Supabase SQL editor for project
-- nkwpqboslnbeifyaegos (approveDoc v1.0). It is idempotent (safe to re-run)
-- via "IF NOT EXISTS" / "CREATE OR REPLACE" throughout — but see the
-- collision note above regarding 02-documents.sql before first run.
-- ============================================================================


-- ============================================================================
-- SECTION 0 — Extensions
-- ============================================================================

create extension if not exists "pgcrypto"; -- gen_random_uuid()


-- ============================================================================
-- SECTION 1 — Lookup / reference tables (no dependencies on ad_user)
-- ============================================================================

-- --------------------------------------------------------------------------
-- ad_language — locale reference (PK is the locale code itself, e.g. en-GB)
-- --------------------------------------------------------------------------
create table if not exists public.ad_language (
    locale      varchar(5) primary key,
    name        varchar not null
);

comment on table public.ad_language is 'Supported locales for user language preference.';

-- --------------------------------------------------------------------------
-- ad_country — country reference, scoped per organisation
-- --------------------------------------------------------------------------
create table if not exists public.ad_country (
    country_code    varchar(3) primary key,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_country is 'Country reference list, per organisation.';

-- --------------------------------------------------------------------------
-- ad_department
-- --------------------------------------------------------------------------
create table if not exists public.ad_department (
    department_id   uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_department is 'Departments within an organisation.';

-- --------------------------------------------------------------------------
-- ad_location
-- --------------------------------------------------------------------------
create table if not exists public.ad_location (
    location_id    uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_location is 'Physical/regional locations within an organisation.';

-- --------------------------------------------------------------------------
-- ad_category — document categories
-- --------------------------------------------------------------------------
create table if not exists public.ad_category (
    category_id     uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_category is 'Categories used to classify documents.';

-- --------------------------------------------------------------------------
-- ad_approval_type — NEW table, supports ad_audience.approval_type_id
-- --------------------------------------------------------------------------
create table if not exists public.ad_approval_type (
    approval_type_id uuid primary key default gen_random_uuid(),
    organisation_id  uuid not null references public.organisations(id) on delete cascade,
    name             varchar not null,
    sort_order       int
);

comment on table public.ad_approval_type is 'Defines the approval workflow types selectable on an audience.';


-- ============================================================================
-- SECTION 2 — ad_user (extends auth.users) and dependents
-- ============================================================================

-- --------------------------------------------------------------------------
-- ad_user
-- Self-referencing FKs (manager_id, senior_manager_id) deferred until after
-- table creation isn't required in Postgres provided the table already
-- exists at the point the constraint is declared — which it does here.
-- --------------------------------------------------------------------------
create table if not exists public.ad_user (
    user_id                 uuid primary key references auth.users(id) on delete cascade,
    organisation_id         uuid not null references public.organisations(id) on delete cascade,
    first_name              varchar,
    last_name               varchar,
    known_name              varchar,
    email                   varchar,
    mobile_number           varchar,
    mobile_cc               varchar,
    status                  varchar,
    language_id             varchar(5) references public.ad_language(locale),
    location_id             uuid references public.ad_location(location_id),
    department_id           uuid references public.ad_department(department_id),
    job_title               varchar,
    manager_id              uuid references public.ad_user(user_id),
    senior_manager_id       uuid references public.ad_user(user_id),
    role_user               boolean default true,
    role_admin              boolean default false,
    role_reporting          boolean default false,
    role_publisher          boolean default false,
    role_admin_assistant    boolean default false,
    delegated               boolean default false
    -- NOTE: avatar intentionally omitted — see profiles.avatar instead.
);

comment on table public.ad_user is 'approveDoc-specific extension of auth.users. Avatar lives on profiles, not here.';


-- ============================================================================
-- SECTION 3 — Documents, versions, audiences, assignments, state, audit
-- ============================================================================

-- --------------------------------------------------------------------------
-- ad_document
-- Note: current_version_id is added as a FK once ad_document_version exists
-- (see ALTER below) to avoid a circular create-time dependency.
-- --------------------------------------------------------------------------
create table if not exists public.ad_document (
    doc_id              uuid primary key default gen_random_uuid(),
    organisation_id     uuid not null references public.organisations(id) on delete cascade,
    name                varchar not null,
    description         text,
    category_id         uuid references public.ad_category(category_id),
    helptext            varchar,
    current_version_id  uuid -- FK added below after ad_document_version exists
);

comment on table public.ad_document is 'Master document record (a "policy"); version-specific content lives in ad_document_version.';

-- --------------------------------------------------------------------------
-- ad_document_version
-- --------------------------------------------------------------------------
create table if not exists public.ad_document_version (
    id                      uuid primary key default gen_random_uuid(),
    document_id             uuid not null references public.ad_document(doc_id) on delete cascade,
    major_version_number    int not null,
    minor_version_number    int not null default 0,
    source_file_url         text,
    pdf_file_url            text,
    change_summary          text,
    created_at              timestamptz not null default now()
);

comment on table public.ad_document_version is 'Each upload/revision of a document. source_file_url = original upload, pdf_file_url = PDF rendition.';

-- Now that ad_document_version exists, wire up ad_document.current_version_id
do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'ad_document_current_version_id_fkey'
    ) then
        alter table public.ad_document
            add constraint ad_document_current_version_id_fkey
            foreign key (current_version_id)
            references public.ad_document_version(id)
            on delete set null;
    end if;
end $$;

-- --------------------------------------------------------------------------
-- ad_audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_audience (
    audience_id      uuid primary key default gen_random_uuid(),
    organisation_id  uuid not null references public.organisations(id) on delete cascade,
    name             varchar not null,
    approval_type_id uuid references public.ad_approval_type(approval_type_id)
);

comment on table public.ad_audience is 'A defined group of users that documents can be assigned to.';

-- --------------------------------------------------------------------------
-- ad_audience_member — join table: users in an audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_audience_member (
    audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
    user_id         uuid not null references public.ad_user(user_id) on delete cascade,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    primary key (audience_id, user_id)
);

comment on table public.ad_audience_member is 'Membership join table between ad_audience and ad_user.';

-- --------------------------------------------------------------------------
-- ad_audience_document — join table: documents assigned to an audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_audience_document (
    audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
    doc_id          uuid not null references public.ad_document(doc_id) on delete cascade,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    primary key (audience_id, doc_id)
);

comment on table public.ad_audience_document is 'Join table linking documents to the audiences they are published to.';

-- --------------------------------------------------------------------------
-- ad_related_document — document-to-document "see also" link
-- CSV had doc_id -> ad_audience; corrected to ad_document <-> ad_document.
-- --------------------------------------------------------------------------
create table if not exists public.ad_related_document (
    doc_id          uuid not null references public.ad_document(doc_id) on delete cascade,
    related_doc_id  uuid not null references public.ad_document(doc_id) on delete cascade,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    primary key (doc_id, related_doc_id),
    constraint ad_related_document_no_self_link check (doc_id <> related_doc_id)
);

comment on table public.ad_related_document is 'Self-referencing link between related documents (e.g. "see also").';

-- --------------------------------------------------------------------------
-- ad_assignment — compliance assignment of a document to a user/audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_assignment (
    id                          uuid primary key default gen_random_uuid(),
    organisation_id             uuid not null references public.organisations(id) on delete cascade,
    document_id                 uuid not null references public.ad_document(doc_id) on delete cascade,
    audience_id                 uuid references public.ad_audience(audience_id) on delete set null,
    user_id                     uuid references public.ad_user(user_id) on delete cascade,
    due_at                      timestamptz,
    mandatory                   boolean not null default true,
    require_reack_on_update     boolean not null default false,
    created_at                  timestamptz not null default now()
);

comment on table public.ad_assignment is 'A compliance requirement: a document due for a user, optionally arising from an audience.';

-- --------------------------------------------------------------------------
-- ad_user_document_state — per-user, per-document current compliance state
-- --------------------------------------------------------------------------
create table if not exists public.ad_user_document_state (
    id                              uuid primary key default gen_random_uuid(),
    user_id                         uuid not null references public.ad_user(user_id) on delete cascade,
    document_id                     uuid not null references public.ad_document(doc_id) on delete cascade,
    last_acknowledged_version_id    uuid references public.ad_document_version(id) on delete set null,
    is_compliant                    boolean not null default false,
    is_overdue                      boolean not null default false,
    last_viewed_at                  timestamptz,
    acknowledged_at                 timestamptz,
    updated_at                      timestamptz not null default now(),
    unique (user_id, document_id)
);

comment on table public.ad_user_document_state is 'Rolled-up current compliance state per user per document (one row per user/document pair).';

-- --------------------------------------------------------------------------
-- ad_notification
-- --------------------------------------------------------------------------
create table if not exists public.ad_notification (
    id              uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    user_id         uuid not null references public.ad_user(user_id) on delete cascade,
    type            varchar not null, -- e.g. reminder, overdue, assignment
    payload         jsonb,
    sent_at         timestamptz,
    read_at         timestamptz
);

comment on table public.ad_notification is 'Notifications sent to users (reminders, overdue alerts, new assignments, etc).';

-- --------------------------------------------------------------------------
-- audit_log
-- --------------------------------------------------------------------------
create table if not exists public.audit_log (
    id              uuid primary key default gen_random_uuid(),
    organisation_id uuid references public.organisations(id) on delete cascade,
    user_id         uuid references public.ad_user(user_id) on delete set null,
    action          varchar not null,
    entity_type     varchar not null,
    entity_id       uuid,
    metadata        jsonb,
    created_at      timestamptz not null default now()
);

comment on table public.audit_log is 'Generic audit trail across all approveDoc entities.';


-- ============================================================================
-- SECTION 4 — Indexes (FKs are not auto-indexed in Postgres)
-- ============================================================================

create index if not exists idx_ad_user_organisation_id            on public.ad_user(organisation_id);
create index if not exists idx_ad_user_manager_id                 on public.ad_user(manager_id);
create index if not exists idx_ad_user_senior_manager_id          on public.ad_user(senior_manager_id);
create index if not exists idx_ad_user_department_id              on public.ad_user(department_id);
create index if not exists idx_ad_user_location_id                on public.ad_user(location_id);

create index if not exists idx_ad_department_organisation_id      on public.ad_department(organisation_id);
create index if not exists idx_ad_location_organisation_id        on public.ad_location(organisation_id);
create index if not exists idx_ad_country_organisation_id         on public.ad_country(organisation_id);
create index if not exists idx_ad_category_organisation_id        on public.ad_category(organisation_id);
create index if not exists idx_ad_approval_type_organisation_id   on public.ad_approval_type(organisation_id);

create index if not exists idx_ad_document_organisation_id        on public.ad_document(organisation_id);
create index if not exists idx_ad_document_category_id            on public.ad_document(category_id);
create index if not exists idx_ad_document_current_version_id     on public.ad_document(current_version_id);

create index if not exists idx_ad_document_version_document_id    on public.ad_document_version(document_id);

create index if not exists idx_ad_audience_organisation_id        on public.ad_audience(organisation_id);
create index if not exists idx_ad_audience_approval_type_id       on public.ad_audience(approval_type_id);

create index if not exists idx_ad_audience_member_user_id         on public.ad_audience_member(user_id);
create index if not exists idx_ad_audience_member_organisation_id on public.ad_audience_member(organisation_id);

create index if not exists idx_ad_audience_document_doc_id        on public.ad_audience_document(doc_id);
create index if not exists idx_ad_audience_document_organisation_id on public.ad_audience_document(organisation_id);

create index if not exists idx_ad_related_document_related_doc_id on public.ad_related_document(related_doc_id);
create index if not exists idx_ad_related_document_organisation_id on public.ad_related_document(organisation_id);

create index if not exists idx_ad_assignment_organisation_id      on public.ad_assignment(organisation_id);
create index if not exists idx_ad_assignment_document_id          on public.ad_assignment(document_id);
create index if not exists idx_ad_assignment_audience_id          on public.ad_assignment(audience_id);
create index if not exists idx_ad_assignment_user_id              on public.ad_assignment(user_id);
create index if not exists idx_ad_assignment_due_at               on public.ad_assignment(due_at);

create index if not exists idx_ad_user_doc_state_user_id          on public.ad_user_document_state(user_id);
create index if not exists idx_ad_user_doc_state_document_id      on public.ad_user_document_state(document_id);
create index if not exists idx_ad_user_doc_state_is_overdue       on public.ad_user_document_state(is_overdue);

create index if not exists idx_ad_notification_organisation_id    on public.ad_notification(organisation_id);
create index if not exists idx_ad_notification_user_id            on public.ad_notification(user_id);

create index if not exists idx_audit_log_organisation_id          on public.audit_log(organisation_id);
create index if not exists idx_audit_log_user_id                  on public.audit_log(user_id);
create index if not exists idx_audit_log_entity                   on public.audit_log(entity_type, entity_id);


-- ============================================================================
-- SECTION 5 — Row Level Security (organisation-scoped multi-tenancy)
--
-- Strategy: every table with an organisation_id column is protected by a
-- policy that checks the requesting user's organisation_id (looked up from
-- ad_user via auth.uid()) matches the row's organisation_id.
--
-- A helper function avoids repeating the subquery in every policy and lets
-- Postgres cache execution per statement.
-- ============================================================================

create or replace function public.ad_current_user_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select organisation_id
    from public.ad_user
    where user_id = auth.uid()
$$;

comment on function public.ad_current_user_org_id() is 'Returns the organisation_id of the currently authenticated user, for use in RLS policies.';

-- --------------------------------------------------------------------------
-- Enable RLS on every organisation-scoped table
-- --------------------------------------------------------------------------
alter table public.ad_user                 enable row level security;
alter table public.ad_department           enable row level security;
alter table public.ad_location             enable row level security;
alter table public.ad_country              enable row level security;
alter table public.ad_category             enable row level security;
alter table public.ad_approval_type        enable row level security;
alter table public.ad_document             enable row level security;
alter table public.ad_audience             enable row level security;
alter table public.ad_audience_member      enable row level security;
alter table public.ad_audience_document    enable row level security;
alter table public.ad_related_document     enable row level security;
alter table public.ad_assignment           enable row level security;
alter table public.ad_notification         enable row level security;
alter table public.audit_log               enable row level security;

-- ad_document_version and ad_user_document_state have no organisation_id
-- column directly; scope them via their parent document/user instead.
alter table public.ad_document_version     enable row level security;
alter table public.ad_user_document_state  enable row level security;

-- --------------------------------------------------------------------------
-- Policies — one combined ALL-command policy per table, named consistently.
-- Drop-and-recreate pattern used so the script is safely re-runnable.
-- --------------------------------------------------------------------------

drop policy if exists ad_user_org_isolation on public.ad_user;
create policy ad_user_org_isolation on public.ad_user
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_department_org_isolation on public.ad_department;
create policy ad_department_org_isolation on public.ad_department
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_location_org_isolation on public.ad_location;
create policy ad_location_org_isolation on public.ad_location
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_country_org_isolation on public.ad_country;
create policy ad_country_org_isolation on public.ad_country
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_category_org_isolation on public.ad_category;
create policy ad_category_org_isolation on public.ad_category
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_approval_type_org_isolation on public.ad_approval_type;
create policy ad_approval_type_org_isolation on public.ad_approval_type
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_document_org_isolation on public.ad_document;
create policy ad_document_org_isolation on public.ad_document
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_audience_org_isolation on public.ad_audience;
create policy ad_audience_org_isolation on public.ad_audience
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_audience_member_org_isolation on public.ad_audience_member;
create policy ad_audience_member_org_isolation on public.ad_audience_member
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_audience_document_org_isolation on public.ad_audience_document;
create policy ad_audience_document_org_isolation on public.ad_audience_document
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_related_document_org_isolation on public.ad_related_document;
create policy ad_related_document_org_isolation on public.ad_related_document
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_assignment_org_isolation on public.ad_assignment;
create policy ad_assignment_org_isolation on public.ad_assignment
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_notification_org_isolation on public.ad_notification;
create policy ad_notification_org_isolation on public.ad_notification
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists audit_log_org_isolation on public.audit_log;
create policy audit_log_org_isolation on public.audit_log
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

-- ad_document_version — scoped via parent ad_document's organisation_id
drop policy if exists ad_document_version_org_isolation on public.ad_document_version;
create policy ad_document_version_org_isolation on public.ad_document_version
    for all using (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    )
    with check (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    );

-- ad_user_document_state — scoped via parent ad_document's organisation_id
drop policy if exists ad_user_document_state_org_isolation on public.ad_user_document_state;
create policy ad_user_document_state_org_isolation on public.ad_user_document_state
    for all using (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    )
    with check (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    );

-- ============================================================================
-- End of script
-- ============================================================================

-- ============================================================================
-- 09-language-lookup-data.sql
-- ============================================================================

-- ============================================================================
-- approveDoc — ad_language seed data
-- Standard locale list for user language preference.
-- Safe to re-run: ON CONFLICT DO NOTHING.
-- ============================================================================

insert into public.ad_language (locale, name) values
  ('en-GB', 'English (United Kingdom)'),
  ('en-US', 'English (United States)'),
  ('en-AU', 'English (Australia)'),
  ('en-CA', 'English (Canada)'),
  ('en-IE', 'English (Ireland)'),
  ('en-NZ', 'English (New Zealand)'),
  ('en-ZA', 'English (South Africa)'),
  ('fr-FR', 'French (France)'),
  ('fr-CA', 'French (Canada)'),
  ('fr-BE', 'French (Belgium)'),
  ('de-DE', 'German (Germany)'),
  ('de-AT', 'German (Austria)'),
  ('de-CH', 'German (Switzerland)'),
  ('es-ES', 'Spanish (Spain)'),
  ('es-MX', 'Spanish (Mexico)'),
  ('pt-PT', 'Portuguese (Portugal)'),
  ('pt-BR', 'Portuguese (Brazil)'),
  ('it-IT', 'Italian (Italy)'),
  ('nl-NL', 'Dutch (Netherlands)'),
  ('nl-BE', 'Dutch (Belgium)'),
  ('sv-SE', 'Swedish (Sweden)'),
  ('da-DK', 'Danish (Denmark)'),
  ('no-NO', 'Norwegian (Norway)'),
  ('fi-FI', 'Finnish (Finland)'),
  ('pl-PL', 'Polish (Poland)'),
  ('cs-CZ', 'Czech (Czech Republic)'),
  ('el-GR', 'Greek (Greece)'),
  ('ru-RU', 'Russian (Russia)'),
  ('tr-TR', 'Turkish (Turkey)'),
  ('ar-SA', 'Arabic (Saudi Arabia)'),
  ('ar-AE', 'Arabic (United Arab Emirates)'),
  ('he-IL', 'Hebrew (Israel)'),
  ('hi-IN', 'Hindi (India)'),
  ('zh-CN', 'Chinese, Simplified (China)'),
  ('zh-TW', 'Chinese, Traditional (Taiwan)'),
  ('zh-HK', 'Chinese, Traditional (Hong Kong)'),
  ('ja-JP', 'Japanese (Japan)'),
  ('ko-KR', 'Korean (South Korea)'),
  ('vi-VN', 'Vietnamese (Vietnam)'),
  ('th-TH', 'Thai (Thailand)'),
  ('id-ID', 'Indonesian (Indonesia)'),
  ('ms-MY', 'Malay (Malaysia)')
on conflict (locale) do nothing;

-- ============================================================================
-- 10-country-lookup-data.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_country seed data
-- ISO 3166-1 alpha-3 country codes, scoped to the default 'ionetiq'
-- organisation (id 0b116913-5b27-4c19-8eb9-bf5c4787e780).
-- Safe to re-run: ON CONFLICT DO NOTHING.
--
-- ad_country.country_code is the table's primary key, NOT composite with
-- organisation_id - so this seed list can only ever be inserted once across
-- the whole table, regardless of organisation. If approveDoc later needs
-- per-organisation country lists (rather than one shared list owned by
-- whichever org happens to seed it first), ad_country's schema will need
-- revisiting - organisation_id would need to become part of the primary key.
-- ============================================================================

insert into public.ad_country (country_code, organisation_id, name) values
  ('AFG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Afghanistan'),
  ('ALB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Albania'),
  ('DZA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Algeria'),
  ('ASM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'American Samoa'),
  ('AND', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Andorra'),
  ('AGO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Angola'),
  ('AIA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Anguilla'),
  ('ATA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Antarctica'),
  ('ATG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Antigua and Barbuda'),
  ('ARG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Argentina'),
  ('ARM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Armenia'),
  ('ABW', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Aruba'),
  ('AUS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Australia'),
  ('AUT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Austria'),
  ('AZE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Azerbaijan'),
  ('BHS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bahamas'),
  ('BHR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bahrain'),
  ('BGD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bangladesh'),
  ('BRB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Barbados'),
  ('BLR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Belarus'),
  ('BEL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Belgium'),
  ('BLZ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Belize'),
  ('BEN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Benin'),
  ('BMU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bermuda'),
  ('BTN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bhutan'),
  ('BOL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bolivia'),
  ('BES', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bonaire, Sint Eustatius and Saba'),
  ('BIH', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bosnia and Herzegovina'),
  ('BWA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Botswana'),
  ('BVT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bouvet Island'),
  ('BRA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Brazil'),
  ('IOT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'British Indian Ocean Territory'),
  ('BRN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Brunei Darussalam'),
  ('BGR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Bulgaria'),
  ('BFA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Burkina Faso'),
  ('BDI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Burundi'),
  ('CPV', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cabo Verde'),
  ('KHM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cambodia'),
  ('CMR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cameroon'),
  ('CAN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Canada'),
  ('CYM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cayman Islands'),
  ('CAF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Central African Republic'),
  ('TCD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Chad'),
  ('CHL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Chile'),
  ('CHN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'China'),
  ('CXR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Christmas Island'),
  ('CCK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cocos (Keeling) Islands'),
  ('COL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Colombia'),
  ('COM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Comoros'),
  ('COG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Congo'),
  ('COD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Congo, Democratic Republic of the'),
  ('COK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cook Islands'),
  ('CRI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Costa Rica'),
  ('CIV', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cote d''Ivoire'),
  ('HRV', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Croatia'),
  ('CUB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cuba'),
  ('CUW', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Curacao'),
  ('CYP', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Cyprus'),
  ('CZE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Czechia'),
  ('DNK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Denmark'),
  ('DJI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Djibouti'),
  ('DMA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Dominica'),
  ('DOM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Dominican Republic'),
  ('ECU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Ecuador'),
  ('EGY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Egypt'),
  ('SLV', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'El Salvador'),
  ('GNQ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Equatorial Guinea'),
  ('ERI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Eritrea'),
  ('EST', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Estonia'),
  ('SWZ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Eswatini'),
  ('ETH', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Ethiopia'),
  ('FLK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Falkland Islands'),
  ('FRO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Faroe Islands'),
  ('FJI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Fiji'),
  ('FIN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Finland'),
  ('FRA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'France'),
  ('GUF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'French Guiana'),
  ('PYF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'French Polynesia'),
  ('ATF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'French Southern Territories'),
  ('GAB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Gabon'),
  ('GMB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Gambia'),
  ('GEO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Georgia'),
  ('DEU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Germany'),
  ('GHA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Ghana'),
  ('GIB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Gibraltar'),
  ('GRC', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Greece'),
  ('GRL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Greenland'),
  ('GRD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Grenada'),
  ('GLP', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guadeloupe'),
  ('GUM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guam'),
  ('GTM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guatemala'),
  ('GGY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guernsey'),
  ('GIN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guinea'),
  ('GNB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guinea-Bissau'),
  ('GUY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guyana'),
  ('HTI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Haiti'),
  ('HMD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Heard Island and McDonald Islands'),
  ('VAT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Holy See'),
  ('HND', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Honduras'),
  ('HKG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Hong Kong'),
  ('HUN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Hungary'),
  ('ISL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Iceland'),
  ('IND', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'India'),
  ('IDN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Indonesia'),
  ('IRN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Iran'),
  ('IRQ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Iraq'),
  ('IRL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Ireland'),
  ('IMN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Isle of Man'),
  ('ISR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Israel'),
  ('ITA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Italy'),
  ('JAM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Jamaica'),
  ('JPN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Japan'),
  ('JEY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Jersey'),
  ('JOR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Jordan'),
  ('KAZ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Kazakhstan'),
  ('KEN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Kenya'),
  ('KIR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Kiribati'),
  ('PRK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Korea, Democratic Peoples Republic of'),
  ('KOR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Korea, Republic of'),
  ('KWT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Kuwait'),
  ('KGZ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Kyrgyzstan'),
  ('LAO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Lao Peoples Democratic Republic'),
  ('LVA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Latvia'),
  ('LBN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Lebanon'),
  ('LSO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Lesotho'),
  ('LBR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Liberia'),
  ('LBY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Libya'),
  ('LIE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Liechtenstein'),
  ('LTU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Lithuania'),
  ('LUX', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Luxembourg'),
  ('MAC', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Macao'),
  ('MDG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Madagascar'),
  ('MWI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Malawi'),
  ('MYS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Malaysia'),
  ('MDV', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Maldives'),
  ('MLI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mali'),
  ('MLT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Malta'),
  ('MHL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Marshall Islands'),
  ('MTQ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Martinique'),
  ('MRT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mauritania'),
  ('MUS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mauritius'),
  ('MYT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mayotte'),
  ('MEX', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mexico'),
  ('FSM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Micronesia'),
  ('MDA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Moldova'),
  ('MCO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Monaco'),
  ('MNG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mongolia'),
  ('MNE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Montenegro'),
  ('MSR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Montserrat'),
  ('MAR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Morocco'),
  ('MOZ', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Mozambique'),
  ('MMR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Myanmar'),
  ('NAM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Namibia'),
  ('NRU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Nauru'),
  ('NPL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Nepal'),
  ('NLD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Netherlands'),
  ('NCL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'New Caledonia'),
  ('NZL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'New Zealand'),
  ('NIC', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Nicaragua'),
  ('NER', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Niger'),
  ('NGA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Nigeria'),
  ('NIU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Niue'),
  ('NFK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Norfolk Island'),
  ('MKD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'North Macedonia'),
  ('MNP', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Northern Mariana Islands'),
  ('NOR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Norway'),
  ('OMN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Oman'),
  ('PAK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Pakistan'),
  ('PLW', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Palau'),
  ('PSE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Palestine, State of'),
  ('PAN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Panama'),
  ('PNG', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Papua New Guinea'),
  ('PRY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Paraguay'),
  ('PER', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Peru'),
  ('PHL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Philippines'),
  ('PCN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Pitcairn'),
  ('POL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Poland'),
  ('PRT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Portugal'),
  ('PRI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Puerto Rico'),
  ('QAT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Qatar'),
  ('REU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Reunion'),
  ('ROU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Romania'),
  ('RUS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Russian Federation'),
  ('RWA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Rwanda'),
  ('BLM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Barthelemy'),
  ('SHN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Helena, Ascension and Tristan da Cunha'),
  ('KNA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Kitts and Nevis'),
  ('LCA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Lucia'),
  ('MAF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Martin (French part)'),
  ('SPM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Pierre and Miquelon'),
  ('VCT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saint Vincent and the Grenadines'),
  ('WSM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Samoa'),
  ('SMR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'San Marino'),
  ('STP', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sao Tome and Principe'),
  ('SAU', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Saudi Arabia'),
  ('SEN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Senegal'),
  ('SRB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Serbia'),
  ('SYC', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Seychelles'),
  ('SLE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sierra Leone'),
  ('SGP', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Singapore'),
  ('SXM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sint Maarten (Dutch part)'),
  ('SVK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Slovakia'),
  ('SVN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Slovenia'),
  ('SLB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Solomon Islands'),
  ('SOM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Somalia'),
  ('ZAF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'South Africa'),
  ('SGS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'South Georgia and the South Sandwich Islands'),
  ('SSD', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'South Sudan'),
  ('ESP', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Spain'),
  ('LKA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sri Lanka'),
  ('SDN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sudan'),
  ('SUR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Suriname'),
  ('SJM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Svalbard and Jan Mayen'),
  ('SWE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sweden'),
  ('CHE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Switzerland'),
  ('SYR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Syrian Arab Republic'),
  ('TWN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Taiwan'),
  ('TJK', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Tajikistan'),
  ('TZA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Tanzania, United Republic of'),
  ('THA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Thailand'),
  ('TLS', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Timor-Leste'),
  ('TGO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Togo'),
  ('TKL', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Tokelau'),
  ('TON', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Tonga'),
  ('TTO', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Trinidad and Tobago'),
  ('TUN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Tunisia'),
  ('TUR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Turkey'),
  ('TKM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Turkmenistan'),
  ('TCA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Turks and Caicos Islands'),
  ('TUV', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Tuvalu'),
  ('UGA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Uganda'),
  ('UKR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Ukraine'),
  ('ARE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'United Arab Emirates'),
  ('GBR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'United Kingdom'),
  ('USA', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'United States of America'),
  ('UMI', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'United States Minor Outlying Islands'),
  ('URY', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Uruguay'),
  ('UZB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Uzbekistan'),
  ('VUT', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Vanuatu'),
  ('VEN', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Venezuela'),
  ('VNM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Viet Nam'),
  ('VGB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Virgin Islands (British)'),
  ('VIR', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Virgin Islands (U.S.)'),
  ('WLF', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Wallis and Futuna'),
  ('ESH', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Western Sahara'),
  ('YEM', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Yemen'),
  ('ZMB', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Zambia'),
  ('ZWE', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Zimbabwe')
on conflict (country_code) do nothing;

-- ============================================================================
-- 11-country-remove-org-scope-add-alpha2.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_country: remove organisation scoping, add alpha2
--
-- Rationale: ISO 3166-1 country codes are universal, fixed reference
-- data - they don't vary per organisation, so scoping ad_country by
-- organisation_id was wrong (copied from the Department/Location/
-- Category pattern without questioning whether it actually fit).
-- ad_language already correctly has no organisation_id and no RLS -
-- this brings ad_country in line with that same, correct pattern.
--
-- Also adds alpha2 (ISO 3166-1 alpha-2), used to build flag image
-- URLs via flagcdn.com (e.g. https://flagcdn.com/24x18/gb.png).
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

-- Drop the org-scoping policy and disable RLS - this is now a
-- shared, global lookup table, same as ad_language.
drop policy if exists "ad_country_org_isolation" on public.ad_country;
alter table public.ad_country disable row level security;

-- organisation_id no longer applies.
alter table public.ad_country drop column if exists organisation_id;

-- ISO 3166-1 alpha-2 code, for flag icon lookups. Nullable - not
-- every territory has a clean alpha-2 mapping, and existing rows
-- created before this column existed won't have one until backfilled
-- (see 12-country-alpha2-backfill.sql).
alter table public.ad_country add column if not exists alpha2 varchar(2);
comment on column public.ad_country.alpha2 is
  'ISO 3166-1 alpha-2 code, used for flag image lookups (e.g. flagcdn.com). Nullable since not every territory has a clean alpha-2 mapping.';

-- ============================================================================
-- 12-country-alpha2-backfill.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_country alpha-2 backfill
--
-- Populates alpha2 (added in 11-country-remove-org-scope-add-alpha2.sql)
-- for all 248 existing rows, mapped from each row's existing
-- alpha-3 country_code. Run this once, after the schema migration
-- above and after 10-country-lookup-data.sql has populated the base
-- 248 rows.
--
-- Safe to re-run: only updates rows whose country_code matches one
-- of the mappings below; does nothing to rows that already have the
-- correct value.
-- ============================================================================

update public.ad_country set alpha2 = v.a2 from (values
  ('AFG','AF'),('ALB','AL'),('DZA','DZ'),('ASM','AS'),('AND','AD'),('AGO','AO'),('AIA','AI'),
  ('ATA','AQ'),('ATG','AG'),('ARG','AR'),('ARM','AM'),('ABW','AW'),('AUS','AU'),('AUT','AT'),
  ('AZE','AZ'),('BHS','BS'),('BHR','BH'),('BGD','BD'),('BRB','BB'),('BLR','BY'),('BEL','BE'),
  ('BLZ','BZ'),('BEN','BJ'),('BMU','BM'),('BTN','BT'),('BOL','BO'),('BES','BQ'),('BIH','BA'),
  ('BWA','BW'),('BVT','BV'),('BRA','BR'),('IOT','IO'),('BRN','BN'),('BGR','BG'),('BFA','BF'),
  ('BDI','BI'),('CPV','CV'),('KHM','KH'),('CMR','CM'),('CAN','CA'),('CYM','KY'),('CAF','CF'),
  ('TCD','TD'),('CHL','CL'),('CHN','CN'),('CXR','CX'),('CCK','CC'),('COL','CO'),('COM','KM'),
  ('COG','CG'),('COD','CD'),('COK','CK'),('CRI','CR'),('CIV','CI'),('HRV','HR'),('CUB','CU'),
  ('CUW','CW'),('CYP','CY'),('CZE','CZ'),('DNK','DK'),('DJI','DJ'),('DMA','DM'),('DOM','DO'),
  ('ECU','EC'),('EGY','EG'),('SLV','SV'),('GNQ','GQ'),('ERI','ER'),('EST','EE'),('SWZ','SZ'),
  ('ETH','ET'),('FLK','FK'),('FRO','FO'),('FJI','FJ'),('FIN','FI'),('FRA','FR'),('GUF','GF'),
  ('PYF','PF'),('ATF','TF'),('GAB','GA'),('GMB','GM'),('GEO','GE'),('DEU','DE'),('GHA','GH'),
  ('GIB','GI'),('GRC','GR'),('GRL','GL'),('GRD','GD'),('GLP','GP'),('GUM','GU'),('GTM','GT'),
  ('GGY','GG'),('GIN','GN'),('GNB','GW'),('GUY','GY'),('HTI','HT'),('HMD','HM'),('VAT','VA'),
  ('HND','HN'),('HKG','HK'),('HUN','HU'),('ISL','IS'),('IND','IN'),('IDN','ID'),('IRN','IR'),
  ('IRQ','IQ'),('IRL','IE'),('IMN','IM'),('ISR','IL'),('ITA','IT'),('JAM','JM'),('JPN','JP'),
  ('JEY','JE'),('JOR','JO'),('KAZ','KZ'),('KEN','KE'),('KIR','KI'),('PRK','KP'),('KOR','KR'),
  ('KWT','KW'),('KGZ','KG'),('LAO','LA'),('LVA','LV'),('LBN','LB'),('LSO','LS'),('LBR','LR'),
  ('LBY','LY'),('LIE','LI'),('LTU','LT'),('LUX','LU'),('MAC','MO'),('MDG','MG'),('MWI','MW'),
  ('MYS','MY'),('MDV','MV'),('MLI','ML'),('MLT','MT'),('MHL','MH'),('MTQ','MQ'),('MRT','MR'),
  ('MUS','MU'),('MYT','YT'),('MEX','MX'),('FSM','FM'),('MDA','MD'),('MCO','MC'),('MNG','MN'),
  ('MNE','ME'),('MSR','MS'),('MAR','MA'),('MOZ','MZ'),('MMR','MM'),('NAM','NA'),('NRU','NR'),
  ('NPL','NP'),('NLD','NL'),('NCL','NC'),('NZL','NZ'),('NIC','NI'),('NER','NE'),('NGA','NG'),
  ('NIU','NU'),('NFK','NF'),('MKD','MK'),('MNP','MP'),('NOR','NO'),('OMN','OM'),('PAK','PK'),
  ('PLW','PW'),('PSE','PS'),('PAN','PA'),('PNG','PG'),('PRY','PY'),('PER','PE'),('PHL','PH'),
  ('PCN','PN'),('POL','PL'),('PRT','PT'),('PRI','PR'),('QAT','QA'),('REU','RE'),('ROU','RO'),
  ('RUS','RU'),('RWA','RW'),('BLM','BL'),('SHN','SH'),('KNA','KN'),('LCA','LC'),('MAF','MF'),
  ('SPM','PM'),('VCT','VC'),('WSM','WS'),('SMR','SM'),('STP','ST'),('SAU','SA'),('SEN','SN'),
  ('SRB','RS'),('SYC','SC'),('SLE','SL'),('SGP','SG'),('SXM','SX'),('SVK','SK'),('SVN','SI'),
  ('SLB','SB'),('SOM','SO'),('ZAF','ZA'),('SGS','GS'),('SSD','SS'),('ESP','ES'),('LKA','LK'),
  ('SDN','SD'),('SUR','SR'),('SJM','SJ'),('SWE','SE'),('CHE','CH'),('SYR','SY'),('TWN','TW'),
  ('TJK','TJ'),('TZA','TZ'),('THA','TH'),('TLS','TL'),('TGO','TG'),('TKL','TK'),('TON','TO'),
  ('TTO','TT'),('TUN','TN'),('TUR','TR'),('TKM','TM'),('TCA','TC'),('TUV','TV'),('UGA','UG'),
  ('UKR','UA'),('ARE','AE'),('GBR','GB'),('USA','US'),('UMI','UM'),('URY','UY'),('UZB','UZ'),
  ('VUT','VU'),('VEN','VE'),('VNM','VN'),('VGB','VG'),('VIR','VI'),('WLF','WF'),('ESH','EH'),
  ('YEM','YE'),('ZMB','ZM'),('ZWE','ZW')
) as v(code, a2)
where public.ad_country.country_code = v.code;

-- ============================================================================
-- 13-audience-description-user-country.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_audience.description, ad_user.country_code FK
--
-- 1. ad_audience gains a free-text "description" column.
-- 2. ad_user gains an optional FK to ad_country - nullable, since not
--    every user needs a country recorded. References ad_country's
--    actual primary key, which is country_code (varchar(3), ISO
--    3166-1 alpha-3) - NOT a UUID, since ad_country has no surrogate
--    id column (it's a shared, global lookup keyed directly by the
--    ISO code itself - see supabase/11-country-remove-org-scope-add-alpha2.sql).
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

alter table public.ad_audience add column if not exists description text;
comment on column public.ad_audience.description is
  'Free-text description of the audience - what it represents, who it''s for, etc.';

alter table public.ad_user add column if not exists country_code varchar(3)
  references public.ad_country(country_code);
comment on column public.ad_user.country_code is
  'Optional - ISO 3166-1 alpha-3 country code, FK to ad_country(country_code). Nullable: not every user needs a country recorded.';

create index if not exists idx_ad_user_country_code on public.ad_user(country_code);

-- ============================================================================
-- 14-audience-criteria.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_audience_criteria
--
-- Stores the saved query behind a "criteria-built" audience: one row
-- per (audience, criteria_type, value). Multiple rows of the SAME
-- criteria_type are OR'd together (e.g. country=GBR OR country=FRA);
-- DIFFERENT criteria_types are AND'd (e.g. country IN (...) AND
-- department IN (...)). This matches exactly how the UI presents it -
-- multi-select per criterion, criteria combined with AND.
--
-- criteria_value is stored as text rather than a typed column per
-- criteria_type, since the underlying key types differ (country_code
-- is a 3-char string, department_id/location_id are uuids) - one
-- flexible column avoids three mostly-null typed columns. The
-- application layer is responsible for casting back to the right
-- type per criteria_type when building the actual membership query.
--
-- ad_audience.is_criteria_built distinguishes a criteria-built
-- audience (membership is derived from ad_audience_criteria and
-- should be re-run when criteria change) from a manually-curated one
-- (membership is just whatever's in ad_audience_member, no query
-- behind it) - the two Audiences pages (Audiences / Audiences
-- Advanced) both write to the same ad_audience/ad_audience_member
-- tables, this flag is what tells them apart.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

alter table public.ad_audience add column if not exists is_criteria_built boolean not null default false;
comment on column public.ad_audience.is_criteria_built is
  'true if this audience''s membership is derived from ad_audience_criteria (built via Audiences Advanced) rather than manually curated.';

create table if not exists public.ad_audience_criteria (
  criteria_id     uuid primary key default gen_random_uuid(),
  audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  criteria_type   text not null check (criteria_type in ('country', 'location', 'department')),
  criteria_value  text not null,
  created_at      timestamptz not null default now()
);

comment on table public.ad_audience_criteria is
  'Saved query rows behind a criteria-built audience. Rows of the same criteria_type are OR''d; different criteria_types are AND''d. See ad_audience.is_criteria_built.';

create index if not exists idx_ad_audience_criteria_audience on public.ad_audience_criteria(audience_id);
create index if not exists idx_ad_audience_criteria_org on public.ad_audience_criteria(organisation_id);

alter table public.ad_audience_criteria enable row level security;

drop policy if exists "ad_audience_criteria_org_isolation" on public.ad_audience_criteria;
create policy "ad_audience_criteria_org_isolation"
  on public.ad_audience_criteria for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ============================================================================
-- 15-cleanup-audience-test-data.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- cleanup script for Audiences Advanced test data
--
-- Removes the 50 fake test users (and their auth rows) created to test
-- the criteria builder, plus the test locations/departments seeded
-- alongside them. Everything is scoped to the @testdata.invalid email
-- marker, so this can never touch real users.
--
-- Run this whenever you're done testing - it's safe to run multiple
-- times (each block only deletes what matches, so re-running after
-- the data's already gone is a no-op).
--
-- Order matters: child rows (ad_audience_member referencing these
-- users) must go before ad_user itself, and ad_user must go before
-- the auth.* rows underneath it, since ad_user.user_id has a foreign
-- key into auth.users.
-- ============================================================================

-- 1. Remove any audience memberships referencing the test users
--    (criteria-built audiences will simply show fewer/no matches on
--    next confirm; this doesn't touch the audiences themselves).
delete from public.ad_audience_member
where user_id in (select user_id from public.ad_user where email like '%@testdata.invalid');

-- 2. Remove the test ad_user rows.
delete from public.ad_user
where email like '%@testdata.invalid';

-- 3. Remove the underlying auth layer - identities first, then the
--    auth.users row itself (auth.identities has its own FK into
--    auth.users, same ordering reason as above).
delete from auth.identities
where identity_data->>'email' like '%@testdata.invalid';

delete from auth.users
where email like '%@testdata.invalid';

-- 4. Remove the test locations and departments seeded alongside the
--    test users. Only drops these specific seeded rows by name - if
--    you've since added a real "Sales" department or "London"
--    location of your own, check this section before running it, or
--    just skip this block and keep the lookups (harmless either way
--    since nothing else still references them once step 1-2 ran).
delete from public.ad_location
where organisation_id = '0b116913-5b27-4c19-8eb9-bf5c4787e780'
  and name in ('London', 'Manchester', 'Paris', 'Dublin', 'New York');

delete from public.ad_department
where organisation_id = '0b116913-5b27-4c19-8eb9-bf5c4787e780'
  and name in ('Sales', 'Engineering', 'Finance', 'HR', 'Marketing');

-- Verify everything's gone:
-- select count(*) from public.ad_user where email like '%@testdata.invalid';
-- select count(*) from auth.users where email like '%@testdata.invalid';

-- ============================================================================
-- 16-job-role.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_job_role lookup table, ad_user.job_role_id FK
--
-- New org-scoped lookup table for job roles, following the same
-- shape as ad_approval_type (has sort_order for drag-to-reorder).
-- Each job role belongs to a department (department_id FK), shown
-- and selectable on the lookup page per the brief.
--
-- ad_user gains an optional FK to ad_job_role - nullable, same
-- reasoning as ad_user.country_code: not every user needs a job role
-- recorded, and existing users won't have one until set.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

create table if not exists public.ad_job_role (
  job_role_id     uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  department_id   uuid references public.ad_department(department_id) on delete set null,
  name            character varying not null,
  sort_order      integer not null default 0
);

comment on table public.ad_job_role is
  'Org-scoped job role lookup. Each role optionally belongs to a department; sort_order drives the drag-to-reorder UI on the lookup page.';

create index if not exists idx_ad_job_role_org on public.ad_job_role(organisation_id);
create index if not exists idx_ad_job_role_department on public.ad_job_role(department_id);

alter table public.ad_job_role enable row level security;

drop policy if exists "ad_job_role_org_isolation" on public.ad_job_role;
create policy "ad_job_role_org_isolation"
  on public.ad_job_role for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ad_user gains an optional job role FK - nullable, same reasoning
-- as ad_user.country_code (see 13-audience-description-user-country.sql).
alter table public.ad_user add column if not exists job_role_id uuid
  references public.ad_job_role(job_role_id) on delete set null;
comment on column public.ad_user.job_role_id is
  'Optional FK to ad_job_role. Nullable: not every user needs a job role recorded.';

create index if not exists idx_ad_user_job_role on public.ad_user(job_role_id);

-- Widen ad_audience_criteria's criteria_type check constraint to
-- allow 'job_role' as a fourth criterion type, alongside the
-- existing country/location/department (see 14-audience-criteria.sql).
alter table public.ad_audience_criteria drop constraint if exists ad_audience_criteria_criteria_type_check;
alter table public.ad_audience_criteria add constraint ad_audience_criteria_criteria_type_check
  check (criteria_type in ('country', 'location', 'department', 'job_role'));

-- ============================================================================
-- 17-distribution.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_distribution, ad_distribution_audience, ad_distribution_item
--
-- A Distribution is the publishing of a document for acknowledgement to
-- one or more Audiences. This creates three tables:
--
--   ad_distribution        - the distribution itself (document, dates,
--                            settings, warning schedule, owner)
--   ad_distribution_audience - junction table linking a distribution to
--                            its target audiences (replaces the fixed
--                            audience1/2/3 column design - allows any
--                            number of audiences per distribution, ordered
--                            by sort_order)
--   ad_distribution_item   - one row per user per distribution, tracking
--                            individual acknowledgement/rejection status
--
-- Note: two column names from the original spec were typos
-- ("nofifications_sent/acknow/reject") - corrected here to
-- "notifications_sent/acknowledged/rejected" which is what the UI will
-- use. Easier to fix now than to live with forever.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

create table if not exists public.ad_distribution (
  distribution_id         uuid primary key default gen_random_uuid(),
  organisation_id         uuid not null references public.organisations(id) on delete cascade,
  name                    text not null,
  doc_id                  uuid references public.ad_document(doc_id) on delete set null,
  instructions            text,
  distribution_type       varchar(10),
  start_date              date,
  due_date                date,
  days_to_acknowledge     integer,
  first_warning_days      integer,
  first_warning_direction varchar(1),
  second_warning_days     integer,
  second_warning_direction varchar(1),
  req_acknowledgement     boolean not null default true,
  req_password            boolean not null default false,
  owner                   uuid references public.ad_user(user_id) on delete set null,
  notifications_sent      integer not null default 0,
  notifications_acknowledged integer not null default 0,
  notifications_rejected  integer not null default 0,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

comment on table public.ad_distribution is
  'A distribution is the publishing of a document for acknowledgement to one or more audiences. Audience linkage is via ad_distribution_audience (junction table, not fixed columns).';
comment on column public.ad_distribution.first_warning_direction is
  'B = before due_date, A = after due_date';
comment on column public.ad_distribution.second_warning_direction is
  'B = before due_date, A = after due_date';

create index if not exists idx_ad_distribution_org on public.ad_distribution(organisation_id);
create index if not exists idx_ad_distribution_doc on public.ad_distribution(doc_id);
create index if not exists idx_ad_distribution_owner on public.ad_distribution(owner);

alter table public.ad_distribution enable row level security;
drop policy if exists "ad_distribution_org_isolation" on public.ad_distribution;
create policy "ad_distribution_org_isolation"
  on public.ad_distribution for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── Junction: distribution <-> audience (replaces audience1/2/3 columns) ──

create table if not exists public.ad_distribution_audience (
  distribution_id uuid not null references public.ad_distribution(distribution_id) on delete cascade,
  audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  sort_order      integer not null default 0,
  primary key (distribution_id, audience_id)
);

comment on table public.ad_distribution_audience is
  'Links a distribution to its target audiences. sort_order preserves the order in which audiences were added.';

create index if not exists idx_ad_distrib_audience_dist on public.ad_distribution_audience(distribution_id);
create index if not exists idx_ad_distrib_audience_aud  on public.ad_distribution_audience(audience_id);

alter table public.ad_distribution_audience enable row level security;
drop policy if exists "ad_distribution_audience_org_isolation" on public.ad_distribution_audience;
create policy "ad_distribution_audience_org_isolation"
  on public.ad_distribution_audience for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── Per-user distribution items ──

create table if not exists public.ad_distribution_item (
  distrib_item_id   uuid primary key default gen_random_uuid(),
  organisation_id   uuid not null references public.organisations(id) on delete cascade,
  distribution_id   uuid not null references public.ad_distribution(distribution_id) on delete cascade,
  user_id           uuid not null references public.ad_user(user_id) on delete cascade,
  start_date        date,
  due_date          date,
  warning1          date,
  warning2          date,
  acknowledged      boolean not null default false,
  acknowledged_date date,
  rejected          boolean not null default false,
  rejected_date     date,
  status            varchar(10),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.ad_distribution_item is
  'One row per user per distribution. Tracks individual acknowledgement/rejection status and computed warning dates.';

create index if not exists idx_ad_distrib_item_dist on public.ad_distribution_item(distribution_id);
create index if not exists idx_ad_distrib_item_user on public.ad_distribution_item(user_id);
create index if not exists idx_ad_distrib_item_org  on public.ad_distribution_item(organisation_id);
create unique index if not exists idx_ad_distrib_item_unique on public.ad_distribution_item(distribution_id, user_id);

alter table public.ad_distribution_item enable row level security;
drop policy if exists "ad_distribution_item_org_isolation" on public.ad_distribution_item;
create policy "ad_distribution_item_org_isolation"
  on public.ad_distribution_item for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ============================================================================
-- 18-documents-title-nullable.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- make documents.title nullable
--
-- The documents module uses the 'description' column as its document
-- name field (see pages/documents/config.js, colDocDesc = 'description').
-- The 'title' column on the public.documents table was inherited from
-- the initial baseline schema but is never populated or read by the
-- module, causing every document upload to fail with a NOT NULL
-- constraint violation.
--
-- Fix: make title nullable. We don't want to silently duplicate the
-- description value into title on every insert; the column exists for
-- potential future use but shouldn't block the module from working.
-- ============================================================================

alter table public.documents alter column title drop not null;

-- ============================================================================
-- 19-documents-redirect-to-ad-tables.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- redirect documents module to ad_* tables, drop old baseline tables
--
-- The documents module was originally pointed at three baseline tables
-- inherited from the project template:
--
--   documents              (old)  →  ad_document              (correct)
--   document_files         (old)  →  ad_document_file         (new, created here)
--   document_category_lookup (old) →  ad_category             (correct)
--
-- The old tables are dropped after migrating any existing data. The
-- two orphan records in public.documents from failed test uploads are
-- also cleaned up here.
--
-- ad_category gains a sort_order column to match what the documents
-- module needs for drag-to-reorder category management.
--
-- ad_document_file is a new table mirroring document_files' shape but
-- referencing ad_document(doc_id) instead of documents(id).
--
-- Safe to re-run: create/add statements use IF NOT EXISTS / IF NOT EXISTS.
-- Drop statements are CASCADE so dependent objects go with them.
-- ============================================================================

-- ── 1. ad_category: add sort_order ───────────────────────────────────────

alter table public.ad_category add column if not exists sort_order integer not null default 0;
comment on column public.ad_category.sort_order is
  'Drag-to-reorder position used by the documents module category manager.';

-- ── 2. ad_document_file: new files table referencing ad_document ─────────

create table if not exists public.ad_document_file (
  id                uuid primary key default gen_random_uuid(),
  organisation_id   uuid not null references public.organisations(id) on delete cascade,
  doc_id            uuid not null references public.ad_document(doc_id) on delete cascade,
  file_name         text not null,
  download_file_name text,
  storage_path      text not null,
  file_size_bytes   bigint,
  mime_type         text,
  uploaded_by       uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now()
);

comment on table public.ad_document_file is
  'Files attached to ad_document records. Mirrors the old document_files table but references ad_document(doc_id).';

create index if not exists idx_ad_document_file_doc on public.ad_document_file(doc_id);
create index if not exists idx_ad_document_file_org on public.ad_document_file(organisation_id);

alter table public.ad_document_file enable row level security;
drop policy if exists "ad_document_file_org_isolation" on public.ad_document_file;
create policy "ad_document_file_org_isolation"
  on public.ad_document_file for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── 3. Clean up orphan test records then drop old tables ─────────────────

-- Orphan document_files rows first (FK dependency), then documents rows.
delete from public.document_files where document_id in (select id from public.documents);
delete from public.documents;

-- Drop old tables - CASCADE handles any remaining FK/policy dependencies.
drop table if exists public.document_files cascade;
drop table if exists public.documents cascade;
drop table if exists public.document_category_lookup cascade;

-- Reload PostgREST schema so it picks up the new tables and dropped ones.
notify pgrst, 'reload schema';

-- ============================================================================
-- 20-distribution-item-rejected-reason.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- add rejected_reason to ad_distribution_item
--
-- Stores the user-entered explanation when rejecting a document.
-- Nullable: only populated on rejection.
-- ============================================================================
alter table public.ad_distribution_item add column if not exists rejected_reason text;
comment on column public.ad_distribution_item.rejected_reason is
  'Reason given by the user when rejecting a document. Populated via the rejection modal on the acknowledge page.';

-- ============================================================================
-- 21-ad-user-manager-id.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- add manager_id to ad_user
--
-- Self-referencing FK: each user may have one manager (another ad_user row).
-- NULL means the user has no direct manager (e.g. top of the org).
-- ON DELETE SET NULL ensures removing a manager doesn't cascade-delete reports.
--
-- Planned uses:
--   - Org chart / tree view
--   - Escalation notifications (overdue acknowledgements escalate to manager)
--   - Reporting (manager sees their team's compliance status)
-- ============================================================================

alter table public.ad_user
  add column if not exists manager_id uuid
    references public.ad_user(user_id)
    on delete set null;

comment on column public.ad_user.manager_id is
  'Self-referencing FK to ad_user.user_id. NULL = no direct manager. Forms the basis of the org hierarchy for escalation and reporting.';

-- ============================================================================
-- 22-ad-document-reference.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- ad_document_reference
--
-- Stores documents that users have saved to their personal reference library
-- via the "Add to Reference" button on the acknowledge page.
--
-- A user can only reference a given document once (unique constraint).
-- Deleting the user or document cascades the reference row automatically.
-- ============================================================================

create table public.ad_document_reference (
  ad_docref_id    uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  user_id         uuid not null references public.ad_user(user_id) on delete cascade,
  doc_id          uuid not null references public.ad_document(doc_id) on delete cascade,
  date_added      date not null default current_date,

  unique (user_id, doc_id)
);

alter table public.ad_document_reference enable row level security;

create policy "Users: view own references"
  on public.ad_document_reference for select
  using (user_id = auth.uid() or _my_role() in ('admin','super_admin'));

create policy "Users: add own references"
  on public.ad_document_reference for insert
  with check (user_id = auth.uid() and organisation_id = _my_organisation_id());

create policy "Users: remove own references"
  on public.ad_document_reference for delete
  using (user_id = auth.uid() or _my_role() in ('admin','super_admin'));

comment on table public.ad_document_reference is
  'Documents saved to a user''s personal reference library from the acknowledge page.';

-- ============================================================================
-- 23-external-document-sources.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- External document sources
-- Migration: 23-external-document-sources.sql
-- ============================================================================

-- 1. Secrets vault — stores credentials for external systems
create table public.ad_external_source (
  source_id        uuid primary key default gen_random_uuid(),
  organisation_id  uuid not null references public.organisations(id) on delete cascade,
  name             text not null,
  source_type      text not null,          -- SUPABASE | URL | REST | SHAREPOINT | ONBASE
  base_url         text,
  auth_type        text not null default 'NONE',  -- NONE | BEARER | BASIC | API_KEY | OAUTH2
  auth_secret_id   uuid,                   -- vault.secrets.id — never store raw credentials
  auth_username    text,                   -- BASIC auth username (not sensitive)
  auth_header_name text default 'Authorization',
  extra_headers    jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (organisation_id, name)
);

alter table public.ad_external_source enable row level security;
create policy "Admins: manage external sources"
  on public.ad_external_source for all
  using (_my_role() in ('admin', 'super_admin'));

comment on table  public.ad_external_source is 'External document repository connections (SharePoint, OnBase, REST APIs, etc.)';
comment on column public.ad_external_source.auth_secret_id is 'References vault.secrets.id — credential never stored in plain text';

-- 2. Extend ad_document_file
alter table public.ad_document_file
  add column if not exists source_type   text not null default 'SUPABASE',
  add column if not exists source_id     uuid references public.ad_external_source(source_id) on delete set null,
  add column if not exists external_url  text,
  add column if not exists external_ref  text;

alter table public.ad_document_file
  add constraint chk_file_source check (
    (source_type = 'SUPABASE' and storage_path is not null) or
    (source_type != 'SUPABASE' and (external_url is not null or external_ref is not null))
  );

comment on column public.ad_document_file.source_type  is 'SUPABASE | URL | REST | SHAREPOINT | ONBASE';
comment on column public.ad_document_file.external_url is 'Full URL (URL type) or API path (REST/SHAREPOINT/ONBASE)';
comment on column public.ad_document_file.external_ref is 'System-specific ID: OnBase doc handle, SharePoint item ID, etc.';

-- ============================================================================
-- 24-rls-country-language.sql
-- ============================================================================

-- ============================================================================
-- approveDoc -- Enable RLS on ad_country and ad_language
-- Migration: 24-rls-country-language.sql
-- ============================================================================

alter table public.ad_country  enable row level security;
alter table public.ad_language enable row level security;

create policy "Authenticated users: read countries"
  on public.ad_country for select
  using (auth.role() = 'authenticated');

create policy "Authenticated users: read languages"
  on public.ad_language for select
  using (auth.role() = 'authenticated');

create policy "Admins: manage countries"
  on public.ad_country for all
  using (_my_role() in ('admin', 'super_admin'));

create policy "Admins: manage languages"
  on public.ad_language for all
  using (_my_role() in ('admin', 'super_admin'));

-- ============================================================================
-- dev-seed.sql
-- ============================================================================

-- ============================================================================
-- approveDoc — Dev project seed data
-- Run this on a fresh Supabase project AFTER running all migrations (01-24)
-- ============================================================================

-- Organisation
-- (organisation inserted earlier)

-- Categories
INSERT INTO ad_category (category_id, organisation_id, name) VALUES
  ('49ee0dd3-14e1-4632-8fb2-a61ab68f69af', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Policy'),
  ('01775a74-720d-4017-afdc-f250c9cca3dc', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Procedure'),
  ('1207477e-d4b3-49b8-a837-29279a9a699c', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Guidance'),
  ('071428cd-5284-4cc3-917b-c977021aa66e', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Form'),
  ('4ff0c365-f469-4dce-9ff6-7c3b861e9c31', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Other')
ON CONFLICT DO NOTHING;

-- Departments
INSERT INTO ad_department (department_id, organisation_id, name) VALUES
  ('f5924b89-273b-4197-b04e-7e7c5d290884', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sales'),
  ('98b8805c-b95d-499e-9906-2c37aa79b804', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Engineering'),
  ('09dfd755-b2c7-4cb7-a49b-3de7d9bc68ba', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Finance'),
  ('100907ca-3acb-4734-968c-7626437b0c93', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'HR'),
  ('059df2b8-2d33-4778-a234-dc4e841f33b6', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Marketing'),
  ('11c0c2c9-4313-43d8-9589-9ca1b755fe16', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Professional Services')
ON CONFLICT DO NOTHING;

-- Job roles
INSERT INTO ad_job_role (job_role_id, organisation_id, name) VALUES
  ('5958f9c1-8b7d-4cdc-998a-641ca29ae251', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Account Manager'),
  ('3786908b-decf-42a5-babd-25ae5c6204ce', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Sales Engineering'),
  ('10038fe1-a163-4779-abf4-c4b36910f6a3', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Consultant')
ON CONFLICT DO NOTHING;

-- Locations
INSERT INTO ad_location (location_id, organisation_id, name) VALUES
  ('3e17feda-6461-439c-8cc7-93f2cd34751a', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'London'),
  ('2f3af1a2-acc2-4209-b501-73ca6e3dc25b', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Manchester'),
  ('db322996-e67d-461d-a301-60e6c5d2534a', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Paris'),
  ('f17d75cd-55b0-4f97-bd47-b25185440dcc', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Dublin'),
  ('b9e1ebbe-96e6-4ab5-a2ac-2703c93612b2', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'New York'),
  ('09fff245-6658-4cc6-8332-671e951b4693', '0b116913-5b27-4c19-8eb9-bf5c4787e780', 'Remote / Hybrid')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- After running this, invite users via the app (Admin → Users → Invite)
-- Auth users cannot be copied between Supabase projects.
-- ============================================================================
