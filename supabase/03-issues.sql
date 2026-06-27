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
returns trigger language plpgsql as $$
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
returns trigger language plpgsql as $$
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
