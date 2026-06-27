-- ============================================================
-- {{PROJECT_NAME}} - Sample/placeholder data
--
-- Run AFTER 01-core-schema.sql. OPTIONAL - intended to give a brand
-- new project something real to look at and click through
-- immediately, rather than starting from a completely empty
-- database. Safe to skip entirely for a project that doesn't want
-- placeholder data.
--
-- Creates:
--   - An organisation called "ionetiq" (idempotent - re-running
--     this script will not create a duplicate).
--   - template_customer, a placeholder business-entity table with
--     RLS following the same organisation-scoped pattern as
--     everything else in this database.
--   - 10 sample template_customer rows attached to "ionetiq".
--
-- To remove all of this later, run 04-sample-data-cleanup.sql -
-- that script removes exactly what this one creates, nothing else.
-- ============================================================


-- ── 1. The "ionetiq" placeholder organisation ────────────────────

insert into public.organisations (name, reference, description, active)
select 'ionetiq', 'IONETIQ', 'Default placeholder organisation created by the sample data script.', true
where not exists (select 1 from public.organisations where name = 'ionetiq');


-- ── 2. template_customer table ───────────────────────────────────

create table if not exists public.template_customer (
  id              uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  name            text not null,
  reference       text,
  contact_name    text,
  email           text,
  phone           text,
  address         text,
  city            text,
  postcode        text,
  status          text not null default 'prospect' check (status in ('active', 'inactive', 'prospect')),
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_template_customer_org on public.template_customer(organisation_id);

comment on table public.template_customer is
  'Placeholder business entity, for demonstrating the standard organisation-scoped CRUD pattern. Safe to rename/repurpose or drop entirely for a real project - see 04-sample-data-cleanup.sql to remove the seed data without affecting any other table.';


-- ── 3. RLS on template_customer ──────────────────────────────────
-- Same shape as organisations/documents: super_admin full access
-- across every organisation, everyone else scoped to their own
-- organisation. view role is read-only (no write policy at all).

alter table public.template_customer enable row level security;

drop policy if exists "Super admins: full access to template_customer" on public.template_customer;
create policy "Super admins: full access to template_customer"
  on public.template_customer for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view template_customer in own organisation" on public.template_customer;
create policy "Users: view template_customer in own organisation"
  on public.template_customer for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage template_customer in own organisation" on public.template_customer;
create policy "Editors: manage template_customer in own organisation"
  on public.template_customer for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );


-- ── 4. Sample rows, attached to "ionetiq" ────────────────────────
-- Only inserted if template_customer is currently empty, so
-- re-running this script doesn't keep duplicating the same 10 rows.

insert into public.template_customer (organisation_id, name, reference, contact_name, email, phone, address, city, postcode, status, notes)
select o.id, c.name, c.reference, c.contact_name, c.email, c.phone, c.address, c.city, c.postcode, c.status, null
from public.organisations o
cross join (values
  ('Harrington & Bell Solicitors',       'HB-2201',  'Sarah Harrington',  'sarah.harrington@harringtonbell.co.uk',  '0118 957 3042', '14 Castle Street',                   'Reading',                'RG1 7SB',  'active'),
  ('Oakfield Manor Care Home',           'OMC-0087', 'David Oakfield',    'admin@oakfieldmanor.org.uk',             '01753 622 918', 'Oakfield Lane',                      'Slough',                 'SL1 4QR',  'active'),
  ('Bridgeway Logistics Ltd',            'BWL-3390', 'Tony Marsh',        'tony.marsh@bridgewaylogistics.com',      '020 8946 7721', 'Unit 4, Riverside Park',             'Wandsworth',             'SW18 1NN', 'active'),
  ('Hartley & Sons Builders',            'HSB-1145', 'Mick Hartley',      'mick@hartleyandsons.co.uk',              '01494 873 256', '22 Mill Road',                       'High Wycombe',           'HP11 2LX', 'prospect'),
  ('Wren & Finch Architects',            'WFA-0762', 'Eleanor Finch',     'eleanor@wrenfinch.studio',                '020 7946 0834', '9 Bermondsey Square',                'London',                 'SE1 3UN',  'active'),
  ('Cotswold Fine Foods',                'CFF-2208', 'Pamela Whitcombe',  'pwhitcombe@cotswoldfinefoods.co.uk',     '01285 640 119', 'Unit 2, Cirencester Business Park',  'Cirencester',            'GL7 1XR',  'inactive'),
  ('Thameside Dental Practice',          'TDP-0915', 'Dr. Anjali Rao',    'reception@thamesidedental.co.uk',        '01784 251 663', '5 High Street',                      'Staines-upon-Thames',    'TW18 4EP', 'active'),
  ('Penrose Marketing Group',            'PMG-3471', 'Olivia Penrose',    'olivia@penrosemarketing.co.uk',          '0117 925 4408', '31 Park Row',                        'Bristol',                'BS1 5LR',  'prospect'),
  ('Albright Electrical Services',       'AES-1623', 'Kevin Albright',    'kevin@albrightelectrical.co.uk',         '01622 759 340', '8 Forge Lane',                       'Maidstone',              'ME15 6TJ', 'active'),
  ('Sterling & Vane Insurance Brokers',  'SVI-0598', 'Claire Vane',       'claire.vane@sterlingvane.co.uk',         '020 3551 9027', '17 Lombard Court',                   'London',                 'EC3V 9AA', 'inactive')
) as c(name, reference, contact_name, email, phone, address, city, postcode, status)
where o.name = 'ionetiq'
and not exists (select 1 from public.template_customer limit 1);
