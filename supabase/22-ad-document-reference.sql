-- ============================================================================
-- approveDoc -- ad_document_reference
--
-- Stores documents that users have saved to their personal reference library
-- via the "Add to Reference" button on the acknowledge page.
--
-- A user can only reference a given document once (unique constraint).
-- Deleting the user or document cascades the reference row automatically.
-- ============================================================================

create table public.ad_document_reference (
  ad_docref_id    uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  user_id         uuid not null references public.ad_user(user_id) on delete cascade,
  doc_id          uuid not null references public.ad_document(doc_id) on delete cascade,
  date_added      date not null default current_date,

  unique (user_id, doc_id)
);

alter table public.ad_document_reference enable row level security;

create policy "Users: view own references"
  on public.ad_document_reference for select
  using (user_id = auth.uid() or _my_role() in ('admin','super_admin'));

create policy "Users: add own references"
  on public.ad_document_reference for insert
  with check (user_id = auth.uid() and organisation_id = _my_organisation_id());

create policy "Users: remove own references"
  on public.ad_document_reference for delete
  using (user_id = auth.uid() or _my_role() in ('admin','super_admin'));

comment on table public.ad_document_reference is
  'Documents saved to a user''s personal reference library from the acknowledge page.';
