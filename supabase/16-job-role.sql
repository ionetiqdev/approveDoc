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
