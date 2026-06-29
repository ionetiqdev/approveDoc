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
