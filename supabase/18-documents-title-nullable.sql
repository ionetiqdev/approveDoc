-- ============================================================================
-- approveDoc -- make documents.title nullable
--
-- The documents module uses the 'description' column as its document
-- name field (see pages/documents/config.js, colDocDesc = 'description').
-- The 'title' column on the public.documents table was inherited from
-- the initial baseline schema but is never populated or read by the
-- module, causing every document upload to fail with a NOT NULL
-- constraint violation.
--
-- Fix: make title nullable. We don't want to silently duplicate the
-- description value into title on every insert; the column exists for
-- potential future use but shouldn't block the module from working.
-- ============================================================================

alter table public.documents alter column title drop not null;
