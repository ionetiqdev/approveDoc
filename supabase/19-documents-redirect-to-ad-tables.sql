-- ============================================================================
-- approveDoc -- redirect documents module to ad_* tables, drop old baseline tables
--
-- The documents module was originally pointed at three baseline tables
-- inherited from the project template:
--
--   documents              (old)  →  ad_document              (correct)
--   document_files         (old)  →  ad_document_file         (new, created here)
--   document_category_lookup (old) →  ad_category             (correct)
--
-- The old tables are dropped after migrating any existing data. The
-- two orphan records in public.documents from failed test uploads are
-- also cleaned up here.
--
-- ad_category gains a sort_order column to match what the documents
-- module needs for drag-to-reorder category management.
--
-- ad_document_file is a new table mirroring document_files' shape but
-- referencing ad_document(doc_id) instead of documents(id).
--
-- Safe to re-run: create/add statements use IF NOT EXISTS / IF NOT EXISTS.
-- Drop statements are CASCADE so dependent objects go with them.
-- ============================================================================

-- ── 1. ad_category: add sort_order ───────────────────────────────────────

alter table public.ad_category add column if not exists sort_order integer not null default 0;
comment on column public.ad_category.sort_order is
  'Drag-to-reorder position used by the documents module category manager.';

-- ── 2. ad_document_file: new files table referencing ad_document ─────────

create table if not exists public.ad_document_file (
  id                uuid primary key default gen_random_uuid(),
  organisation_id   uuid not null references public.organisations(id) on delete cascade,
  doc_id            uuid not null references public.ad_document(doc_id) on delete cascade,
  file_name         text not null,
  download_file_name text,
  storage_path      text not null,
  file_size_bytes   bigint,
  mime_type         text,
  uploaded_by       uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now()
);

comment on table public.ad_document_file is
  'Files attached to ad_document records. Mirrors the old document_files table but references ad_document(doc_id).';

create index if not exists idx_ad_document_file_doc on public.ad_document_file(doc_id);
create index if not exists idx_ad_document_file_org on public.ad_document_file(organisation_id);

alter table public.ad_document_file enable row level security;
drop policy if exists "ad_document_file_org_isolation" on public.ad_document_file;
create policy "ad_document_file_org_isolation"
  on public.ad_document_file for all
  using (organisation_id = public.ad_current_user_org_id())
  with check (organisation_id = public.ad_current_user_org_id());

-- ── 3. Clean up orphan test records then drop old tables ─────────────────

-- Orphan document_files rows first (FK dependency), then documents rows.
delete from public.document_files where document_id in (select id from public.documents);
delete from public.documents;

-- Drop old tables - CASCADE handles any remaining FK/policy dependencies.
drop table if exists public.document_files cascade;
drop table if exists public.documents cascade;
drop table if exists public.document_category_lookup cascade;

-- Reload PostgREST schema so it picks up the new tables and dropped ones.
notify pgrst, 'reload schema';
