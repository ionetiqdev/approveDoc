-- ============================================================================
-- approveDoc -- add rejected_reason to ad_distribution_item
--
-- Stores the user-entered explanation when rejecting a document.
-- Nullable: only populated on rejection.
-- ============================================================================
alter table public.ad_distribution_item add column if not exists rejected_reason text;
comment on column public.ad_distribution_item.rejected_reason is
  'Reason given by the user when rejecting a document. Populated via the rejection modal on the acknowledge page.';
