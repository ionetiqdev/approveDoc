-- ============================================================================
-- approveDoc - Video Compliance Controls
-- Migration: 26-video-compliance.sql
-- Run on DEV first, then production when ready to promote
-- ============================================================================

-- ── 1. Org-wide video compliance settings ────────────────────────────────────

alter table public.organisations
add column if not exists video_watch_threshold_pct integer not null default 100;

alter table public.organisations
add column if not exists video_seek_lock_enabled boolean not null default true;

comment on column public.organisations.video_watch_threshold_pct is
  'Percentage of a video a user must watch before the Acknowledge button is enabled. 1-100. Default 100 (must watch to the end). Set per organisation, admin+ only.';

comment on column public.organisations.video_seek_lock_enabled is
  'When true, users cannot seek/skip ahead of the furthest point they have watched. Rewatching earlier sections is always allowed. Set per organisation, admin+ only.';

alter table public.organisations
drop constraint if exists chk_video_watch_threshold_pct;
alter table public.organisations
add constraint chk_video_watch_threshold_pct
  check (video_watch_threshold_pct between 1 and 100);

-- ── 2. Per-user video progress on ad_distribution_item ──────────────────────

alter table public.ad_distribution_item
add column if not exists video_watched_seconds numeric;

alter table public.ad_distribution_item
add column if not exists video_duration_seconds numeric;

comment on column public.ad_distribution_item.video_watched_seconds is
  'Furthest point (seconds) the user has watched into the video. Used to resume playback and to gate Acknowledge against the org''s video_watch_threshold_pct.';

comment on column public.ad_distribution_item.video_duration_seconds is
  'Total duration (seconds) of the video, captured on first playback. Used alongside video_watched_seconds to compute watched percentage.';

-- ── 3. Admin-scoped setter ────────────────────────────────────────────────
-- organisations UPDATE is restricted to super_admin by RLS (see
-- 01-core-schema.sql). Video compliance settings should be editable by
-- 'admin' too, so this security-definer function checks the caller's role
-- itself and updates only these two columns on the caller's own org -
-- it does not grant any broader access to the organisations table.

create or replace function public.update_video_compliance_settings(
  p_watch_pct integer,
  p_seek_lock boolean
)
returns void language plpgsql security definer as $$
begin
  if public._my_role() not in ('admin', 'super_admin') then
    raise exception 'Only admin or super_admin can change video compliance settings';
  end if;

  if p_watch_pct < 1 or p_watch_pct > 100 then
    raise exception 'Watch percentage must be between 1 and 100';
  end if;

  update public.organisations
  set video_watch_threshold_pct = p_watch_pct,
      video_seek_lock_enabled   = p_seek_lock
  where id = public._my_organisation_id();
end;
$$;
