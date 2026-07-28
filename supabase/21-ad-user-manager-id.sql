-- ============================================================================
-- approveDoc -- add manager_id to ad_user
--
-- Self-referencing FK: each user may have one manager (another ad_user row).
-- NULL means the user has no direct manager (e.g. top of the org).
-- ON DELETE SET NULL ensures removing a manager doesn't cascade-delete reports.
--
-- Planned uses:
--   - Org chart / tree view
--   - Escalation notifications (overdue acknowledgements escalate to manager)
--   - Reporting (manager sees their team's compliance status)
-- ============================================================================

alter table public.ad_user
  add column if not exists manager_id uuid
    references public.ad_user(user_id)
    on delete set null;

comment on column public.ad_user.manager_id is
  'Self-referencing FK to ad_user.user_id. NULL = no direct manager. Forms the basis of the org hierarchy for escalation and reporting.';
