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
