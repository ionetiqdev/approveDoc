# approveDoc — Schema (08-approvedoc-schema.sql)

This document explains the `ad_*` table schema added by
`08-approvedoc-schema.sql`, why certain decisions were made, and what a
future Claude instance (or Mike) needs to know before extending it.

## Context

This migration follows `01-core-schema.sql`, `02-documents.sql`, and
`03-issues.sql`, already applied to the **approveDoc v1.0** Supabase project
(`nkwpqboslnbeifyaegos`, repo `github.com/ionetiqdev/approveDoc.git`).

It adds the layer responsible for:
- Organisational structure (departments, locations, categories)
- Users that extend `auth.users` with approveDoc-specific fields
- Audiences (groups of users) and the documents assigned to them
- Document versioning (major/minor)
- Per-user compliance state tracking (acknowledged, overdue, compliant)
- Notifications and a generic audit log

## Source of truth

This schema was generated from `approvedoc-schema.csv` (a hand-written
table/column/relationship list). Several issues in that CSV were corrected
during generation — listed below so nobody "fixes" them back to the
original CSV by mistake.

## Decisions made (confirmed with Mike)

| # | Issue in source CSV | Resolution |
|---|---|---|
| 1 | `ad_department` was listed twice, second instance missing `organisation_id` | Used the fuller definition (`department_id` PK, `organisation_id` FK, `name`) |
| 2 | `ad_audience.audience_id` had no PK marked | Confirmed as PK of `ad_audience` |
| 3 | `ad_audience.approval_type_id` had no target table | Created new table `ad_approval_type` (`approval_type_id` PK, `organisation_id` FK, `name`, `sort_order`) |
| 4 | `ad_related_document.doc_id` listed `Related To: ad_audience` | Corrected — this is a document-to-document "related document" link; both `doc_id` and `related_doc_id` reference `ad_document` |
| 5 | `ad_user.avatar` had no data type and no clear ownership | **Dropped from `ad_user` entirely.** `profiles` (from `01-core-schema.sql`) already extends `auth.users` and owns the avatar/storage-bucket link. `ad_user` and `profiles` are siblings — both extend the same `auth.users` row for different concerns. Avatar should be read via `profiles.avatar`, not duplicated here. |
| 6 | No `organisations` table in the CSV | Assumed to already exist (created in `01-core-schema.sql`). This migration only adds FK references to `public.organisations(id)` — it does not create it. If this assumption is wrong, every FK in this file will fail on first run. |
| 7 | `ad_user.user_id` listed as FK to "Supabase Users" | Wired to `auth.users(id) on delete cascade`, the standard Supabase pattern |
| 8 | CSV used `datetime` / `json` | Mapped to Postgres best practice: `timestamptz` / `jsonb` |

## ⚠️ Known risk: possible overlap with 02-documents.sql

This migration was generated without sight of `02-documents.sql`'s actual
contents. Table names like `ad_document` and `ad_category` are plausible
candidates for things `02-documents.sql` might already have created.

**Every `create table` in this migration uses `IF NOT EXISTS`**, which means:
- If a table already exists with a *different* column set, this migration
  will silently do nothing for that table — no error, no new columns.
- This can mask a mismatch rather than surface it.

**Before running this on a fresh environment**, diff the table names in this
file against `02-documents.sql`. If there's overlap, decide whether to:
- Rename the new table, or
- Drop this migration's version and instead `ALTER` the existing table, or
- Confirm they're meant to be the same and the existing one already has the
  required columns.

(Mike ran this migration once already, with no errors. That doesn't fully
rule out the silent-skip scenario above — it just means nothing *broke*.
Worth a manual `\d ad_document` etc. check in the SQL editor to confirm the
columns present match this file.)

## Multi-tenancy / RLS approach

Every table carrying `organisation_id` has RLS enabled, gated through a
single helper function:

```sql
public.ad_current_user_org_id()
```

This resolves `auth.uid()` → `ad_user.organisation_id` and is used in a
`USING` + `WITH CHECK` policy on every org-scoped table, so a row is only
visible/writable if it belongs to the caller's own organisation.

Two tables — `ad_document_version` and `ad_user_document_state` — don't
carry `organisation_id` directly. They're scoped indirectly, through a
subquery against their parent `ad_document.organisation_id`.

This is **not** the "open RLS for anon/authenticated" pattern used in the
document viewer module (`test_document` / `test_docfiles`). That pattern was
fine for a single-tenant viewer prototype; this schema is explicitly
multi-tenant (every table has `organisation_id`), so proper isolation was
applied instead. If anon/public access is ever needed against any of these
tables, it will need its own explicit policy — the current setup requires
an authenticated `ad_user` row to read or write anything.

## Indexes

Postgres does not auto-index foreign key columns. Every FK column in this
migration has a matching `create index if not exists`, since these tables
will be joined heavily for compliance dashboards and reporting (e.g.
"all overdue assignments for department X").

## What's NOT in this migration

- `organisations` table itself (assumed from `01-core-schema.sql`)
- `profiles` table itself, or its `avatar` column (assumed from
  `01-core-schema.sql`)
- Any storage buckets — none of these tables store files directly;
  `ad_document_version.source_file_url` / `pdf_file_url` are just `text`
  columns pointing at wherever the document module's storage lives
  (see `02-documents.sql` / the document viewer module's bucket setup)
- Triggers to auto-update `ad_user_document_state` when a new
  `ad_document_version` is published — that logic is application-level for
  now and not yet built

## Suggested next steps for whoever picks this up

1. Confirm `organisations` and `profiles` column names match what this
   migration assumes (`organisations.id`, `profiles.avatar`)
2. Diff against `02-documents.sql` for table name collisions (see risk note
   above)
3. Decide whether `ad_user_document_state` should be maintained via a
   database trigger (on new `ad_document_version` insert, or on
   `ad_assignment` changes) rather than purely application-side recalculation
4. Build the reporting queries / views compliance dashboards will actually
   run against (e.g. "overdue by department", "compliance % by audience")
