# Google Drive Integration — Setup Guide

This guide walks through setting up Google Drive integration for approveDoc,
enabling users to browse and select documents directly from Google Drive.

---

## Overview

approveDoc uses two Google APIs:
- **Google Picker API** — the file browser UI (runs in the user's browser)
- **Google Drive API** — to verify file access and retrieve metadata

You will need:
1. A Google Cloud project
2. An API Key (for the Picker UI)
3. An OAuth 2.0 Client ID (so users can authenticate with their Google account)

Both are free. No billing is required for read-only Drive access at normal usage volumes.

---

## Step 1 — Create a Google Cloud Project

1. Go to [https://console.cloud.google.com](https://console.cloud.google.com)
2. Click the project dropdown (top left) → **New Project**
3. Name it e.g. `approveDoc` → **Create**
4. Make sure the new project is selected in the dropdown

---

## Step 2 — Enable Required APIs

1. In the left menu go to **APIs & Services → Library**
2. Search for **Google Drive API** → click it → **Enable**
3. Search for **Google Picker API** → click it → **Enable**

---

## Step 3 — Create an API Key

The API Key is used to load the Picker UI. It is embedded in the frontend
and is safe to be public (you will restrict it by domain below).

1. Go to **APIs & Services → Credentials**
2. Click **+ Create Credentials → API Key**
3. Copy the key — you will need it later
4. Click **Edit API key** (pencil icon):
   - Under **Application restrictions** → select **Websites**
   - Add your domains:
     ```
     https://ionetiq.dev/*
     https://approvedoc.app/*
     http://localhost/*
     ```
   - Under **API restrictions** → select **Restrict key**
   - Select: **Google Drive API** and **Google Picker API**
5. Click **Save**

---

## Step 4 — Create an OAuth 2.0 Client ID

The OAuth Client ID lets users sign in with their Google account so the
Picker can show their Drive files. approveDoc never stores Google credentials —
the user authenticates temporarily in their browser.

1. Go to **APIs & Services → Credentials**
2. Click **+ Create Credentials → OAuth client ID**
3. If prompted, configure the **OAuth consent screen** first:
   - User type: **External**
   - App name: `approveDoc`
   - User support email: your email
   - Authorised domains: `ionetiq.dev`, `approvedoc.app`
   - Developer contact: your email
   - Scopes: click **Add or remove scopes** → add:
     - `.../auth/drive.readonly`
     - `.../auth/drive.file`
   - Save and continue through the steps
   - For testing, add your Google account as a **Test user**
   - Submit for verification when ready for production users
4. Back in Credentials → **+ Create Credentials → OAuth client ID**
   - Application type: **Web application**
   - Name: `approveDoc Web`
   - Authorised JavaScript origins — add:
     ```
     https://ionetiq.dev
     https://approvedoc.app
     http://localhost
     ```
   - Authorised redirect URIs: leave blank (Picker uses popup flow, not redirect)
5. Click **Create** → copy the **Client ID**

---

## Step 5 — Note your credentials

You will need these two values when configuring the integration in approveDoc:

| Value | Where to find it |
|---|---|
| **API Key** | APIs & Services → Credentials → API Keys |
| **OAuth Client ID** | APIs & Services → Credentials → OAuth 2.0 Client IDs |

Format:
```
API Key:    AIzaSy...
Client ID:  123456789-abc...apps.googleusercontent.com
```

---

## Step 6 — Add credentials to approveDoc

Once you have the API Key and Client ID, tell Mike / the developer and they
will add them to the approveDoc configuration. These are stored as:

- `GOOGLE_PICKER_API_KEY` — in the app config / Supabase environment
- `GOOGLE_OAUTH_CLIENT_ID` — in the app config / Supabase environment

---

## Notes

- The OAuth consent screen will show **"unverified app"** to users until
  Google verifies it. For internal use with test users added, this is fine.
  Verification is only required when opening to external Google accounts.
- The Picker only shows files the signed-in user has access to — it cannot
  browse files outside their Drive or shared drives they're not a member of.
- approveDoc stores only the **file ID** and constructs the download URL —
  no Google tokens or credentials are ever stored in the approveDoc database.
- If a file is later removed from Google Drive or permissions are revoked,
  the document will fail to load in approveDoc at that point.

---

## Supported Platforms (planned)

| Platform | Status |
|---|---|
| Google Drive | ✅ In development |
| Microsoft SharePoint / OneDrive | 🔜 Planned |
| Dropbox | 🔜 Planned |
| Box | 🔜 Planned |
| Direct URL | ✅ Available now |
| REST API | ✅ Available now |
