# approveDoc — Codebase Documentation

> **Version:** v1.0 (build `11/08/2026`)  
> **Stack:** Tabler UI + Bootstrap 5.3 · Vanilla JS · Supabase (PostgreSQL + Auth + Storage + Edge Functions) · IIS (Windows)  
> **Repo:** `github.com/ionetiqdev/approveDoc.git`  

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Directory Structure](#2-directory-structure)
3. [Deployment](#3-deployment)
4. [Shared JavaScript Modules](#4-shared-javascript-modules)
   - [supabase-client.js](#41-supabase-clientjs)
   - [auth.js](#42-authjs)
   - [app.js](#43-appjs)
   - [sidebar-html.js](#44-sidebar-htmljs)
   - [sidebar.js](#45-sidebarjs)
   - [theme.js](#46-themejs)
   - [status-widget.js](#47-status-widgetjs)
   - [profile-modal.js](#48-profile-modaljs)
5. [Page Conventions](#5-page-conventions)
   - [HTML Head Template](#51-html-head-template)
   - [Script Load Order](#52-script-load-order)
   - [Role-Gated Elements](#53-role-gated-elements)
6. [Feature Modules](#6-feature-modules)
   - [Documents](#61-documents)
   - [Audiences](#62-audiences)
   - [Distribution](#63-distribution)
   - [Users (Admin)](#64-users-admin)
   - [User View (Testing)](#65-user-view-testing)
   - [Acknowledge](#66-acknowledge)
   - [Org Chart (Testing)](#67-org-chart-testing)
7. [Database Schema](#7-database-schema)
   - [Core Tables](#71-core-tables)
   - [approveDoc Tables](#72-approvedoc-tables)
   - [RLS Policy Pattern](#73-rls-policy-pattern)
   - [Migration History](#74-migration-history)
8. [Supabase Edge Functions](#8-supabase-edge-functions)
   - [manage-user](#81-manage-user)
   - [fetch-document](#82-fetch-document)
9. [Authentication & Sessions](#9-authentication--sessions)
10. [Cross-Domain Compatibility](#10-cross-domain-compatibility)
11. [localStorage Isolation](#11-localstorage-isolation)
12. [PDF Viewer](#12-pdf-viewer)
13. [External Document Sources](#13-external-document-sources)
14. [Known Patterns & Conventions](#14-known-patterns--conventions)

---

## 1. Project Overview

approveDoc is a cloud-native document acknowledgement and compliance platform. It enables organisations to:

- Distribute required-reading documents (policies, procedures, compliance materials) to their workforce
- Track acknowledgement, rejections, and reference saves per user
- Enforce deadlines and generate compliance visibility
- Support external document repositories (Google Drive, REST APIs, etc.)

The core workflow:
1. **Admins** create a **Distribution** — linking a document to one or more **Audiences**, with a start date, due date, and optional warnings
2. The system generates **Distribution Items** — one per user per distribution, with status tracking
3. **Recipients** review the document and respond: **Acknowledge**, **Reject** (with mandatory reason), or **Save to Reference**
4. **Admins** monitor compliance status in real time

---

## 2. Directory Structure

```
approveDoc/
├── index.html                    # Dashboard (root page)
├── deploy.bat                    # Deployment script (see §3)
├── BUILD_TIMESTAMP.txt           # Set by deploy.bat
├── CHANGES.txt                   # Commit message for deploy.bat
├── project.conf.example          # Template for project.conf (gitignored)
│
├── assets/
│   ├── css/
│   │   └── theme.css             # Custom CSS overrides on top of Tabler
│   ├── js/
│   │   ├── supabase-client.js    # Supabase client + AppSession (§4.1)
│   │   ├── auth.js               # Authentication, roles, UI (§4.2)
│   │   ├── app.js                # Shared utilities: toast, confirm, guard (§4.3)
│   │   ├── sidebar-html.js       # Sidebar HTML injection + Preferences modal (§4.4)
│   │   ├── sidebar.js            # Sidebar toggle / collapse behaviour (§4.5)
│   │   ├── theme.js              # Dark mode + accent colour toggle (§4.6)
│   │   ├── status-widget.js      # Header compliance status counter (§4.7)
│   │   ├── profile-modal.js      # Avatar upload helper (§4.8)
│   │   ├── app-root.js           # (legacy) App root URL helper
│   │   └── version.js            # Auto-generated; sets APP_PUBLISHED
│   └── pdfjs/                    # Self-hosted pdf.js (excluded from zips)
│
├── pages/
│   ├── auth/
│   │   ├── login.html
│   │   ├── reset-password.html
│   │   └── set-password.html
│   ├── admin/
│   │   ├── organisations.html
│   │   └── users.html
│   ├── audiences_combined/
│   │   └── index.html            # Audience management (combined list + editor)
│   ├── distribution/
│   │   └── index.html            # Distribution management
│   ├── documents/
│   │   ├── index.html            # Document viewer + upload
│   │   ├── documents.js          # All document logic
│   │   └── config.js             # Table/column/bucket name mappings
│   ├── lookups/                  # Admin lookup table editors
│   ├── reports/                  # Report placeholders
│   ├── testing/
│   │   ├── user-view.html        # User's document list (grouped by status)
│   │   ├── acknowledge.html      # Document viewer + Acknowledge/Reject/Reference
│   │   └── org-chart.html        # Org hierarchy (drag-and-drop)
│   └── ...
│
├── supabase/
│   ├── 01- to 24-*.sql          # Sequential DB migrations (§7.4)
│   └── functions/
│       ├── manage-user/          # Edge function: create/update/delete users
│       └── fetch-document/       # Edge function: proxy external documents
│
└── docs/
    ├── CODEBASE.md               # This file
    ├── APPROVEDOC_SCHEMA.md      # DB schema reference
    ├── GOOGLE-DRIVE-SETUP.md     # Google Drive integration setup guide
    ├── SUPABASE-AUTH-SETUP.md    # Supabase auth configuration guide
    └── ...
```

---

## 3. Deployment

`deploy.bat <branch>` — the single deployment command.

```
deploy dev     → deploys to ionetiq.dev/approvedoc/dev/
deploy main    → deploys to ionetiq.dev/approvedoc/ (production)
```

**What it does:**
1. Finds `approvedoc_DDMMYYYY_HHmm.zip` in `Downloads`
2. Extracts it to the IIS working directory
3. Regenerates cache-busting strings on all HTML/JS files
4. Writes `version.js` with `APP_PUBLISHED = 'DD/MM/YYYY HH:MM'`
5. Switches to the target git branch
6. Commits everything with the content of `CHANGES.txt` as the message
7. Pushes to GitHub

**Zip naming convention:** `approvedoc_DDMMYYYY_HHmm.zip` (4-digit year).

**Every zip repackage must update three files in lockstep:**
- Zip filename (date/time)
- `BUILD_TIMESTAMP.txt` (`DD/MM/YYYY HH:MM`, UK/London time)
- `CHANGES.txt` (used verbatim as the git commit message)

**`assets/pdfjs/` is always excluded from zips** — managed separately.

---

## 4. Shared JavaScript Modules

All shared modules live in `assets/js/` and are loaded in every page in a defined order (see §5.2).

### 4.1 `supabase-client.js`

Sets up the Supabase JS client and session management.

**Key exports (all on `window`):**
- `sb` — the Supabase client instance (used everywhere as `sb.from(...)`, `sb.auth.*`, `sb.storage.*`)
- `AppSession` — thin wrapper over `localStorage` for reading/writing the session token
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — placeholders substituted at deploy time

**AppSession:**
```js
AppSession.save(session)   // Persist session to localStorage
AppSession.load()          // Returns parsed session object or null
AppSession.clear()         // Removes session from localStorage
```

Session is stored under the key `'app_session'` — a deliberate plain name to avoid browser extension pattern matching.

**Important:** `SUPABASE_URL` and `SUPABASE_ANON_KEY` are template placeholders (`{{...}}`) in source — `deploy.bat` substitutes real values. Never hardcode these.

---

### 4.2 `auth.js`

The authentication and authorisation module. Everything auth-related goes through `Auth.*`.

**Role model (fixed — must match RLS policies):**

| Role | Access |
|---|---|
| `super_admin` | All organisations. ionetiq team only. |
| `admin` | One organisation. Full admin functions. |
| `user` | One organisation. Editing capability. |
| `view` | One organisation. Read-only. |

**Public API (`window.Auth`):**

```js
// Authentication
await Auth.requireAuth()          // Call at top of every protected page.
                                  // Loads session, profile, organisation.
                                  // Redirects to login if unauthenticated.
                                  // Returns session or null.

await Auth.requireGuest()         // Call on login page.
                                  // Redirects to dashboard if already logged in.

await Auth.signOut()              // Signs out and redirects to login.

// Session / Profile
Auth.getSession()                 // Returns current Supabase session object
Auth.getProfile()                 // Returns profiles row for current user
Auth.getOrganisationId()          // Returns UUID of active organisation

// Role checks
Auth.isSuperAdmin()               // Boolean
Auth.isAdmin()                    // Boolean (admin or super_admin)
Auth.canEdit()                    // Boolean (user, admin, or super_admin)

// Organisation switcher (super_admin only)
await Auth.setActiveOrganisation(orgId)   // Switch active org; returns bool
await Auth.getAllOrganisations()           // Returns all org rows

// User preferences (stored in profiles.preferences JSONB)
Auth.getPreference(key, defaultVal)
await Auth.setPreference(key, value)

// UI refresh — must be called after SidebarHtml.inject()
Auth.refreshUI()
```

**`requireAuth()` flow:**
1. Loads session from `AppSession.load()`
2. Calls `sb.auth.setSession()` to restore the Supabase session
3. **Cross-domain patch:** Creates a second Supabase client (`window._authenticatedSb`) with the access token hardcoded in the `Authorization` header, then overrides `sb.from = (table) => window._authenticatedSb.from(table)`. This is necessary because `setSession()` does not always propagate to the client's internal query state on new domains.
4. Loads the `profiles` row via `_loadProfile()` — with an explicit `fetch()` fallback in case the client-level query returns nothing due to session sync issues
5. Resolves the active organisation via `_resolveActiveOrganisation()`
6. Calls `_applyUserUI()` to update the DOM

**`_applyUserUI()` / `Auth.refreshUI()`:**
- Fills all `[data-user-name]`, `[data-user-email]`, `[data-user-role]` elements
- Renders avatar in `[data-user-initials]` elements (image or initials)
- Removes `role-hidden` class from `[data-require-role="admin"]`, `[data-require-role="super_admin"]`, `[data-require-role="user"]` elements based on the user's role
- Renders the organisation switcher into `[data-active-organisation]` elements

**Organisation resolution:**
- Non-super-admins: always their `profiles.organisation_id`
- Super-admins: last-picked org stored in `localStorage` (scoped to domain + path), defaulting to the alphabetically-first org

---

### 4.3 `app.js`

General-purpose utilities.

**`App.toast(message, type, duration)`**  
Shows a Bootstrap toast notification in the bottom-right corner.
- `type`: `'success'` (default), `'danger'`, `'warning'`, `'info'`
- `duration`: ms before auto-dismiss (default 3500)

**`App.confirm(options)`**  
Shows a confirmation modal. Returns a `Promise<boolean>`.
```js
const ok = await App.confirm({
  title: 'Delete this item?',
  message: 'This cannot be undone.',
  confirmText: 'Delete',
  confirmClass: 'btn-danger'
});
if (ok) { /* proceed */ }
```

**`App.formatDate(iso)`** / **`App.formatDateTime(iso)`**  
Formats ISO date strings in UK locale (`29 Jul 2026`, `29 Jul 2026 14:30`).

**`App.escHtml(str)`**  
Escapes `&`, `<`, `>`, `"` for safe HTML insertion.

**`App.showLoader()` / `App.hideLoader()`**  
Full-page loading overlay.

**`App.guardModalClose(modalEl, bsModalInstance, isDirtyFn)`**  
Wires a dirty-guard onto a Bootstrap modal. If `isDirtyFn()` returns true when the user tries to close, shows a "Discard changes?" confirmation first.

```js
// Typical usage — call after modal is shown, not before:
distModalEl.addEventListener('shown.bs.modal', () => {
  _snapshot = takeSnapshot();
  App.guardModalClose(distModalEl, bsModal, () => !_saved && takeSnapshot() !== _snapshot);
});
```

**Important pattern:** Use a `_saved` boolean flag (set to `true` immediately before calling `modal.hide()` after a successful save) rather than comparing snapshots. The snapshot comparison returns dirty even when empty because clearing form fields changes the snapshot vs `null`.

---

### 4.4 `sidebar-html.js`

Injects the sidebar HTML and Preferences modal, and manages per-user display preferences.

**`SidebarHtml.inject(root)`**  
Call this after `Auth.requireAuth()` and before `Auth.refreshUI()` on every page.

- `root` — path to app root (use `window._appRootUrl || '../../'`)
- Injects the full sidebar nav, footer (user avatar, preferences, sign out), and Preferences modal
- Sets `window._appRoot = root` for auth.js redirect compatibility

**`_scopedKey(baseKey)`** (internal)  
Builds a localStorage key scoped to `hostname + absoluteRoot`, e.g. `app_accent:ionetiq.dev/approvedoc/dev/`. This isolates display preferences between:
- Development (`ionetiq.dev/approvedoc/dev/`) and production (`ionetiq.dev/approvedoc/`)
- Different domains (`ionetiq.dev` vs `approvedoc.app`)

**Preferences modal tabs:**
- **Display** — Accent colour, sidebar colour, dark mode
- **Document** — Upload button, drop zone, prompt on drop, delete button
- **Current User** — Avatar, display name, job title, password change

**Subsystem markers:**  
Nav entries for optional subsystems (Documents, Issues, etc.) are wrapped in `<!-- SUBSYSTEM:name:start -->` / `<!-- SUBSYSTEM:name:end -->` comments. Remove a block to remove that subsystem from the nav. See `docs/SUBSYSTEMS.md`.

---

### 4.5 `sidebar.js`

Handles sidebar toggle, collapse, and mobile overlay behaviour. No configuration needed — initialise with `Sidebar.init()`.

---

### 4.6 `theme.js`

Handles the dark/light mode toggle button (`[data-theme-toggle]`). Reads/writes `'app_theme'` in localStorage (unscoped — theme preference is shared across environments). Also handles accent colour application.

---

### 4.7 `status-widget.js`

Renders a compliance status summary widget in the header. Shows counts of pending/overdue/acknowledged/rejected items for the current user.

```js
StatusWidget.init()      // Initialise (called from page init)
StatusWidget.refresh()   // Refresh counts (call after status changes)
```

---

### 4.8 `profile-modal.js`

Helper for the avatar upload flow in the Preferences modal (Current User tab). Handles file selection, upload to `user-avatars` bucket, and cache-busting.

---

## 5. Page Conventions

### 5.1 HTML Head Template

Every page follows this structure:

```html
<!DOCTYPE html>
<html lang="en" data-bs-theme="light" data-app-root="../../">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Page Title - approveDoc</title>

  <!-- CDN CSS -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/core@1.4.0/dist/css/tabler.min.css" />
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.44.0/dist/tabler-icons.min.css" />

  <!-- App CSS -->
  <link rel="stylesheet" href="../../assets/css/theme.css" />

  <!-- Inline theme script — MUST be first, before any other scripts -->
  <!-- Applies dark mode, accent colour, and sidebar colour from localStorage
       before the page renders, to avoid flash of wrong theme. Also computes
       window._appRootUrl for use throughout the page. -->
  <script>
    (function() {
      try {
        var root = document.documentElement.getAttribute('data-app-root') || './';
        var absoluteRoot = new URL(root, window.location.href).pathname;
        var suffix = ':' + window.location.hostname + absoluteRoot;
        window._appRootUrl = (new URL(root, window.location.href)).href;
        if (!window._appRootUrl.endsWith('/')) window._appRootUrl += '/';
        // Apply saved theme
        var savedTheme = localStorage.getItem('app_theme');
        var theme = savedTheme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
        document.documentElement.setAttribute('data-bs-theme', theme);
        // Apply saved accent colour
        var accent = localStorage.getItem('app_accent' + suffix);
        if (accent) {
          document.documentElement.style.setProperty('--tblr-primary', accent);
          // ... RGB decomposition for rgba() usage
        }
        // Apply saved sidebar colour
        var sidebarBg = localStorage.getItem('app_sidebar_bg' + suffix);
        if (sidebarBg) { _applySidebarColours(sidebarBg); }
      } catch(e) {}
    })();
  </script>
</head>
```

**`data-app-root`** — relative path from the page back to the app root:
- Root `index.html` → `"./"`
- `pages/xxx/index.html` → `"../../"`

This is the only value that needs to change between page depths. Everything else derives from it.

---

### 5.2 Script Load Order

Every page loads scripts in this exact order:

```html
<!-- 1. CDN libraries -->
<script src="https://cdn.jsdelivr.net/npm/@tabler/core@1.4.0/dist/js/tabler.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<!-- 2. Core app modules (order matters — each depends on the previous) -->
<script src="../../assets/js/version.js"></script>          <!-- APP_PUBLISHED constant -->
<script src="../../assets/js/supabase-client.js"></script>  <!-- sb, AppSession -->
<script src="../../assets/js/auth.js"></script>             <!-- Auth -->
<script src="../../assets/js/app.js"></script>              <!-- App -->
<script src="../../assets/js/theme.js"></script>
<script src="../../assets/js/sidebar-html.js"></script>     <!-- SidebarHtml -->
<script src="../../assets/js/sidebar.js"></script>          <!-- Sidebar -->
<script src="../../assets/js/profile-modal.js"></script>
<script src="../../assets/js/status-widget.js"></script>    <!-- StatusWidget -->

<!-- 3. Page-specific scripts (inline or external) -->
<script>
  (async () => {
    const session = await Auth.requireAuth();
    if (!session) return;
    SidebarHtml.inject(window._appRootUrl || '../../');
    Sidebar.init();
    Auth.refreshUI();
    StatusWidget.init();
    // ... page-specific init
  })();
</script>
```

---

### 5.3 Role-Gated Elements

Elements hidden from certain roles use the `role-hidden` CSS class plus a `data-require-role` attribute:

```html
<!-- Only visible to admin and super_admin -->
<li class="nav-item role-hidden" data-require-role="admin">...</li>

<!-- Only visible to super_admin -->
<button class="role-hidden" data-require-role="super_admin">...</button>

<!-- Only visible to user role exactly (not admin) -->
<li class="nav-item role-hidden" data-require-role="user-only">...</li>
```

`Auth.refreshUI()` (i.e. `_applyUserUI()`) removes `role-hidden` from matching elements after the sidebar is injected. Elements without a matching role remain hidden.

`role-hidden` is defined in `theme.css` as `display: none !important`.

**Do not use `d-none`** for role-gated elements — `d-none` is used for feature-controlled visibility (e.g. upload button shown/hidden by user preferences) and the two systems must not interfere.

---

## 6. Feature Modules

### 6.1 Documents

**Files:** `pages/documents/index.html`, `pages/documents/documents.js`, `pages/documents/config.js`

**What it does:** Upload, browse, and view PDF documents. Supports Supabase storage and external sources (Google Drive, direct URLs, REST APIs).

**`config.js`:**  
Maps logical names to actual DB table/column names. If the schema ever changes, update only `config.js`. Key values:
- `DOC_CONFIG` — table names, column names, bucket name, pdf.js viewer path
- `DOC_DEFAULT_FEATURES` — app-level feature flags for the viewer (toolbar, nav panes, which buttons to show/hide)

**`documents.js` key functions:**

| Function | Purpose |
|---|---|
| `loadDocuments()` | Fetches all docs for current org, renders the list |
| `loadDocFeatures()` | Merges user preferences into `DOC_FEATURES` (upload/delete only — viewer config is app-level) |
| `applyDocFeatures()` | Shows/hides upload button, drop zone, delete button based on `DOC_FEATURES` |
| `openDoc(docId)` | Selects a doc; fetches its file and loads the PDF viewer |
| `buildPdfHash()` | Builds the pdf.js URL hash (zoom, page mode, toolbar flags) |
| `injectPdfStyles()` | Injects CSS into the pdf.js iframe to hide unwanted toolbar buttons |
| `uploadAndSave(...)` | Uploads a file to Supabase storage and creates `ad_document` + `ad_document_file` rows |
| `bindUpload()` | Wires the New Document modal — handles Upload, Google Drive, Direct URL, REST API source types |

**Source types** in `ad_document_file.source_type`:
- `SUPABASE` (default) — file in Supabase storage bucket
- `URL` — direct download URL (proxied through edge function)
- `REST` — REST API endpoint with optional auth (proxied through edge function)

For non-SUPABASE sources, the file is fetched via `POST /functions/v1/fetch-document` with the user's JWT, which proxies the request server-side.

---

### 6.2 Audiences

**File:** `pages/audiences_combined/index.html`

Manages audience definitions. An audience is a named group of users, defined either by explicit membership (`FIXED`) or by criteria (`CRITERIA` — based on department, location, job role, etc.).

**Key behaviour:**
- Type-ahead search for criteria values (country pinned to top within its group)
- Warning when changing audience type (existing members/criteria will be lost)
- `saveAudience()` on type change: deletes old members/criteria, inserts new ones

---

### 6.3 Distribution

**File:** `pages/distribution/index.html`

Creates and manages document distributions — the mechanism by which documents are sent to audiences for acknowledgement.

**Create Distribution modal:**
- **Left half:** Name, Document, Type, Start date, radio toggle for Due date vs Days to acknowledge, Instructions
- **Right half (tabbed card):**
  - *Audiences* — unlimited, type-ahead search, each audience already picked is excluded from other rows' dropdowns
  - *Warnings* — First and Second warning, each with Days + Before/After toggle

**Validation on save (all required):**
- Name, Document, Distribution type, Start date
- Due date OR Days to acknowledge
- At least one audience
- At least First warning (days + direction)

**Dirty guard:** Snapshot taken on modal open. "Discard changes?" prompt if user closes with unsaved changes. A module-level `_distSaved` flag (set to `true` before `modal.hide()` after successful save) bypasses the guard — this flag must be at module scope (not inside the async IIFE) so `saveDistribution()` can access it.

**Due date computation:**  
If "Days to acknowledge" mode: `due_date = start_date + N calendar days` (simple elapsed time). Working-days option is planned but not yet implemented.

**DB function `build_distribution_items`:**  
Called after saving a distribution. Uses `DISTINCT ON` + `ON CONFLICT DO NOTHING` so users who belong to multiple selected audiences get exactly one distribution item.

---

### 6.4 Users (Admin)

**File:** `pages/admin/users.html`

Admin user management — create (invite), edit, and delete users.

**Invite flow:**  
Calls the `manage-user` Edge Function with `action: 'create'`. The function creates both a `profiles` row and an `ad_user` row, sends the invite email with a `redirect_to` pointing at `pages/auth/reset-password.html`.

**Manager field:**  
Type-ahead picker for `ad_user.manager_id`. Clearing the manager and checking "Top-level manager" sets `is_top_level = true` and `manager_id = null`.

---

### 6.5 User View (Testing)

**File:** `pages/testing/user-view.html`

Shows a user's distribution items grouped by status. Intended for end-user access.

**Section groups:**

| Group | Statuses included |
|---|---|
| Awaiting Action | `PENDING`, `OVERDUE` |
| Acknowledged | `APPROVED` |
| Rejected | `REJECTED` |
| Reference | `REFERENCE` |

**Interaction:**
- Double-click a row or click the checklist icon → navigates to `acknowledge.html?item={id}`
- Section bands: `#D3D3D3` in light mode, CSS variable in dark mode

**Column widths** (set on `<colgroup>` directly on the `<table>`, not in the per-section template):

| Column | Width |
|---|---|
| Document | 20% |
| Due date | 8% |
| Status | 10% |
| Audience | 20% |
| Date added | 8% |
| Instructions | 32% |
| Buttons | 2% |

---

### 6.6 Acknowledge

**File:** `pages/testing/acknowledge.html`

Full-page document viewer + action buttons for a single distribution item.

**Query params:** `?item={distrib_item_id}`

**Actions:**
- **Acknowledge** — sets `status = 'APPROVED'`, `acknowledged = true`, `acknowledged_date = today`
- **Reject** — shows reason prompt, sets `status = 'REJECTED'`, `rejected = true`, `rejected_reason`
- **Add to Reference** — inserts into `ad_document_reference`, sets `status = 'REFERENCE'`

**Button states:**
- Acknowledge and Reject are disabled once any action has been taken on the item
- Add to Reference is disabled until status is `APPROVED`; disabled (different tooltip) if already `REFERENCE`

**PDF loading:**  
Checks `source_type` on the file record. `SUPABASE` → signed URL → blob. Others → POST to `fetch-document` edge function.

**CSS injection:**  
After the pdf.js iframe loads, `injectPdfStyles()` injects a `<style>` tag into the iframe's document to hide print/download/annotation editor/overflow buttons, matching the Documents page viewer exactly.

---

### 6.7 Org Chart (Testing)

**File:** `pages/testing/org-chart.html`

Recursive, unlimited-depth org hierarchy visualisation.

**Model:**
- `ad_user.manager_id` — FK to self; one manager per user
- `ad_user.is_top_level` — boolean; marks intentional roots (not just unassigned users)
- Distinction: `manager_id = null` + `is_top_level = false` → not yet assigned; `manager_id = null` + `is_top_level = true` → intentional top of hierarchy

**Layout:** 50/50 split — tree (left) + "Not Yet Assigned" panel (right)

**Connector lines:**
- Vertical line on each child: `::before` pseudo-element, full height on non-last children, truncated to avatar centre on last child (creates └ corner)
- Horizontal tick: `::after` pseudo-element, aligned to avatar centre (18px from top of node = 5px padding + 13px half-avatar)
- Indent: 23px (half of 26px avatar + ~10px row padding)

**Drag-and-drop:**  
Drag any user row and drop onto another user → sets `manager_id` to the target. Circular reference prevention (`isDescendant()` check). Tree re-renders after drop.

---

## 7. Database Schema

### 7.1 Core Tables

| Table | Purpose |
|---|---|
| `auth.users` | Supabase built-in; all authenticated users |
| `organisations` | Top-level tenant; everything is scoped to an org |
| `profiles` | Extends `auth.users`; display name, role, avatar, preferences (JSONB) |

**Role values in `profiles.role`:** `super_admin`, `admin`, `user`, `view`

### 7.2 approveDoc Tables

| Table | Purpose |
|---|---|
| `ad_user` | Per-org user record extending `auth.users`; job title, department, country, manager |
| `ad_category` | Document categories (Policy, Procedure, Guidance, etc.) |
| `ad_document` | Document metadata (name, description, category) |
| `ad_document_file` | File record; `storage_path` for Supabase storage, or `external_url`/`external_ref` for external sources |
| `ad_external_source` | External repository connection (SharePoint, OnBase, REST API, etc.) with Vault credential reference |
| `ad_audience` | Named group of users (`FIXED` membership or `CRITERIA`-based) |
| `ad_audience_member` | Explicit members of a FIXED audience |
| `ad_audience_criteria` | Criteria rules for a CRITERIA audience |
| `ad_distribution` | A distribution: document → audiences, with dates, warnings, instructions |
| `ad_distribution_audience` | Many-to-many: distribution ↔ audience |
| `ad_distribution_item` | One per user per distribution; tracks acknowledgement status |
| `ad_document_reference` | Documents a user has saved to their personal reference library |
| `ad_department` | Lookup: departments |
| `ad_job_role` | Lookup: job roles |
| `ad_location` | Lookup: locations |
| `ad_category` | Lookup: document categories |
| `ad_country` | Reference: ISO countries |
| `ad_language` | Reference: ISO languages |

**`ad_distribution_item` status values:**

| Status | Meaning |
|---|---|
| `PENDING` | Awaiting action, within due date |
| `OVERDUE` | Awaiting action, past due date |
| `APPROVED` | Acknowledged by the user |
| `REJECTED` | Rejected by the user (with reason) |
| `REFERENCE` | Acknowledged and saved to reference library |

### 7.3 RLS Policy Pattern

All approveDoc tables with `organisation_id` use organisation-scoped RLS:

```sql
-- Helper function (defined in 01-core-schema.sql)
create function _my_organisation_id() returns uuid as $$
  select organisation_id from profiles where id = auth.uid()
$$ language sql security definer stable;

create function _my_role() returns text as $$
  select role from profiles where id = auth.uid()
$$ language sql security definer stable;

-- Typical table policy
create policy "Organisation scope"
  on public.ad_foo for all
  using (organisation_id = _my_organisation_id());

-- Super admin bypass
create policy "Super admins: full access"
  on public.ad_foo for all
  using (_my_role() = 'super_admin');
```

### 7.4 Migration History

| Migration | Description |
|---|---|
| `01-core-schema.sql` | `organisations`, `profiles`, helper functions, RLS patterns |
| `02-documents.sql` | `ad_document`, `ad_document_file`, storage bucket |
| `03-issues.sql` | Issues tracking tables |
| `04-sample-data.sql` | Sample data (dev only) |
| `08-approvedoc-schema.sql` | Core approveDoc tables: `ad_user`, audiences, distribution, items |
| `13-audience-*.sql` | Audience description, user-country link |
| `14-audience-criteria.sql` | Criteria-based audiences |
| `16-job-role.sql` | Job role lookup table |
| `17-distribution.sql` | Distribution and distribution items |
| `20-distribution-item-rejected-reason.sql` | `rejected_reason`, `rejected_date` on `ad_distribution_item` |
| `21-ad-user-manager-id.sql` | `manager_id` self-referencing FK on `ad_user` |
| `22-ad-document-reference.sql` | `ad_document_reference` table with RLS |
| `23-external-document-sources.sql` | `ad_external_source` table; `source_type`, `external_url`, `external_ref` on `ad_document_file` |
| `24-rls-country-language.sql` | Enable RLS on `ad_country` and `ad_language` |

---

## 8. Supabase Edge Functions

### 8.1 `manage-user`

**Endpoint:** `POST /functions/v1/manage-user`  
**Auth:** JWT required (admin or super_admin)

Handles user lifecycle operations that require service role access (bypassing RLS):

| `action` | What it does |
|---|---|
| `create` | Creates `auth.users` entry (invite email), `profiles` row, `ad_user` row |
| `update_password` | Updates password for a user by admin |
| `delete` | Deletes user from `auth.users` (cascades to profiles) |

**Invite flow:** On `create`, the function calls `supabase.auth.admin.inviteUserByEmail()` with a `redirect_to` pointing at the app's `reset-password.html`. The new user receives an email and sets their password on first login.

### 8.2 `fetch-document`

**Endpoint:** `POST /functions/v1/fetch-document`  
**Auth:** JWT required  
**Body:** `{ "file_id": "<uuid>" }`

Proxies document retrieval for non-Supabase sources:

1. Verifies the caller is authenticated and belongs to the document's organisation
2. Looks up `ad_document_file` including the linked `ad_external_source`
3. Routes by `source_type`:
   - `SUPABASE` → generates a signed URL and redirects
   - `URL` → fetches directly, following redirects (including Google Drive virus-scan confirm tokens)
   - `REST` / `SHAREPOINT` / `ONBASE` → fetches with credentials from Supabase Vault
4. Returns the PDF as a stream

**Google Drive handling:**  
The function manually follows HTTP redirects and detects Google Drive's virus-scan confirmation page (HTML response instead of PDF). It extracts the `confirm=` token and retries automatically — no user interaction required.

**Credentials:**  
For authenticated REST sources, credentials are stored in Supabase Vault (never in `ad_document_file` directly). The function reads them via `vault.decrypted_secrets` at request time.

---

## 9. Authentication & Sessions

### Login flow (`pages/auth/login.html`)

1. User submits email + password
2. Calls `sb.auth.signInWithPassword()`
3. On success, `AppSession.save(session)` stores the session in localStorage
4. Redirects to `index.html`

### Session restoration (every protected page)

`Auth.requireAuth()`:
1. Calls `AppSession.load()` to get the stored session
2. If no session → redirects to login
3. Calls `sb.auth.setSession({ access_token, refresh_token })`
4. If setSession fails (expired token) → clears session, redirects to login
5. Patches `sb.from` to use authenticated client (cross-domain fix — see §10)
6. Loads profile and organisation

### Password reset (`pages/auth/reset-password.html`)

Dual-purpose page:
- Without token: shows "send reset email" form
- With `#access_token` hash: shows "set new password" form

### Password set (`pages/auth/set-password.html`)

Used for first-time password set after invite. Reads `access_token` from the URL hash.

---

## 10. Cross-Domain Compatibility

approveDoc is hosted at `ionetiq.dev/approvedoc/` but is also accessible at `approvedoc.app/` (DNS alias to the same IIS server and folder).

**Problem:** `sb.auth.setSession()` in Supabase JS v2 does not always propagate the access token to the client's internal query state when called on a new origin. This means `sb.from('profiles').select('*')` runs as anonymous and returns nothing, even though the session was successfully restored.

**Solution (in `auth.js`):**  
After `setSession()` succeeds, create a second Supabase client with the access token hardcoded in a global `Authorization` header:

```js
window._authenticatedSb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  global: { headers: { Authorization: 'Bearer ' + data.session.access_token } },
  auth:   { persistSession: false, autoRefreshToken: false }
});
// Override sb.from to route all table queries through the authenticated client
sb.from = (table) => window._authenticatedSb.from(table);
```

This patch is applied once and persisted on `window`, so all subsequent `sb.from(...)` calls throughout the app automatically carry the correct token.

**Profile fallback:**  
`_loadProfile()` also has a raw `fetch()` fallback using the stored access token directly, in case even the patched client fails during the brief window between session restore and the `sb.from` patch applying.

---

## 11. localStorage Isolation

approveDoc uses localStorage for session, theme preferences, accent colour, and sidebar colour. These must be isolated between:
- Dev (`ionetiq.dev/approvedoc/dev/`) and production (`ionetiq.dev/approvedoc/`)
- Different domains (`ionetiq.dev` vs `approvedoc.app`)

**Strategy:** All preference keys are suffixed with `hostname + absoluteRoot`:

```
app_accent:ionetiq.dev/approvedoc/dev/
app_accent:approvedoc.app/dev/
app_accent:ionetiq.dev/approvedoc/
```

**Key:**  `app_session` — unsuffixed (shared per origin — browsers already isolate localStorage by origin).

**Where this is applied:**
- Inline theme script in every HTML page (`var suffix = ':' + window.location.hostname + absoluteRoot`)
- `_scopedKey()` in `sidebar-html.js`
- `_activeOrganisationKey()` in `auth.js`

**`window._appRootUrl`:**  
Also computed in the inline theme script — the absolute URL to the app root (e.g. `https://approvedoc.app/dev/`). Used by `auth.js` for redirects and by `SidebarHtml.inject()` so sidebar links resolve correctly regardless of the page's own location.

---

## 12. PDF Viewer

approveDoc uses a self-hosted copy of **pdf.js** at `assets/pdfjs/`. This folder is excluded from deployment zips and managed separately.

**Why self-hosted:**  
Allows CSS injection into the iframe to customise the toolbar (hiding print, download, annotation editor, etc.) without CORS restrictions.

**Viewer URL pattern:**
```
{pdfViewerUrl}?file={encodeURIComponent(blobUrl)}#{hash}
```

Where `hash` is built by `buildPdfHash()`:
```
page=1&zoom=page-fit&pagemode=thumbs&toolbar=1&navpanes=1&locale=en-US
```

**Blob URL approach:**  
The PDF is always fetched to a blob first (`URL.createObjectURL(new File([blob], name, { type: 'application/pdf' }))`), then passed to pdf.js as a blob URL. This bypasses pdf.js's `validateFileURL` security check that would block Supabase signed URLs (external hosts).

**CSS injection (`injectPdfStyles()`):**  
After the iframe loads, a `<style>` tag is injected into the iframe's document. This hides:
- Print, download buttons
- Annotation editor buttons (pencil, T, ink, stamp)
- Overflow menu button
- Rotate buttons
- Separators
- Open file, view bookmark, document properties, presentation mode buttons

The toolbar, thumbnails, page navigation, zoom, and search remain visible.

**Flash prevention:**  
The iframe is set to `visibility: hidden` before `src` is assigned. After the `load` event, styles are injected, then `visibility` is cleared after 150ms.

---

## 13. External Document Sources

Documents can be stored in Supabase or fetched from external systems.

**`ad_document_file.source_type`:**

| Value | Storage |
|---|---|
| `SUPABASE` | Supabase storage bucket (default) |
| `URL` | Publicly accessible URL |
| `REST` | REST API endpoint (with optional auth) |
| `SHAREPOINT` | Microsoft SharePoint / Graph API (planned) |
| `ONBASE` | Hyland OnBase REST API (planned) |

**`ad_external_source` table:**  
Stores connection configuration for a repository — base URL, auth type, and a reference to a Supabase Vault secret (never the credential itself).

**Adding an external document (New Document modal):**
- Upload file → Supabase storage (existing flow)
- Google Drive → paste sharing URL; auto-converts to `https://drive.google.com/uc?export=download&id=FILE_ID`
- Direct URL → any publicly accessible PDF URL
- REST API → endpoint + auth type + optional reference ID

**Google Drive authentication:**  
Google Drive sharing URLs with "Anyone with the link can view" work without OAuth. The `fetch-document` edge function handles the redirect chain and extracts the `confirm=` token from the virus-scan page for larger files.

For browse-and-pick from Google Drive (Picker API), see `docs/GOOGLE-DRIVE-SETUP.md`.

---

## 14. Known Patterns & Conventions

### Module-level vs scoped variables
Variables that need to be accessed from both async init code and top-level functions (e.g. dirty guard flags, modal instances) must be declared at module scope (top-level `let`), not inside async IIFEs. A variable declared inside `(async () => { ... })()` is inaccessible from functions defined outside it.

```js
// CORRECT — accessible everywhere
let _distSaved = false;

(async () => {
  // ... init
})();

async function saveDistribution() {
  _distSaved = true;  // works
}
```

### Dirty guard pattern
```js
let _saved    = false;
let _snapshot = null;
let _guarded  = false;

modalEl.addEventListener('shown.bs.modal', () => {
  _saved    = false;
  _snapshot = takeSnapshot();
  if (!_guarded) {
    _guarded = true;
    App.guardModalClose(modalEl, bsModal, () => !_saved && takeSnapshot() !== _snapshot);
  }
});

modalEl.addEventListener('hidden.bs.modal', () => {
  _snapshot = null;
  _saved    = false;
  resetModal();
});

async function save() {
  // ... validate and save
  _saved = true;        // Set BEFORE calling modal.hide()
  bsModal.hide();
}
```

### Type-ahead picker
Used for audience search, manager picker, etc. Pattern:
- Text input for display, hidden input for the UUID value
- `focus` → show full list; `input` → filter list; `mousedown` on item (not `click`) to prevent blur closing the dropdown before selection registers; `blur` with 150ms delay to allow mousedown to fire

### `d-none` vs `role-hidden`
- `role-hidden` — for role-gated nav/UI elements (removed by `Auth.refreshUI()`)
- `d-none` — for feature-controlled elements (upload button, drop zone) managed by `applyDocFeatures()`
- Never mix them on the same element — auth.js manages `role-hidden`; feature code manages `d-none`

### Supabase query pattern
Always filter by `organisation_id` from `Auth.getOrganisationId()`:
```js
const { data, error } = await sb
  .from('ad_foo')
  .select('*')
  .eq('organisation_id', Auth.getOrganisationId())
  .order('name');
```

### Date handling
All dates stored as ISO strings (`YYYY-MM-DD` for dates, `YYYY-MM-DDTHH:MM:SSZ` for timestamps). Display via `App.formatDate()` (UK locale: `29 Jul 2026`). Due date from "days to acknowledge" is computed as simple elapsed calendar days — working days option planned.

### Windows `cmd.exe` batch scripting
Leading-zero months/times are interpreted as octal in `cmd.exe` arithmetic. Documented and fixed in `deploy.bat` — do not use `%date%` or `%time%` directly in arithmetic expressions.
