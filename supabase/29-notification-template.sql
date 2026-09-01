-- ============================================================================
-- approveDoc - Notification Templates
-- Migration: 29-notification-template.sql
-- Run on DEV first, then production when ready to promote
--
-- This table was created directly on dev during the "Notification model
-- with Make.com and webhooks" session and had no committed migration until
-- now - this file brings the repo in line with what's actually live.
--
-- KNOWN LIMITATION (carried over from that session, not fixed here):
-- RLS is currently a permissive prototype policy allowing full anon access,
-- and organisation_id is nullable. Both need tightening (org-scoped RLS,
-- not-null organisation_id) before this is production-safe - flagged as a
-- TODO in that session, still outstanding.
-- ============================================================================

create table if not exists public.ad_notification_template (
  template_id     uuid primary key default gen_random_uuid(),
  organisation_id uuid references public.organisations(id) on delete cascade,
  name            varchar not null,
  message_title   text not null,
  message_text    text not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.ad_notification_template is
  'Reusable message templates for notifications. message_text supports {firstname}/{lastname} tokens (see send-notification-direct). Prototype: RLS and organisation_id nullability need tightening before production use.';

alter table public.ad_notification_template enable row level security;
drop policy if exists "prototype_anon_all_notification_template" on public.ad_notification_template;
create policy "prototype_anon_all_notification_template"
  on public.ad_notification_template for all
  to anon
  using (true);
