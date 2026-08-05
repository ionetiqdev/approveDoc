-- ============================================================================
-- approveDoc -- External document sources
-- Migration: 23-external-document-sources.sql
-- ============================================================================

-- 1. Secrets vault — stores credentials for external systems
create table public.ad_external_source (
  source_id        uuid primary key default gen_random_uuid(),
  organisation_id  uuid not null references public.organisations(id) on delete cascade,
  name             text not null,
  source_type      text not null,          -- SUPABASE | URL | REST | SHAREPOINT | ONBASE
  base_url         text,
  auth_type        text not null default 'NONE',  -- NONE | BEARER | BASIC | API_KEY | OAUTH2
  auth_secret_id   uuid,                   -- vault.secrets.id — never store raw credentials
  auth_username    text,                   -- BASIC auth username (not sensitive)
  auth_header_name text default 'Authorization',
  extra_headers    jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (organisation_id, name)
);

alter table public.ad_external_source enable row level security;
create policy "Admins: manage external sources"
  on public.ad_external_source for all
  using (_my_role() in ('admin', 'super_admin'));

comment on table  public.ad_external_source is 'External document repository connections (SharePoint, OnBase, REST APIs, etc.)';
comment on column public.ad_external_source.auth_secret_id is 'References vault.secrets.id — credential never stored in plain text';

-- 2. Extend ad_document_file
alter table public.ad_document_file
  add column if not exists source_type   text not null default 'SUPABASE',
  add column if not exists source_id     uuid references public.ad_external_source(source_id) on delete set null,
  add column if not exists external_url  text,
  add column if not exists external_ref  text;

alter table public.ad_document_file
  add constraint chk_file_source check (
    (source_type = 'SUPABASE' and storage_path is not null) or
    (source_type != 'SUPABASE' and (external_url is not null or external_ref is not null))
  );

comment on column public.ad_document_file.source_type  is 'SUPABASE | URL | REST | SHAREPOINT | ONBASE';
comment on column public.ad_document_file.external_url is 'Full URL (URL type) or API path (REST/SHAREPOINT/ONBASE)';
comment on column public.ad_document_file.external_ref is 'System-specific ID: OnBase doc handle, SharePoint item ID, etc.';
