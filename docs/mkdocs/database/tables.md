# Tables Reference

## ad_distribution_item

Key columns:

| Column | Type | Notes |
|---|---|---|
| `distrib_item_id` | uuid PK | |
| `distribution_id` | uuid FK | → `ad_distribution` |
| `user_id` | uuid FK | → `auth.users` |
| `organisation_id` | uuid FK | → `organisations` |
| `status` | varchar(10) | `PENDING`, `OVERDUE`, `APPROVED`, `REJECTED`, `REFERENCE` |
| `acknowledged` | boolean | |
| `acknowledged_date` | date | |
| `rejected` | boolean | |
| `rejected_reason` | text | |
| `rejected_date` | date | |

## ad_document_file

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `doc_id` | uuid FK | → `ad_document` |
| `organisation_id` | uuid FK | |
| `file_name` | text | Original filename |
| `storage_path` | text | Supabase storage path (or `'external'` placeholder) |
| `download_file_name` | text | Displayed filename |
| `mime_type` | text | |
| `source_type` | text | `SUPABASE`, `URL`, `REST`, `SHAREPOINT`, `ONBASE` |
| `source_id` | uuid FK | → `ad_external_source` (nullable) |
| `external_url` | text | URL or API endpoint for external sources |
| `external_ref` | text | System-specific ID (e.g. OnBase handle) |

## ad_external_source

| Column | Type | Notes |
|---|---|---|
| `source_id` | uuid PK | |
| `organisation_id` | uuid FK | |
| `name` | text | e.g. "SharePoint Production" |
| `source_type` | text | `URL`, `REST`, `SHAREPOINT`, `ONBASE` |
| `base_url` | text | Base URL for the system |
| `auth_type` | text | `NONE`, `BEARER`, `BASIC`, `API_KEY`, `OAUTH2` |
| `auth_secret_id` | uuid | References `vault.secrets.id` — **never raw credentials** |
| `auth_username` | text | For BASIC auth username (not sensitive) |
| `auth_header_name` | text | Default `'Authorization'`; use `'X-API-Key'` for API_KEY type |
| `extra_headers` | jsonb | Additional headers needed |

## ad_user

| Column | Type | Notes |
|---|---|---|
| `user_id` | uuid PK/FK | → `auth.users` |
| `organisation_id` | uuid FK | |
| `first_name` / `last_name` | text | |
| `email` | text | |
| `manager_id` | uuid FK | → `ad_user.user_id` (self-referencing) |
| `is_top_level` | boolean | Intentional root of hierarchy |
| `department_id`, `location_id`, `job_role_id`, `country_id` | uuid FK | Lookup tables |

## ad_document_reference

| Column | Type | Notes |
|---|---|---|
| `ad_docref_id` | uuid PK | |
| `organisation_id` | uuid FK | |
| `user_id` | uuid FK | |
| `doc_id` | uuid FK | |
| `date_added` | date | Defaults to today |

Unique constraint on `(user_id, doc_id)` — a user can only reference a document once.
