-- ============================================================================
-- approveDoc -- ad_distribution, ad_distribution_audience, ad_distribution_item
--
-- A Distribution is the publishing of a document for acknowledgement to
-- one or more Audiences. This creates three tables:
--
--   ad_distribution        - the distribution itself (document, dates,
--                            settings, warning schedule, owner)
--   ad_distribution_audience - junction table linking a distribution to
--                            its target audiences (replaces the fixed
--                            audience1/2/3 column design - allows any
--                            number of audiences per distribution, ordered
--                            by sort_order)
--   ad_distribution_item   - one row per user per distribution, tracking
--                            individual acknowledgement/rejection status
--
-- Note: two column names from the original spec were typos
-- ("nofifications_sent/acknow/reject") - corrected here to
-- "notifications_sent/acknowledged/rejected" which is what the UI will
-- use. Easier to fix now than to live with forever.
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================================

create table if not exists public.ad_distribution (
  distribution_id         uuid primary key default gen_random_uuid(),
  organisation_id         uuid not null references public.organisations(id) on delete cascade,
  name                    text not null,
  doc_id                  uuid references public.ad_document(doc_id) on delete set null,
  instructions            text,
  distribution_type       varchar(10),
  start_date              date,
  due_date                date,
  days_to_acknowledge     integer,
  first_warning_days      integer,
  first_warning_direction varchar(1),
  second_warning_days     integer,
  second_warning_direction varchar(1),
  req_acknowledgement     boolean not null default true,
  req_password            boolean not null default false,
  owner                   uuid references public.ad_user(user_id) on delete set null,
  notifications_sent      integer not null default 0,
  notifications_acknowledged integer not null default 0,
  notifications_rejected  integer not null default 0,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

comment on table public.ad_distribution is
  'A distribution is the publishing of a document for acknowledgement to one or more audiences. Audience linkage is via ad_distribution_audience (junction table, not fixed columns).';
comment on column public.ad_distribution.first_warning_direction is
  'B = before due_date, A = after due_date';
comment on column public.ad_distribution.second_warning_direction is
  'B = before due_date, A = after due_date';

create index if not exists idx_ad_distribution_org on public.ad_distribution(organisation_id);
create index if not exists idx_ad_distribution_doc on public.ad_distribution(doc_id);
create index if not exists idx_ad_distribution_owner on public.ad_distribution(owner);

alter table public.ad_distribution enable row level security;
drop policy if exists "ad_distribution_org_isolation" on public.ad_distribution;
create policy "ad_distribution_org_isolation"
  on public.ad_distribution for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── Junction: distribution <-> audience (replaces audience1/2/3 columns) ──

create table if not exists public.ad_distribution_audience (
  distribution_id uuid not null references public.ad_distribution(distribution_id) on delete cascade,
  audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  sort_order      integer not null default 0,
  primary key (distribution_id, audience_id)
);

comment on table public.ad_distribution_audience is
  'Links a distribution to its target audiences. sort_order preserves the order in which audiences were added.';

create index if not exists idx_ad_distrib_audience_dist on public.ad_distribution_audience(distribution_id);
create index if not exists idx_ad_distrib_audience_aud  on public.ad_distribution_audience(audience_id);

alter table public.ad_distribution_audience enable row level security;
drop policy if exists "ad_distribution_audience_org_isolation" on public.ad_distribution_audience;
create policy "ad_distribution_audience_org_isolation"
  on public.ad_distribution_audience for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── Per-user distribution items ──

create table if not exists public.ad_distribution_item (
  distrib_item_id   uuid primary key default gen_random_uuid(),
  organisation_id   uuid not null references public.organisations(id) on delete cascade,
  distribution_id   uuid not null references public.ad_distribution(distribution_id) on delete cascade,
  user_id           uuid not null references public.ad_user(user_id) on delete cascade,
  start_date        date,
  due_date          date,
  warning1          date,
  warning2          date,
  acknowledged      boolean not null default false,
  acknowledged_date date,
  rejected          boolean not null default false,
  rejected_date     date,
  status            varchar(10),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.ad_distribution_item is
  'One row per user per distribution. Tracks individual acknowledgement/rejection status and computed warning dates.';

create index if not exists idx_ad_distrib_item_dist on public.ad_distribution_item(distribution_id);
create index if not exists idx_ad_distrib_item_user on public.ad_distribution_item(user_id);
create index if not exists idx_ad_distrib_item_org  on public.ad_distribution_item(organisation_id);
create unique index if not exists idx_ad_distrib_item_unique on public.ad_distribution_item(distribution_id, user_id);

alter table public.ad_distribution_item enable row level security;
drop policy if exists "ad_distribution_item_org_isolation" on public.ad_distribution_item;
create policy "ad_distribution_item_org_isolation"
  on public.ad_distribution_item for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());
