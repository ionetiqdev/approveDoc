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
