-- ============================================================
-- {{PROJECT_NAME}} - Documents sub-system
--
-- Run AFTER 01-core-schema.sql. Self-contained: every table, index,
-- and policy this sub-system needs lives in this one file, so it
-- can be skipped entirely for a project that doesn't want Documents,
-- or added later to a project that didn't run it at creation time
-- (see docs/SUBSYSTEMS.md).
--
-- Safe to re-run: every statement is idempotent.
-- ============================================================


-- ── 1. document_category_lookup ──────────────────────────────────
-- Categories are per-organisation (not a global shared lookup) -
-- each org manages its own category list, e.g. "Policy", "Contract",
-- "Certificate". A brand new organisation starts with none; an
-- admin adds their own via the Documents page.

create table if not exists public.document_category_lookup (
  id                       uuid primary key default gen_random_uuid(),
  organisation_id          uuid not null references public.organisations(id) on delete cascade,
  name                     text not null,
  document_category_order  integer not null default 0,
  created_at               timestamptz not null default now(),

  constraint document_category_lookup_org_name_key unique (organisation_id, name)
);

create index if not exists idx_document_category_lookup_org
  on public.document_category_lookup(organisation_id);


-- ── 2. documents ───────────────────────────────────────────────────
-- One row per document record. The actual file content lives in
-- document_files (a document can have more than one file attached -
-- e.g. versions, or a cover page plus an appendix).

create table if not exists public.documents (
  id                   uuid primary key default gen_random_uuid(),
  organisation_id      uuid not null references public.organisations(id) on delete cascade,
  document_category_id uuid references public.document_category_lookup(id) on delete set null,
  title                text not null,
  description          text,
  created_by           uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists idx_documents_org on public.documents(organisation_id);
create index if not exists idx_documents_category on public.documents(document_category_id);


-- ── 3. document_files ────────────────────────────────────────────
-- File metadata; the actual bytes live in Supabase Storage under
-- the 'documents' bucket (created below), one storage object per row
-- here. organisation_id is intentionally duplicated onto this table
-- rather than scoped purely via a join back to documents - unlike a
-- pure junction table, document_files is itself the target of direct
-- Storage RLS checks (see bucket policies below), which need a fast,
-- direct column to check without an extra join into documents.

create table if not exists public.document_files (
  id                  uuid primary key default gen_random_uuid(),
  organisation_id     uuid not null references public.organisations(id) on delete cascade,
  document_id         uuid not null references public.documents(id) on delete cascade,
  file_name           text not null,
  download_file_name  text,
  storage_path        text not null,
  file_size_bytes      bigint,
  mime_type            text,
  uploaded_by          uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now()
);

create index if not exists idx_document_files_org on public.document_files(organisation_id);
create index if not exists idx_document_files_document on public.document_files(document_id);


-- ── 4. RLS ─────────────────────────────────────────────────────────
-- Same shape as organisations/profiles: super_admin gets full access
-- across every organisation, everyone else is scoped to their own
-- organisation via the _my_organisation_id() helper from
-- 01-core-schema.sql. view-role users get read-only (no with check,
-- so they have no write policy at all and INSERT/UPDATE/DELETE stay
-- blocked for them by the default-deny behaviour of RLS).

-- document_category_lookup
alter table public.document_category_lookup enable row level security;

drop policy if exists "Super admins: full access to document categories" on public.document_category_lookup;
create policy "Super admins: full access to document categories"
  on public.document_category_lookup for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view document categories in own organisation" on public.document_category_lookup;
create policy "Users: view document categories in own organisation"
  on public.document_category_lookup for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage document categories in own organisation" on public.document_category_lookup;
create policy "Editors: manage document categories in own organisation"
  on public.document_category_lookup for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );

-- documents
alter table public.documents enable row level security;

drop policy if exists "Super admins: full access to documents" on public.documents;
create policy "Super admins: full access to documents"
  on public.documents for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view documents in own organisation" on public.documents;
create policy "Users: view documents in own organisation"
  on public.documents for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage documents in own organisation" on public.documents;
create policy "Editors: manage documents in own organisation"
  on public.documents for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );

-- document_files
alter table public.document_files enable row level security;

drop policy if exists "Super admins: full access to document files" on public.document_files;
create policy "Super admins: full access to document files"
  on public.document_files for all
  using (public._my_role() = 'super_admin')
  with check (public._my_role() = 'super_admin');

drop policy if exists "Users: view document files in own organisation" on public.document_files;
create policy "Users: view document files in own organisation"
  on public.document_files for select
  using (organisation_id = public._my_organisation_id());

drop policy if exists "Editors: manage document files in own organisation" on public.document_files;
create policy "Editors: manage document files in own organisation"
  on public.document_files for all
  using (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  )
  with check (
    public._my_role() in ('admin', 'user')
    and organisation_id = public._my_organisation_id()
  );


-- ── 5. Storage: documents bucket ──────────────────────────────────
-- PRIVATE bucket (unlike avatars) - document content is genuinely
-- sensitive business data, not something to expose by guessable URL.
-- Access goes through signed URLs generated at request time, gated
-- by the same organisation/role check as the documents table itself.
-- Path convention: {organisation_id}/{document_id}/{file_name}.

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

drop policy if exists "Users: read documents in own organisation" on storage.objects;
create policy "Users: read documents in own organisation"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and (
      (storage.foldername(name))[1] = public._my_organisation_id()::text
      or public._my_role() = 'super_admin'
    )
  );

drop policy if exists "Editors: upload documents in own organisation" on storage.objects;
create policy "Editors: upload documents in own organisation"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (
      (
        public._my_role() in ('admin', 'user')
        and (storage.foldername(name))[1] = public._my_organisation_id()::text
      )
      or public._my_role() = 'super_admin'
    )
  );

drop policy if exists "Editors: delete documents in own organisation" on storage.objects;
create policy "Editors: delete documents in own organisation"
  on storage.objects for delete
  using (
    bucket_id = 'documents'
    and (
      (
        public._my_role() in ('admin', 'user')
        and (storage.foldername(name))[1] = public._my_organisation_id()::text
      )
      or public._my_role() = 'super_admin'
    )
  );
