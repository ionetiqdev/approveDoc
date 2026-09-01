# deploy.bat

The single deployment command for approveDoc.

## Usage

```cmd
deploy dev      :: Deploy to ionetiq.dev/approvedoc/dev/
deploy main     :: Deploy to ionetiq.dev/approvedoc/ (production)
```

## What it does

1. Finds `approvedoc_DDMMYYYY_HHmm.zip` in `C:\Users\{user}\My Drive\Downloads`
2. Extracts it to the IIS working directory
3. Regenerates cache-busting strings on all HTML/JS files
4. Writes `version.js` with `APP_PUBLISHED = 'DD/MM/YYYY HH:MM'` (UK time)
5. Switches to the target git branch
6. Commits everything with the content of `CHANGES.txt` as the message
7. Pushes to GitHub

## Three-file lockstep rule

Every time you produce a new zip, update these three files **before** zipping:

| File | Format | Example |
|---|---|---|
| Zip filename | `approvedoc_DDMMYYYY_HHmm.zip` | `approvedoc_29072026_1552.zip` |
| `BUILD_TIMESTAMP.txt` | `DD/MM/YYYY HH:MM` | `29/07/2026 15:52` |
| `CHANGES.txt` | Free text (used as git commit message) | `Fix: acknowledge page layout` |

!!! warning "Year format"
    The year is **4 digits** (`2026`), not 2. This is verified from the `deploy.bat` source.

## pdfjs/ exclusion

`assets/pdfjs/` is **always excluded** from deployment zips. It is managed separately on the server. Zip command:

```cmd
zip -r approvedoc_DDMMYYYY_HHmm.zip . -x ".git/*" "node_modules/*" "Backup/*" "*.zip" "project.conf" "assets/pdfjs/*"
```

## Git branch conflicts

If `deploy dev` fails with "Your local changes would be overwritten by checkout", commit or stash local changes first:

```cmd
git add -A
git commit -m "WIP: local changes"
deploy dev
```
