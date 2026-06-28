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
