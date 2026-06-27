-- ============================================================
-- {{PROJECT_NAME}} - One-off migration
--
-- Adds download_file_name to document_files. 02-documents.sql has
-- already been updated to create this column on a fresh database -
-- run this once if you ran an earlier version of that script first.
--
-- Safe to re-run - add column if not exists is a no-op if already there.
-- ============================================================

alter table public.document_files add column if not exists download_file_name text;
