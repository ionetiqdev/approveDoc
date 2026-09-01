# Promote dev → main

How a new build goes from a zip Claude hands you, through dev testing,
to live on production.

---

## 1. Deploy a new zip to dev

Claude names every build zip `template_DDMMYYYY_HHmm.zip`
(UK date/time) and it lands in your Downloads folder when you save it.
Then, from this project's working directory:

```
deploy.bat dev
```

`deploy.bat` finds the newest `template_*.zip` in Downloads
automatically (no need to tell it which one), extracts it on top of
this working directory, moves the zip into `.\Backup\` (kept
indefinitely - clear it out by hand if it grows large), regenerates
`version.js` with that build's published timestamp, commits, and
pushes to the `dev` branch. GitHub Actions deploys it to
`public_html/template/dev/`.

## 2. Test on dev

If something's wrong, tell Claude, get a new zip, run `deploy.bat dev`
again. Repeat as many times as needed - dev is just "whatever the
latest zip was," there's nothing special to reset between attempts.

## 3. Promote dev → main

Once dev is good, do NOT run `deploy.bat main`. Instead, make main an
exact mirror of dev:

```
git checkout main
git reset --hard dev
git push origin main --force-with-lease
```

This pushes the exact build already proven out on dev - same files,
same `version.js` timestamp - to the `main` branch. GitHub Actions
deploys that to `public_html/template/` (production root).

---

## Why not just run deploy.bat main with the same zip?

`deploy.bat` regenerates `version.js` with a fresh "right now"
timestamp every time it runs. If you ran it again for main, production
would show a different Published time than what you actually tested
on dev - even though the code is identical. Promoting via
`git reset --hard dev` instead keeps that traceability: the timestamp
on production always tells you exactly which dev-tested build is live.

## Why --force-with-lease and not a plain merge?

main and dev tend to diverge in their own commit history (every
`deploy.bat` run is its own commit, on top of whatever was there
before). A plain `git merge dev` tries to reconcile two independent
histories and can throw conflicts - typically in `version.js` and any
file changed on both branches - even when you don't actually want a
true merge, you just want main to become dev.

`git reset --hard dev` skips that entirely: it moves main's pointer to
the same commit as dev, full stop. `--force-with-lease` (rather than
plain `--force`) still protects you if someone else pushed to main
since you last fetched - it refuses rather than silently overwriting
work it hasn't seen.

This assumes dev is always the source of truth and nothing is ever
committed directly to main outside this promote step. If that ever
stops being true, this process needs revisiting.

## A note on the working directory and IIS

This project's working directory is also served locally by IIS
(`C:\inetpub\wwwroot\Template` or equivalent for other projects).
That's available if you ever need it, but it is NOT the normal way
this gets tested - day-to-day testing happens on the real hosted
`dev` folder (`public_html/template/dev/`) after running
`deploy.bat dev` and letting GitHub Actions publish it, same as
described above. Reach for local IIS only in an unusual situation
(offline work, debugging something that's hard to diagnose against
the live dev site) - be aware that `deploy.bat` extracting a new
build into the working directory will make IIS start serving that
new build immediately, before it's been pushed to GitHub or
deployed anywhere else.

## A note on deploy.bat's overwrite behaviour

`deploy.bat` extracts the new zip ON TOP of the working directory - it
does not delete files first. If a build ever genuinely removes a file
(a page gets deleted, something gets renamed), the old file will
linger in your working directory and could still get committed/pushed
even though it's no longer part of the real build. If you know a
build removed something, delete it from the working directory by hand
before running `deploy.bat`.
