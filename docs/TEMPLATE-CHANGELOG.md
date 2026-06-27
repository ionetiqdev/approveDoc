# Template changelog

Every entry here corresponds to a `TEMPLATE-VERSION.txt` bump. This is
the durable record of what changed in the template itself and why -
not a build-by-build log (that's what each zip's own `CHANGES.txt` is
for), but a versioned summary of meaningful changes, kept so that:

- a project's `project.conf` can record which version it was built
  from (`TEMPLATE_VERSION_AT_CREATION`), and
- anyone (you, a future ionetiq team member, or Claude in a future
  session with no memory of today) can look at a project's recorded
  version, read everything below it, and know exactly what's
  available to consider pulling into that project - without having to
  remember or reconstruct the history themselves.

Applying a change to an existing, already-customised project is still
a judgement call, not a mechanical merge - this changelog tells you
**what's available and why**, not how to merge it into your specific
project's divergence from the template. See `docs/UPDATING-PROJECTS.md`
for how that actually works in practice.

**Security-relevant entries** (an RLS gap, a privilege-escalation
hole, anything in that category) are marked with **🔒 SECURITY** at
the start of their bullet point - per `docs/UPDATING-PROJECTS.md`,
these are the one category worth pulling into every live project
regardless of how unrelated the rest of that version is.

## 1.1.1 - 27 June 2026

- 🔒 SECURITY: `supabase/03-issues.sql`'s two trigger functions
  (`issues_set_ref`, `issues_set_updated_at`) were missing
  `set search_path = public`, unlike every other function in the
  core schema. Low real-world exploitability (no untrusted input
  reaches either function), but inconsistent with the hardening
  already applied everywhere else - found via Supabase's security
  advisor (`function_search_path_mutable`) while setting up a new
  project. Both functions now match the existing pattern.

## 1.1.0 - 27 June 2026

Introduced the versioning/changelog system itself (this file,
`TEMPLATE-VERSION.txt`, `project.conf`'s `TEMPLATE_VERSION_AT_CREATION`
field), plus:

- `supabase/07-lookup-data.sql` - a manual, edit-before-running script
  giving an ionetiq team member a single place to fill in real
  starting values for `issues_project`, `issues_area`, `issues_user`,
  and `document_category_lookup` (all empty by default), with the
  option to override `issues_status`/`issues_priority`/`issues_type`'s
  existing schema-level defaults too.
- `docs/NEW-PROJECT.md` rewritten as a genuinely ordered, numbered,
  checkable step-by-step process (previously organised by topic, not
  by the actual order someone would do the steps in).
- `docs/UPDATING-PROJECTS.md` - new. Explains how to decide what to
  pull into an already-built project from a newer template version,
  given there's no mechanical merge tool.
- `docs/SUBSYSTEMS.md` - new. Was referenced by name in code comments
  since the very first day of this project but never actually
  written. Documents the real pattern established by Documents and
  Issues, for adding a third sub-system later.

## 1.0.0 - 27 June 2026 (baseline)

First version where the template was treated as a working, reviewed
baseline rather than a work in progress. Established in one extended
session, covering:

- Core schema: `organisations`, `profiles`, 4-role model
  (super_admin/admin/user/view), `_my_role()`/`_my_organisation_id()`
  SECURITY DEFINER helpers, hardened RLS including the
  privilege-escalation guard preventing an org admin from ever
  granting super_admin or moving a user to a different organisation.
- Documents sub-system: org-scoped documents/categories, private
  storage bucket with signed URLs, real PDF.js inline viewer
  (bundled in `assets/pdfjs`), per-user viewer preferences, category
  drag-and-drop reordering.
- Issues sub-system: deliberately global/non-multi-tenant,
  super_admin-only, full tabbed edit modal (Reported/Assignment/
  Resolution/Documentation tabs) with auto-incrementing reference
  numbers and a related-issue text-lookup field.
  `template_customer` sample-data table and seed/cleanup scripts.
- Full admin: Organisations (super_admin-only) and Users (admin can
  manage users within their own organisation, never grant
  super_admin) with avatar upload, password reset, and the
  `manage-user` Edge Function for privileged auth operations.
- Real Tabler UI throughout: proper `card`/`card-header-tabs`
  structure (not bare `nav-tabs`), `table-vcenter card-table` row
  styling with status dots instead of decorative badges, consistent
  `btn-icon-lg` action icons, working pagination, coloured modal
  headers with a matching close button and a thin border around
  every modal.
- Full deploy pipeline: `deploy.bat` (zip discovery, branch
  auto-creation, cache-busting, published-version reporting) and
  GitHub Actions (Supabase credential injection at deploy time,
  FTP publish, Slack notification) - proven working end-to-end
  against a real Supabase project and a real FTP host.
- Sidebar/header: Admin → Lookups → Lookup 1/2/3 nesting, Preferences
  as both a sidebar link and header icon (no avatar dropdown - tried,
  did not work reliably, reverted), sidebar footer user info row
  (avatar/name/role/logout) matching ionetiq Risk's actual layout.

No earlier version exists - this is the starting point.
