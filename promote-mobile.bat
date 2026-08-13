@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ============================================================
:: promote-mobile.bat
::
:: Usage: promote-mobile.bat
::
:: Safely merges feature/mobile-capacitor -> main, then immediately
:: merges main back into feature/mobile-capacitor, so the two
:: branches never drift apart in only one direction. This is the
:: fix for the exact failure that broke the Android project earlier:
:: main got a commit that feature/mobile-capacitor never received
:: back, so checking that branch back out reverted a working
:: android/ folder to an older, broken one.
::
:: Ends back on feature/mobile-capacitor - the branch you normally
:: work on day to day.
::
:: What this does, in order:
::   1. Refuses to run if you have uncommitted changes (commit or
::      stash first).
::   2. Checkout feature/mobile-capacitor, pull latest.
::   3. Checkout main, pull latest.
::   4. Merge feature/mobile-capacitor into main, push.
::   5. Checkout feature/mobile-capacitor again.
::   6. Merge main back into feature/mobile-capacitor, push.
::      (this is the step that was missing before)
:: ============================================================

set "MOBILE_BRANCH=feature/mobile-capacitor"

if exist "project.conf" (
  for /f "usebackq tokens=1,* delims==" %%A in ("project.conf") do (
    if "%%A"=="WORKING_DIR" set "WORKING_DIR=%%B"
  )
)
if "%WORKING_DIR%"=="" set WORKING_DIR=%CD%

cd /d "%WORKING_DIR%"
if errorlevel 1 (
  echo ERROR: Could not switch to working directory: %WORKING_DIR%
  exit /b 1
)

:: ── Step 1: refuse to run with uncommitted changes ──
:: Checks the status file's SIZE rather than reading its content into a
:: variable - git status can return many lines, and cramming multi-line
:: output into a variable breaks any command that then uses it.
git status --porcelain > "%TEMP%\gitstatus.txt" 2>nul
for %%F in ("%TEMP%\gitstatus.txt") do set GITSTATUS_SIZE=%%~zF
del "%TEMP%\gitstatus.txt" 2>nul

if not "%GITSTATUS_SIZE%"=="0" (
  echo ERROR: You have uncommitted changes. Commit or stash them first,
  echo then re-run this script.
  git status
  exit /b 1
)

:: ── Step 2: update the mobile branch ──
echo Updating %MOBILE_BRANCH%...
git checkout %MOBILE_BRANCH%
if errorlevel 1 (
  echo ERROR: Could not switch to %MOBILE_BRANCH%.
  exit /b 1
)
git pull
if errorlevel 1 (
  echo ERROR: Could not pull %MOBILE_BRANCH%.
  exit /b 1
)

:: ── Step 3: update main ──
echo Updating main...
git checkout main
if errorlevel 1 (
  echo ERROR: Could not switch to main.
  exit /b 1
)
git pull
if errorlevel 1 (
  echo ERROR: Could not pull main.
  exit /b 1
)

:: ── Step 4: merge mobile branch into main ──
echo Merging %MOBILE_BRANCH% into main...
git merge %MOBILE_BRANCH% --no-edit
if errorlevel 1 (
  echo ERROR: Merge into main failed - likely a real conflict. Resolve
  echo it by hand, then finish manually: git push, then re-run this
  echo script to complete the sync back onto %MOBILE_BRANCH%.
  exit /b 1
)
git push
if errorlevel 1 (
  echo ERROR: Could not push main.
  exit /b 1
)

:: ── Step 5/6: merge main back into the mobile branch ──
:: This is the step that was missing before - without it, main moves
:: ahead of the mobile branch every time you promote, and the next
:: `git checkout feature/mobile-capacitor` silently reverts anything
:: that only landed on main (which is what broke the android/ folder).
echo Syncing main back into %MOBILE_BRANCH%...
git checkout %MOBILE_BRANCH%
if errorlevel 1 (
  echo ERROR: Could not switch back to %MOBILE_BRANCH%.
  exit /b 1
)
git merge main --no-edit
if errorlevel 1 (
  echo ERROR: Could not merge main back into %MOBILE_BRANCH% - likely a
  echo real conflict. Resolve it by hand, then: git push.
  exit /b 1
)
git push
if errorlevel 1 (
  echo ERROR: Could not push %MOBILE_BRANCH%.
  exit /b 1
)

echo.
echo Done. main and %MOBILE_BRANCH% are now in sync, both pushed.
echo You're on %MOBILE_BRANCH%, ready to keep working.
exit /b 0
