# Directory Structure

```
approveDoc/
├── index.html                    # Dashboard (root page)
├── deploy.bat                    # Deployment script
├── BUILD_TIMESTAMP.txt           # Set by deploy.bat
├── CHANGES.txt                   # Git commit message for deploy.bat
├── project.conf.example          # Template for project.conf (gitignored)
│
├── assets/
│   ├── css/theme.css             # Custom overrides on top of Tabler
│   └── js/
│       ├── supabase-client.js    # Supabase client + AppSession
│       ├── auth.js               # Authentication, roles, UI
│       ├── app.js                # Shared utilities
│       ├── sidebar-html.js       # Sidebar HTML + Preferences modal
│       ├── sidebar.js            # Sidebar toggle behaviour
│       ├── theme.js              # Dark mode + accent colour
│       ├── status-widget.js      # Header compliance counter
│       ├── profile-modal.js      # Avatar upload helper
│       └── version.js            # Auto-generated build timestamp
│
├── pages/
│   ├── auth/                     # Login, password reset, set password
│   ├── admin/                    # Organisations, Users
│   ├── audiences_combined/       # Audience management
│   ├── distribution/             # Distribution management
│   ├── documents/                # Document viewer + upload
│   ├── lookups/                  # Lookup table editors
│   └── testing/                  # User View, Acknowledge, Org Chart
│
├── supabase/
│   ├── 01- to 24-*.sql          # Sequential DB migrations
│   └── functions/
│       ├── manage-user/          # Edge function: user lifecycle
│       └── fetch-document/       # Edge function: external doc proxy
│
└── docs/                         # Developer documentation
```

!!! note "assets/pdfjs/"
    `assets/pdfjs/` is **excluded from deployment zips** and managed separately on each server.
