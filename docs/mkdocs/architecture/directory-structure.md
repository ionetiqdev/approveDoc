# Directory Structure

```
approveDoc/
├── index.html                    # Dashboard (root page)
├── deploy.bat                    # Deployment script
├── BUILD_TIMESTAMP.txt           # Set by deploy.bat — DD/MM/YYYY HH:MM
├── CHANGES.txt                   # Git commit message for next deploy
├── project.conf.example          # Template for project.conf (gitignored)
│
├── assets/
│   ├── css/
│   │   └── theme.css             # CSS overrides on top of Tabler
│   ├── js/                       # Shared modules — loaded on every page
│   │   ├── supabase-client.js    # Supabase client + AppSession
│   │   ├── auth.js               # Authentication, roles, organisation
│   │   ├── app.js                # Utilities: toast, confirm, guard
│   │   ├── sidebar-html.js       # Sidebar injection + Preferences modal
│   │   ├── sidebar.js            # Sidebar toggle / collapse
│   │   ├── theme.js              # Dark mode + accent colour
│   │   ├── status-widget.js      # Header compliance counter
│   │   ├── profile-modal.js      # Avatar upload helper
│   │   └── version.js            # Auto-generated; APP_PUBLISHED constant
│   └── pdfjs/                    # Self-hosted pdf.js (excluded from zips)
│
├── pages/
│   ├── auth/                     # Login, reset password, set password
│   ├── admin/                    # Organisations, Users
│   ├── audiences_combined/       # Audience management
│   ├── distribution/             # Distribution management
│   ├── documents/                # Document viewer + upload
│   │   ├── index.html
│   │   ├── documents.js          # All document logic
│   │   └── config.js             # Table/column/bucket mappings
│   ├── lookups/                  # Admin lookup editors
│   ├── reports/                  # Report placeholders
│   └── testing/                  # End-user facing pages
│       ├── user-view.html        # User's document list
│       ├── acknowledge.html      # Document viewer + actions
│       └── org-chart.html        # Org hierarchy
│
├── supabase/
│   ├── 01- to 24-*.sql          # Sequential DB migrations
│   └── functions/
│       ├── manage-user/          # Edge function: user lifecycle
│       └── fetch-document/       # Edge function: external doc proxy
│
└── docs/                         # Developer documentation
    ├── CODEBASE.md
    ├── APPROVEDOC_SCHEMA.md
    ├── GOOGLE-DRIVE-SETUP.md
    └── SUPABASE-AUTH-SETUP.md
```

!!! tip "pdfjs/ is excluded from zips"
    `assets/pdfjs/` is never included in deployment zips. It is managed separately on the server. Always exclude it when repackaging.
