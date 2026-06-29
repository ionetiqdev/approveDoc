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
