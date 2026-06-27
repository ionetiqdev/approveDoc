-- ============================================================
-- {{PROJECT_NAME}} - Remove sample/placeholder data
--
-- Reverses 04-sample-data.sql exactly: drops the template_customer
-- table entirely (not just its rows) and removes the "ionetiq"
-- organisation it created. Does NOT touch any other table, any
-- other organisation, or any user/profile - only what
-- 04-sample-data.sql itself created.
--
-- Run this once you've used the sample data to see the template
-- working, and are ready to start on the real project instead.
--
-- WARNING: if you assigned any real user to the "ionetiq"
-- organisation while testing (via the Users admin page), deleting
-- it here will set that user's organisation_id to null (the FK is
-- ON DELETE SET NULL, not cascade) - they won't be deleted, but
-- they'll have no organisation until you reassign them. Check
-- Admin > Users for anyone still pointing at "ionetiq" before
-- running this.
-- ============================================================

drop table if exists public.template_customer;

delete from public.organisations
where name = 'ionetiq'
  and reference = 'IONETIQ'
  and description = 'Default placeholder organisation created by the sample data script.';
