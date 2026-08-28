-- ============================================================================
-- approveDoc - Notifications (replaces the old fixed 2-slot "Warning" system)
-- Migration: 27-notifications.sql
-- Run on DEV first, then production when ready to promote
--
-- Renames the concept from "Warning" to "Notification" throughout, and
-- replaces the two fixed first_warning_*/second_warning_* columns on
-- ad_distribution (plus warning1/warning2 on ad_distribution_item) with:
--
--   ad_distribution_notification       - the RULES: unlimited notifications
--                                        per distribution, each with its own
--                                        days/direction, recipient targeting
--                                        (the user themself, their line
--                                        manager, or a specific chosen
--                                        person), and delivery channel.
--   ad_distribution_item_notification  - the INSTANCES: one row per rule x
--                                        per distribution item, with the
--                                        resolved recipient, computed
--                                        scheduled date, and send status.
--                                        Actual sending is a later phase -
--                                        the status column exists now so
--                                        that phase doesn't need another
--                                        migration.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

-- ── 1. Notification rules ────────────────────────────────────────────────

create table if not exists public.ad_distribution_notification (
  notification_id  uuid primary key default gen_random_uuid(),
  organisation_id   uuid not null references public.organisations(id) on delete cascade,
  distribution_id   uuid not null references public.ad_distribution(distribution_id) on delete cascade,
  days              integer not null,
  direction         varchar(1) not null,
  recipient_type    varchar(10) not null default 'USER',
  specific_user_id  uuid references public.ad_user(user_id) on delete set null,
  channel           varchar(10) not null default 'EMAIL',
  sort_order        integer not null default 0,
  enabled           boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.ad_distribution_notification is
  'Notification rules for a distribution. Unlimited per distribution (replaces the old fixed first_warning/second_warning columns). Each rule fires N days before/after the due date, to a target recipient, via a chosen channel.';
comment on column public.ad_distribution_notification.direction is
  'B = before due_date, A = after due_date';
comment on column public.ad_distribution_notification.recipient_type is
  'USER = the distribution item''s own user, MANAGER = that user''s ad_user.manager_id, SPECIFIC = specific_user_id on this rule';
comment on column public.ad_distribution_notification.specific_user_id is
  'Only used when recipient_type = SPECIFIC. The chosen recipient regardless of who the distribution item belongs to.';
comment on column public.ad_distribution_notification.channel is
  'EMAIL, SMS, WHATSAPP, SLACK, or OTHER. Delivery itself is a later phase - this records the intended channel now.';

alter table public.ad_distribution_notification
drop constraint if exists chk_notification_direction;
alter table public.ad_distribution_notification
add constraint chk_notification_direction check (direction in ('B', 'A'));

alter table public.ad_distribution_notification
drop constraint if exists chk_notification_recipient_type;
alter table public.ad_distribution_notification
add constraint chk_notification_recipient_type check (recipient_type in ('USER', 'MANAGER', 'SPECIFIC'));

alter table public.ad_distribution_notification
drop constraint if exists chk_notification_channel;
alter table public.ad_distribution_notification
add constraint chk_notification_channel check (channel in ('EMAIL', 'SMS', 'WHATSAPP', 'SLACK', 'OTHER'));

create index if not exists idx_ad_dist_notif_dist on public.ad_distribution_notification(distribution_id);
create index if not exists idx_ad_dist_notif_org  on public.ad_distribution_notification(organisation_id);

alter table public.ad_distribution_notification enable row level security;
drop policy if exists "ad_distribution_notification_org_isolation" on public.ad_distribution_notification;
create policy "ad_distribution_notification_org_isolation"
  on public.ad_distribution_notification for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── 2. Notification instances (computed per distribution item) ──────────

create table if not exists public.ad_distribution_item_notification (
  item_notification_id uuid primary key default gen_random_uuid(),
  organisation_id       uuid not null references public.organisations(id) on delete cascade,
  distrib_item_id       uuid not null references public.ad_distribution_item(distrib_item_id) on delete cascade,
  notification_id       uuid not null references public.ad_distribution_notification(notification_id) on delete cascade,
  recipient_user_id     uuid not null references public.ad_user(user_id) on delete cascade,
  scheduled_date         date,
  status                varchar(10) not null default 'PENDING',
  sent_at               timestamptz,
  created_at            timestamptz not null default now()
);

comment on table public.ad_distribution_item_notification is
  'One row per notification rule x per distribution item. recipient_user_id is the resolved recipient (may differ from the item''s own user if the rule targets a manager or a specific person). Sending is a later phase - status/sent_at exist now so that phase does not need another migration.';
comment on column public.ad_distribution_item_notification.status is
  'PENDING, SENT, or FAILED.';

alter table public.ad_distribution_item_notification
drop constraint if exists chk_item_notification_status;
alter table public.ad_distribution_item_notification
add constraint chk_item_notification_status check (status in ('PENDING', 'SENT', 'FAILED'));

create index if not exists idx_ad_item_notif_item      on public.ad_distribution_item_notification(distrib_item_id);
create index if not exists idx_ad_item_notif_rule       on public.ad_distribution_item_notification(notification_id);
create index if not exists idx_ad_item_notif_recipient  on public.ad_distribution_item_notification(recipient_user_id);
create index if not exists idx_ad_item_notif_org        on public.ad_distribution_item_notification(organisation_id);
create index if not exists idx_ad_item_notif_scheduled  on public.ad_distribution_item_notification(scheduled_date) where status = 'PENDING';

alter table public.ad_distribution_item_notification enable row level security;
drop policy if exists "ad_distribution_item_notification_org_isolation" on public.ad_distribution_item_notification;
create policy "ad_distribution_item_notification_org_isolation"
  on public.ad_distribution_item_notification for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── 3. Drop the old fixed 2-slot columns ─────────────────────────────────

alter table public.ad_distribution drop column if exists first_warning_days;
alter table public.ad_distribution drop column if exists first_warning_direction;
alter table public.ad_distribution drop column if exists second_warning_days;
alter table public.ad_distribution drop column if exists second_warning_direction;

alter table public.ad_distribution_item drop column if exists warning1;
alter table public.ad_distribution_item drop column if exists warning2;

-- ── 4. Rebuild build_distribution_items to populate the new tables ──────

create or replace function public.build_distribution_items(p_distribution_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  v_dist          public.ad_distribution%rowtype;
  v_rows_inserted integer := 0;
begin
  select * into v_dist
  from public.ad_distribution
  where distribution_id = p_distribution_id;

  if not found then
    raise exception 'Distribution % not found', p_distribution_id;
  end if;

  -- Insert one item per unique user across all audiences linked to this
  -- distribution. DISTINCT ensures a user appearing in multiple audiences
  -- only gets one row. ON CONFLICT DO NOTHING makes this idempotent.
  with target_users as (
    select distinct am.user_id
    from public.ad_distribution_audience da
    join public.ad_audience_member am
      on am.audience_id = da.audience_id
     and am.organisation_id = da.organisation_id
    where da.distribution_id = p_distribution_id
  )
  insert into public.ad_distribution_item (
    organisation_id,
    distribution_id,
    user_id,
    start_date,
    due_date,
    acknowledged,
    rejected,
    status
  )
  select
    v_dist.organisation_id,
    p_distribution_id,
    tu.user_id,
    v_dist.start_date,
    v_dist.due_date,
    false,
    false,
    'PENDING'
  from target_users tu
  on conflict (distribution_id, user_id) do nothing;

  get diagnostics v_rows_inserted = row_count;

  -- Build notification instances for every enabled rule x every item that
  -- doesn't already have one for that rule (idempotent, same as above -
  -- safe to call again if audiences or notification rules change).
  insert into public.ad_distribution_item_notification (
    organisation_id,
    distrib_item_id,
    notification_id,
    recipient_user_id,
    scheduled_date,
    status
  )
  select
    v_dist.organisation_id,
    di.distrib_item_id,
    dn.notification_id,
    case dn.recipient_type
      when 'MANAGER'   then coalesce(u.manager_id, di.user_id)
      when 'SPECIFIC'  then coalesce(dn.specific_user_id, di.user_id)
      else di.user_id
    end as recipient_user_id,
    case dn.direction
      when 'B' then v_dist.due_date - dn.days
      when 'A' then v_dist.due_date + dn.days
      else null
    end as scheduled_date,
    'PENDING'
  from public.ad_distribution_item di
  join public.ad_distribution_notification dn
    on dn.distribution_id = di.distribution_id
   and dn.enabled = true
  join public.ad_user u
    on u.user_id = di.user_id
  where di.distribution_id = p_distribution_id
  and not exists (
    select 1 from public.ad_distribution_item_notification din
    where din.distrib_item_id = di.distrib_item_id
    and din.notification_id = dn.notification_id
  );

  return v_rows_inserted;
end;
$$;

comment on function public.build_distribution_items(uuid) is
  'Creates ad_distribution_item rows for all users in all audiences linked to a distribution, and ad_distribution_item_notification rows for every enabled notification rule. Safe to call multiple times - existing rows are not overwritten, new ones (from audience or notification rule changes) are added.';
