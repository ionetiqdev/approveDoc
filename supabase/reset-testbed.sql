-- ============================================================================
-- approveDoc - Test Bed Reset Script
-- ============================================================================
-- Clears all document, audience and distribution data.
-- Preserves: users, lookup tables, organisations, profiles, issues.
--
-- Run order respects FK constraints (children before parents).
-- Safe to run multiple times (idempotent).
-- ============================================================================

-- 1. Distribution items (references distributions and users)
truncate table public.ad_distribution_item restart identity cascade;

-- 2. Distribution audience links (references distributions and audiences)
truncate table public.ad_distribution_audience restart identity cascade;

-- 3. Distributions (references documents and users)
truncate table public.ad_distribution restart identity cascade;

-- 4. Audience members (references audiences and users)
truncate table public.ad_audience_member restart identity cascade;

-- 5. Audience criteria (references audiences)
truncate table public.ad_audience_criteria restart identity cascade;

-- 6. Audiences
truncate table public.ad_audience restart identity cascade;

-- 7. Document files (references documents)
truncate table public.ad_document_file restart identity cascade;

-- 8. Document versions (references documents)
truncate table public.ad_document_version restart identity cascade;

-- 9. Related documents (references documents)
truncate table public.ad_related_document restart identity cascade;

-- 10. Documents
truncate table public.ad_document restart identity cascade;

-- ============================================================================
-- Tables intentionally NOT cleared:
--   ad_user, profiles, organisations
--   ad_approval_type, ad_category, ad_country, ad_department,
--   ad_job_role, ad_language, ad_location
--   ad_notification, audit_log
--   issues_*
-- ============================================================================

select
  (select count(*) from public.ad_document)           as documents,
  (select count(*) from public.ad_audience)            as audiences,
  (select count(*) from public.ad_distribution)        as distributions,
  (select count(*) from public.ad_distribution_item)   as distribution_items,
  (select count(*) from public.ad_audience_member)     as audience_members;
