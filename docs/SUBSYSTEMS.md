# Adding a new sub-system to the template

A "sub-system" is an optional, self-contained module - Documents and
Issues are the two that exist today. This document is the pattern to
follow when adding a third (or a fourth, etc.), to both the template
itself and to a specific project.

## What makes something a sub-system vs. just a feature

A sub-system has its own SQL file, its own page(s), its own nav
entry, and can be meaningfully left out of a project that doesn't
need it without breaking anything else. If a new feature is tightly
coupled to the core schema (something every project needs regardless,
like `organisations`/`profiles`), it isn't a sub-system - it belongs
in `01-core-schema.sql` instead.

## The pattern, step by step

### 1. SQL file: `supabase/0N-{name}.sql`

Self-contained - every table, index, trigger, and RLS policy the
sub-system needs lives in this one file. Depends on
`01-core-schema.sql` having already run (for `_my_role()`/
`_my_organisation_id()` and the `organisations`/`profiles` tables),
but should not depend on any *other* sub-system's tables unless
that's a genuine, deliberate requirement.

Decide explicitly, the same way Documents (multi-tenant) and Issues
(deliberately global) differ: does this sub-system's data belong to
one organisation, or is it shared across all of them? Write the RLS
policies to match - see `01-core-schema.sql`'s comments on the
`_my_role()`/`_my_organisation_id()` pattern, and `03-issues.sql`'s
header comment for how a deliberately-global sub-system's RLS differs
from an org-scoped one.

If the sub-system needs Storage (a bucket), decide public vs. private
the same deliberate way `02-documents.sql` did - default to private
with signed URLs unless there's a specific reason the content is safe
to expose by guessable URL.

### 2. Page(s): `pages/{name}/`

Use the existing page boilerplate pattern (see any current page's
`<head>` pre-paint script, the standard script-tag load order, the
`Auth.requireAuth()` → `SidebarHtml.inject()` → `Sidebar.init()` →
`Auth.refreshUI()` sequence) rather than write it from scratch. Match
the established Tabler conventions: `card`/`card-header`/`card-body`
structure for any tabbed content, `table-vcenter card-table
text-nowrap` for any data table, status dots (not decorative badges)
for genuine status fields, `btn-icon-lg` for row action icons,
`pagination`/Show-entries toolbar for any list of records, the global
modal-header/border styling (already applies automatically via
`theme.css` - no per-page CSS needed for that part).

### 3. Sidebar nav entry: `assets/js/sidebar-html.js`

Add the nav `<li>` inside clearly delimited
`<!-- SUBSYSTEM:{name}:start -->` / `<!-- SUBSYSTEM:{name}:end -->`
comment markers, exactly like the existing Documents and Issues
entries - this is what makes "remove this sub-system from a project"
a clean deletion later, rather than a hunt through unmarked markup.

Decide the role gate deliberately: does every role see this nav
item, or is it restricted (like Issues, `super_admin`-only)? Use
`data-require-role="..."` with the `role-hidden` class, matching the
existing pattern - and remember that the nav link visibility is a UX
convenience, never the actual security boundary; RLS in the SQL file
is what really enforces access.

### 4. Decide: bundled by default, or opt-in?

Per the original handoff doc's open question (never fully resolved
until this was written): for now, a new sub-system should be treated
the same way Documents/Issues currently are - present in the SQL/
pages/nav by default, with removal being "delete the marked block and
don't run that SQL file" rather than a real interview-driven toggle.
A genuine per-project on/off interview question is a future
improvement, not yet built - don't assume it exists.

### 5. Update the changelog

Add an entry to `docs/TEMPLATE-CHANGELOG.md`, bump
`TEMPLATE-VERSION.txt`, and update `NEW-PROJECT.md`'s sub-system list
in step 1's interview-questions section if the new sub-system should
be offered to every new project going forward.

## Removing a sub-system from a specific project

Delete the marked `<!-- SUBSYSTEM:{name}:start/end -->` block from
that project's own copy of `sidebar-html.js`, delete the `pages/{name}/`
folder, and simply never run that sub-system's SQL file (or, if it's
already run, drop its tables manually - there's no automated
uninstall script for this yet).

## Adding a sub-system to a project that didn't start with it

This is exactly the scenario the original handoff doc called out as a
requirement ("I don't want Issue tracking to start but realise during
the project that I do") - and it's why each sub-system's SQL file is
self-contained and safe to run on its own, against an already-live
database, at any point after `01-core-schema.sql`. Run the sub-
system's SQL file, copy its `pages/{name}/` folder in, and add its
marked nav block to that project's `sidebar-html.js` - the same three
artifacts described above, just applied to an existing project
instead of a brand new one.
