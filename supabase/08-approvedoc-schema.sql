-- ============================================================================
-- approveDoc v1.0 — Compliance / Acknowledgement Schema
-- Migration: 04-approvedoc-schema.sql
-- Project: nkwpqboslnbeifyaegos (approveDoc v1.0)
-- Repo: github.com/ionetiqdev/approveDoc.git
-- Generated: 27/06/2026
--
-- Follows on from existing migrations already applied to this project:
--   01-core-schema.sql
--   02-documents.sql
--   03-issues.sql
--
-- This migration adds the user/audience/assignment/compliance-tracking layer
-- (ad_* tables) plus audit_log. It assumes 01-03 have already run, in
-- particular that public.organisations already exists (created in
-- 01-core-schema.sql) and that public.profiles already exists and owns the
-- user's avatar (also from 01-core-schema.sql or equivalent).
--
-- IMPORTANT: if any table below (e.g. ad_document, ad_category) was already
-- partially created by 02-documents.sql, review for naming collisions before
-- running — this migration uses "create table if not exists" so it will NOT
-- overwrite an existing table's columns, it will just silently skip creating
-- it. Diff against 02-documents.sql first if unsure.
--
-- ASSUMPTIONS / DECISIONS (confirmed with Mike):
--   1. ad_department: duplicate definition in source CSV removed; using the
--      fuller version (department_id PK, organisation_id FK, name).
--   2. ad_audience.audience_id is the PK of ad_audience.
--   3. ad_approval_type is a NEW table (not in original CSV) to support
--      ad_audience.approval_type_id as a proper FK.
--   4. ad_related_document.doc_id / related_doc_id both reference ad_document
--      (CSV listed doc_id -> ad_audience, treated as a copy-paste error since
--      this is clearly a document-to-document "related document" link).
--   5. ad_user.avatar is DROPPED. Avatar is owned by the existing `profiles`
--      table (which, like ad_user, extends auth.users). Apps should join
--      profiles.avatar for display rather than duplicating it on ad_user.
--   6. organisations table is assumed to ALREADY EXIST — referenced via FK
--      only, not created here. If it does not exist yet, run
--      00_organisations_prereq.sql first.
--   7. ad_user.user_id FKs to auth.users(id), consistent with Supabase
--      convention for tables that extend the built-in user.
--   8. datetime -> timestamptz, json -> jsonb (Postgres/Supabase best practice).
--   9. RLS: organisation-scoped policies applied to every table that carries
--      an organisation_id column, based on the requesting user's own
--      organisation_id (resolved via ad_user). See section 4.
--
-- Run this whole script in the Supabase SQL editor for project
-- nkwpqboslnbeifyaegos (approveDoc v1.0). It is idempotent (safe to re-run)
-- via "IF NOT EXISTS" / "CREATE OR REPLACE" throughout — but see the
-- collision note above regarding 02-documents.sql before first run.
-- ============================================================================


-- ============================================================================
-- SECTION 0 — Extensions
-- ============================================================================

create extension if not exists "pgcrypto"; -- gen_random_uuid()


-- ============================================================================
-- SECTION 1 — Lookup / reference tables (no dependencies on ad_user)
-- ============================================================================

-- --------------------------------------------------------------------------
-- ad_language — locale reference (PK is the locale code itself, e.g. en-GB)
-- --------------------------------------------------------------------------
create table if not exists public.ad_language (
    locale      varchar(5) primary key,
    name        varchar not null
);

comment on table public.ad_language is 'Supported locales for user language preference.';

-- --------------------------------------------------------------------------
-- ad_country — country reference, scoped per organisation
-- --------------------------------------------------------------------------
create table if not exists public.ad_country (
    country_code    varchar(3) primary key,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_country is 'Country reference list, per organisation.';

-- --------------------------------------------------------------------------
-- ad_department
-- --------------------------------------------------------------------------
create table if not exists public.ad_department (
    department_id   uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_department is 'Departments within an organisation.';

-- --------------------------------------------------------------------------
-- ad_location
-- --------------------------------------------------------------------------
create table if not exists public.ad_location (
    location_id    uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_location is 'Physical/regional locations within an organisation.';

-- --------------------------------------------------------------------------
-- ad_category — document categories
-- --------------------------------------------------------------------------
create table if not exists public.ad_category (
    category_id     uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    name            varchar not null
);

comment on table public.ad_category is 'Categories used to classify documents.';

-- --------------------------------------------------------------------------
-- ad_approval_type — NEW table, supports ad_audience.approval_type_id
-- --------------------------------------------------------------------------
create table if not exists public.ad_approval_type (
    approval_type_id uuid primary key default gen_random_uuid(),
    organisation_id  uuid not null references public.organisations(id) on delete cascade,
    name             varchar not null,
    sort_order       int
);

comment on table public.ad_approval_type is 'Defines the approval workflow types selectable on an audience.';


-- ============================================================================
-- SECTION 2 — ad_user (extends auth.users) and dependents
-- ============================================================================

-- --------------------------------------------------------------------------
-- ad_user
-- Self-referencing FKs (manager_id, senior_manager_id) deferred until after
-- table creation isn't required in Postgres provided the table already
-- exists at the point the constraint is declared — which it does here.
-- --------------------------------------------------------------------------
create table if not exists public.ad_user (
    user_id                 uuid primary key references auth.users(id) on delete cascade,
    organisation_id         uuid not null references public.organisations(id) on delete cascade,
    first_name              varchar,
    last_name               varchar,
    known_name              varchar,
    email                   varchar,
    mobile_number           varchar,
    mobile_cc               varchar,
    status                  varchar,
    language_id             varchar(5) references public.ad_language(locale),
    location_id             uuid references public.ad_location(location_id),
    department_id           uuid references public.ad_department(department_id),
    job_title               varchar,
    manager_id              uuid references public.ad_user(user_id),
    senior_manager_id       uuid references public.ad_user(user_id),
    role_user               boolean default true,
    role_admin              boolean default false,
    role_reporting          boolean default false,
    role_publisher          boolean default false,
    role_admin_assistant    boolean default false,
    delegated               boolean default false
    -- NOTE: avatar intentionally omitted — see profiles.avatar instead.
);

comment on table public.ad_user is 'approveDoc-specific extension of auth.users. Avatar lives on profiles, not here.';


-- ============================================================================
-- SECTION 3 — Documents, versions, audiences, assignments, state, audit
-- ============================================================================

-- --------------------------------------------------------------------------
-- ad_document
-- Note: current_version_id is added as a FK once ad_document_version exists
-- (see ALTER below) to avoid a circular create-time dependency.
-- --------------------------------------------------------------------------
create table if not exists public.ad_document (
    doc_id              uuid primary key default gen_random_uuid(),
    organisation_id     uuid not null references public.organisations(id) on delete cascade,
    name                varchar not null,
    description         text,
    category_id         uuid references public.ad_category(category_id),
    helptext            varchar,
    current_version_id  uuid -- FK added below after ad_document_version exists
);

comment on table public.ad_document is 'Master document record (a "policy"); version-specific content lives in ad_document_version.';

-- --------------------------------------------------------------------------
-- ad_document_version
-- --------------------------------------------------------------------------
create table if not exists public.ad_document_version (
    id                      uuid primary key default gen_random_uuid(),
    document_id             uuid not null references public.ad_document(doc_id) on delete cascade,
    major_version_number    int not null,
    minor_version_number    int not null default 0,
    source_file_url         text,
    pdf_file_url            text,
    change_summary          text,
    created_at              timestamptz not null default now()
);

comment on table public.ad_document_version is 'Each upload/revision of a document. source_file_url = original upload, pdf_file_url = PDF rendition.';

-- Now that ad_document_version exists, wire up ad_document.current_version_id
do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'ad_document_current_version_id_fkey'
    ) then
        alter table public.ad_document
            add constraint ad_document_current_version_id_fkey
            foreign key (current_version_id)
            references public.ad_document_version(id)
            on delete set null;
    end if;
end $$;

-- --------------------------------------------------------------------------
-- ad_audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_audience (
    audience_id      uuid primary key default gen_random_uuid(),
    organisation_id  uuid not null references public.organisations(id) on delete cascade,
    name             varchar not null,
    approval_type_id uuid references public.ad_approval_type(approval_type_id)
);

comment on table public.ad_audience is 'A defined group of users that documents can be assigned to.';

-- --------------------------------------------------------------------------
-- ad_audience_member — join table: users in an audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_audience_member (
    audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
    user_id         uuid not null references public.ad_user(user_id) on delete cascade,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    primary key (audience_id, user_id)
);

comment on table public.ad_audience_member is 'Membership join table between ad_audience and ad_user.';

-- --------------------------------------------------------------------------
-- ad_audience_document — join table: documents assigned to an audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_audience_document (
    audience_id     uuid not null references public.ad_audience(audience_id) on delete cascade,
    doc_id          uuid not null references public.ad_document(doc_id) on delete cascade,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    primary key (audience_id, doc_id)
);

comment on table public.ad_audience_document is 'Join table linking documents to the audiences they are published to.';

-- --------------------------------------------------------------------------
-- ad_related_document — document-to-document "see also" link
-- CSV had doc_id -> ad_audience; corrected to ad_document <-> ad_document.
-- --------------------------------------------------------------------------
create table if not exists public.ad_related_document (
    doc_id          uuid not null references public.ad_document(doc_id) on delete cascade,
    related_doc_id  uuid not null references public.ad_document(doc_id) on delete cascade,
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    primary key (doc_id, related_doc_id),
    constraint ad_related_document_no_self_link check (doc_id <> related_doc_id)
);

comment on table public.ad_related_document is 'Self-referencing link between related documents (e.g. "see also").';

-- --------------------------------------------------------------------------
-- ad_assignment — compliance assignment of a document to a user/audience
-- --------------------------------------------------------------------------
create table if not exists public.ad_assignment (
    id                          uuid primary key default gen_random_uuid(),
    organisation_id             uuid not null references public.organisations(id) on delete cascade,
    document_id                 uuid not null references public.ad_document(doc_id) on delete cascade,
    audience_id                 uuid references public.ad_audience(audience_id) on delete set null,
    user_id                     uuid references public.ad_user(user_id) on delete cascade,
    due_at                      timestamptz,
    mandatory                   boolean not null default true,
    require_reack_on_update     boolean not null default false,
    created_at                  timestamptz not null default now()
);

comment on table public.ad_assignment is 'A compliance requirement: a document due for a user, optionally arising from an audience.';

-- --------------------------------------------------------------------------
-- ad_user_document_state — per-user, per-document current compliance state
-- --------------------------------------------------------------------------
create table if not exists public.ad_user_document_state (
    id                              uuid primary key default gen_random_uuid(),
    user_id                         uuid not null references public.ad_user(user_id) on delete cascade,
    document_id                     uuid not null references public.ad_document(doc_id) on delete cascade,
    last_acknowledged_version_id    uuid references public.ad_document_version(id) on delete set null,
    is_compliant                    boolean not null default false,
    is_overdue                      boolean not null default false,
    last_viewed_at                  timestamptz,
    acknowledged_at                 timestamptz,
    updated_at                      timestamptz not null default now(),
    unique (user_id, document_id)
);

comment on table public.ad_user_document_state is 'Rolled-up current compliance state per user per document (one row per user/document pair).';

-- --------------------------------------------------------------------------
-- ad_notification
-- --------------------------------------------------------------------------
create table if not exists public.ad_notification (
    id              uuid primary key default gen_random_uuid(),
    organisation_id uuid not null references public.organisations(id) on delete cascade,
    user_id         uuid not null references public.ad_user(user_id) on delete cascade,
    type            varchar not null, -- e.g. reminder, overdue, assignment
    payload         jsonb,
    sent_at         timestamptz,
    read_at         timestamptz
);

comment on table public.ad_notification is 'Notifications sent to users (reminders, overdue alerts, new assignments, etc).';

-- --------------------------------------------------------------------------
-- audit_log
-- --------------------------------------------------------------------------
create table if not exists public.audit_log (
    id              uuid primary key default gen_random_uuid(),
    organisation_id uuid references public.organisations(id) on delete cascade,
    user_id         uuid references public.ad_user(user_id) on delete set null,
    action          varchar not null,
    entity_type     varchar not null,
    entity_id       uuid,
    metadata        jsonb,
    created_at      timestamptz not null default now()
);

comment on table public.audit_log is 'Generic audit trail across all approveDoc entities.';


-- ============================================================================
-- SECTION 4 — Indexes (FKs are not auto-indexed in Postgres)
-- ============================================================================

create index if not exists idx_ad_user_organisation_id            on public.ad_user(organisation_id);
create index if not exists idx_ad_user_manager_id                 on public.ad_user(manager_id);
create index if not exists idx_ad_user_senior_manager_id          on public.ad_user(senior_manager_id);
create index if not exists idx_ad_user_department_id              on public.ad_user(department_id);
create index if not exists idx_ad_user_location_id                on public.ad_user(location_id);

create index if not exists idx_ad_department_organisation_id      on public.ad_department(organisation_id);
create index if not exists idx_ad_location_organisation_id        on public.ad_location(organisation_id);
create index if not exists idx_ad_country_organisation_id         on public.ad_country(organisation_id);
create index if not exists idx_ad_category_organisation_id        on public.ad_category(organisation_id);
create index if not exists idx_ad_approval_type_organisation_id   on public.ad_approval_type(organisation_id);

create index if not exists idx_ad_document_organisation_id        on public.ad_document(organisation_id);
create index if not exists idx_ad_document_category_id            on public.ad_document(category_id);
create index if not exists idx_ad_document_current_version_id     on public.ad_document(current_version_id);

create index if not exists idx_ad_document_version_document_id    on public.ad_document_version(document_id);

create index if not exists idx_ad_audience_organisation_id        on public.ad_audience(organisation_id);
create index if not exists idx_ad_audience_approval_type_id       on public.ad_audience(approval_type_id);

create index if not exists idx_ad_audience_member_user_id         on public.ad_audience_member(user_id);
create index if not exists idx_ad_audience_member_organisation_id on public.ad_audience_member(organisation_id);

create index if not exists idx_ad_audience_document_doc_id        on public.ad_audience_document(doc_id);
create index if not exists idx_ad_audience_document_organisation_id on public.ad_audience_document(organisation_id);

create index if not exists idx_ad_related_document_related_doc_id on public.ad_related_document(related_doc_id);
create index if not exists idx_ad_related_document_organisation_id on public.ad_related_document(organisation_id);

create index if not exists idx_ad_assignment_organisation_id      on public.ad_assignment(organisation_id);
create index if not exists idx_ad_assignment_document_id          on public.ad_assignment(document_id);
create index if not exists idx_ad_assignment_audience_id          on public.ad_assignment(audience_id);
create index if not exists idx_ad_assignment_user_id              on public.ad_assignment(user_id);
create index if not exists idx_ad_assignment_due_at               on public.ad_assignment(due_at);

create index if not exists idx_ad_user_doc_state_user_id          on public.ad_user_document_state(user_id);
create index if not exists idx_ad_user_doc_state_document_id      on public.ad_user_document_state(document_id);
create index if not exists idx_ad_user_doc_state_is_overdue       on public.ad_user_document_state(is_overdue);

create index if not exists idx_ad_notification_organisation_id    on public.ad_notification(organisation_id);
create index if not exists idx_ad_notification_user_id            on public.ad_notification(user_id);

create index if not exists idx_audit_log_organisation_id          on public.audit_log(organisation_id);
create index if not exists idx_audit_log_user_id                  on public.audit_log(user_id);
create index if not exists idx_audit_log_entity                   on public.audit_log(entity_type, entity_id);


-- ============================================================================
-- SECTION 5 — Row Level Security (organisation-scoped multi-tenancy)
--
-- Strategy: every table with an organisation_id column is protected by a
-- policy that checks the requesting user's organisation_id (looked up from
-- ad_user via auth.uid()) matches the row's organisation_id.
--
-- A helper function avoids repeating the subquery in every policy and lets
-- Postgres cache execution per statement.
-- ============================================================================

create or replace function public.ad_current_user_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select organisation_id
    from public.ad_user
    where user_id = auth.uid()
$$;

comment on function public.ad_current_user_org_id() is 'Returns the organisation_id of the currently authenticated user, for use in RLS policies.';

-- --------------------------------------------------------------------------
-- Enable RLS on every organisation-scoped table
-- --------------------------------------------------------------------------
alter table public.ad_user                 enable row level security;
alter table public.ad_department           enable row level security;
alter table public.ad_location             enable row level security;
alter table public.ad_country              enable row level security;
alter table public.ad_category             enable row level security;
alter table public.ad_approval_type        enable row level security;
alter table public.ad_document             enable row level security;
alter table public.ad_audience             enable row level security;
alter table public.ad_audience_member      enable row level security;
alter table public.ad_audience_document    enable row level security;
alter table public.ad_related_document     enable row level security;
alter table public.ad_assignment           enable row level security;
alter table public.ad_notification         enable row level security;
alter table public.audit_log               enable row level security;

-- ad_document_version and ad_user_document_state have no organisation_id
-- column directly; scope them via their parent document/user instead.
alter table public.ad_document_version     enable row level security;
alter table public.ad_user_document_state  enable row level security;

-- --------------------------------------------------------------------------
-- Policies — one combined ALL-command policy per table, named consistently.
-- Drop-and-recreate pattern used so the script is safely re-runnable.
-- --------------------------------------------------------------------------

drop policy if exists ad_user_org_isolation on public.ad_user;
create policy ad_user_org_isolation on public.ad_user
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_department_org_isolation on public.ad_department;
create policy ad_department_org_isolation on public.ad_department
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_location_org_isolation on public.ad_location;
create policy ad_location_org_isolation on public.ad_location
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_country_org_isolation on public.ad_country;
create policy ad_country_org_isolation on public.ad_country
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_category_org_isolation on public.ad_category;
create policy ad_category_org_isolation on public.ad_category
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_approval_type_org_isolation on public.ad_approval_type;
create policy ad_approval_type_org_isolation on public.ad_approval_type
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_document_org_isolation on public.ad_document;
create policy ad_document_org_isolation on public.ad_document
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_audience_org_isolation on public.ad_audience;
create policy ad_audience_org_isolation on public.ad_audience
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_audience_member_org_isolation on public.ad_audience_member;
create policy ad_audience_member_org_isolation on public.ad_audience_member
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_audience_document_org_isolation on public.ad_audience_document;
create policy ad_audience_document_org_isolation on public.ad_audience_document
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_related_document_org_isolation on public.ad_related_document;
create policy ad_related_document_org_isolation on public.ad_related_document
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_assignment_org_isolation on public.ad_assignment;
create policy ad_assignment_org_isolation on public.ad_assignment
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists ad_notification_org_isolation on public.ad_notification;
create policy ad_notification_org_isolation on public.ad_notification
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

drop policy if exists audit_log_org_isolation on public.audit_log;
create policy audit_log_org_isolation on public.audit_log
    for all using (organisation_id = public.ad_current_user_org_id())
    with check (organisation_id = public.ad_current_user_org_id());

-- ad_document_version — scoped via parent ad_document's organisation_id
drop policy if exists ad_document_version_org_isolation on public.ad_document_version;
create policy ad_document_version_org_isolation on public.ad_document_version
    for all using (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    )
    with check (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    );

-- ad_user_document_state — scoped via parent ad_document's organisation_id
drop policy if exists ad_user_document_state_org_isolation on public.ad_user_document_state;
create policy ad_user_document_state_org_isolation on public.ad_user_document_state
    for all using (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    )
    with check (
        document_id in (
            select doc_id from public.ad_document
            where organisation_id = public.ad_current_user_org_id()
        )
    );

-- ============================================================================
-- End of script
-- ============================================================================
