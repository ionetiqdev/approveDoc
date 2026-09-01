# Migration History

Migrations are numbered sequentially and applied in order. Run in the Supabase SQL Editor.

| Migration | Description |
|---|---|
| `01-core-schema.sql` | `organisations`, `profiles`, storage buckets, helper functions (`_my_role`, `_my_organisation_id`), RLS patterns |
| `02-documents.sql` | `ad_document`, `ad_document_file`, `documents` storage bucket |
| `03-issues.sql` | Issues tracking tables |
| `04-sample-data.sql` | Sample organisations and users (dev only) |
| `05-drop-fixed-release.sql` | Cleanup |
| `06-add-download-filename.sql` | `download_file_name` column on `ad_document_file` |
| `07-lookup-data.sql` | Approval types, categories seed data |
| `08-approvedoc-schema.sql` | Core compliance tables: `ad_user`, `ad_audience`, `ad_distribution`, `ad_distribution_item` |
| `09-language-lookup-data.sql` | ISO language seed data |
| `10-country-lookup-data.sql` | ISO country seed data |
| `11-country-remove-org-scope-add-alpha2.sql` | Countries are global reference data (no org scope); add `alpha2` |
| `12-country-alpha2-backfill.sql` | Backfill `alpha2` codes |
| `13-audience-description-user-country.sql` | Audience description field; `ad_user` country link |
| `14-audience-criteria.sql` | `ad_audience_criteria` table for criteria-based audiences |
| `15-cleanup-audience-test-data.sql` | Remove test data |
| `16-job-role.sql` | `ad_job_role` lookup table |
| `17-distribution.sql` | `ad_distribution`, `ad_distribution_audience`, `ad_distribution_item`; `build_distribution_items` function |
| `18-documents-title-nullable.sql` | Make document title nullable |
| `19-documents-redirect-to-ad-tables.sql` | Redirect documents to `ad_*` tables |
| `20-distribution-item-rejected-reason.sql` | `rejected_reason`, `rejected_date`, `rejected` columns on `ad_distribution_item` |
| `21-ad-user-manager-id.sql` | `manager_id` self-referencing FK on `ad_user` (ON DELETE SET NULL) |
| `22-ad-document-reference.sql` | `ad_document_reference` table with RLS; unique on `(user_id, doc_id)` |
| `23-external-document-sources.sql` | `ad_external_source` table; `source_type`, `source_id`, `external_url`, `external_ref` on `ad_document_file` |
| `24-rls-country-language.sql` | Enable RLS on `ad_country` and `ad_language` |
