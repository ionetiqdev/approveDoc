@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ============================================================
:: deploy-mobile.bat
::
:: Usage: deploy-mobile.bat
::
:: Companion to deploy.bat, for the mobile/ scaffold while it's
:: still being built out interactively with Claude. Unlike
:: deploy.bat, this does NOT commit or push - mobile changes are
:: reviewed and committed by hand while still under active
:: development. Revisit this once mobile has its own steady
:: build/release rhythm.
::
:: What this does, in order:
::   0. Checks the mobile branch is up to date with main (fetches +
::      merges origin/main in) before touching anything - this is the
::      fix for the specific failure where checking out the mobile
::      branch reverted a working android/ project back to an older,
::      broken state because a merge had only landed on main.
::      Skipped if you have uncommitted changes, to avoid overwriting
::      anything.
::   1. Finds the newest approvedoc-mobile_DDMMYYYY_HHmm.zip in
::      your Downloads folder (or DOWNLOADS_DIR from project.conf,
::      same as deploy.bat).
::   2. Extracts it ON TOP of this working directory using 7-Zip
::      (overwrite in place - same caveat as deploy.bat: if a
::      build genuinely removes a file, the old one lingers until
::      deleted by hand).
::   3. Moves that zip into .\Backup\ (already gitignored).
::
:: Requires 7-Zip - see deploy.bat's header for why 7-Zip rather
:: than PowerShell's Expand-Archive.
:: ============================================================

set "ZIP_EXE=C:\Program Files\7-Zip\7z.exe"
set "PROJECT_CODE=approvedoc-mobile"
set "MOBILE_BRANCH=feature/mobile-capacitor"

if exist "project.conf" (
  for /f "usebackq tokens=1,* delims==" %%A in ("project.conf") do (
    if "%%A"=="DOWNLOADS_DIR" set "DOWNLOADS_DIR=%%B"
    if "%%A"=="WORKING_DIR"   set "WORKING_DIR=%%B"
  )
)
if "%DOWNLOADS_DIR%"=="" set DOWNLOADS_DIR=%USERPROFILE%\Downloads
if "%WORKING_DIR%"=="" set WORKING_DIR=%CD%

cd /d "%WORKING_DIR%"
if errorlevel 1 (
  echo ERROR: Could not switch to working directory: %WORKING_DIR%
  exit /b 1
)

:: ── Step 0: make sure the mobile branch isn't behind main ──
:: This is what actually broke the Android project earlier - main had a
:: commit (with a working android/ folder) that never got merged back
:: into feature/mobile-capacitor, so checking out that branch reverted
:: it to an older, broken state. This step prevents that recurring by
:: catching the branch up BEFORE any new zip is extracted on top of it.
echo Checking mobile branch is up to date with main...

for /f "delims=" %%C in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%C

git status --porcelain > "%TEMP%\gitstatus.txt" 2>nul
for %%F in ("%TEMP%\gitstatus.txt") do set GITSTATUS_SIZE=%%~zF
del "%TEMP%\gitstatus.txt" 2>nul

if not "%GITSTATUS_SIZE%"=="0" (
  echo WARNING: You have uncommitted changes - skipping the main-sync check
  echo this run so nothing gets overwritten. Commit or stash your changes,
  echo then re-run this script to get the sync check.
  goto :AfterSync
)

git rev-parse --verify %MOBILE_BRANCH% >nul 2>&1
if errorlevel 1 (
  echo WARNING: Branch "%MOBILE_BRANCH%" doesn't exist locally yet - skipping sync check.
  goto :AfterSync
)

if not "%CURRENT_BRANCH%"=="%MOBILE_BRANCH%" (
  git checkout %MOBILE_BRANCH%
  if errorlevel 1 (
    echo ERROR: Could not switch to %MOBILE_BRANCH%.
    exit /b 1
  )
)

git fetch origin >nul 2>&1
git merge origin/main --no-edit
if errorlevel 1 (
  echo WARNING: Could not auto-merge main into %MOBILE_BRANCH% - there may
  echo be a real conflict. Resolve this by hand before continuing, or ask
  echo Claude for help. Continuing with extraction anyway.
) else (
  echo Branch is up to date with main.
)

:AfterSync

if not exist "%ZIP_EXE%" (
  echo ERROR: 7-Zip not found at %ZIP_EXE%
  echo Install 7-Zip from https://www.7-zip.org/, or edit ZIP_EXE
  echo near the top of this script if it's installed elsewhere.
  exit /b 1
)

:: ── Step 1: find the newest matching zip ──
echo Looking for %PROJECT_CODE%_*.zip in %DOWNLOADS_DIR% ...

set LATEST_ZIP=
set LATEST_EPOCH=-1
for %%F in ("%DOWNLOADS_DIR%\%PROJECT_CODE%_*.zip") do (
  call :ParseZipTimestamp "%%~nF" EPOCH
  if !EPOCH! GTR !LATEST_EPOCH! (
    set LATEST_EPOCH=!EPOCH!
    set LATEST_ZIP=%%~fF
  )
)

if "%LATEST_ZIP%"=="" (
  echo ERROR: No %PROJECT_CODE%_*.zip found in %DOWNLOADS_DIR%.
  echo Expected a filename like %PROJECT_CODE%_06082026_1030.zip
  exit /b 1
)
echo Using: %LATEST_ZIP%

:: ── Step 2: extract on top of the working directory (7-Zip) ──
echo Extracting...
"%ZIP_EXE%" x "%LATEST_ZIP%" -o"%WORKING_DIR%" -aoa -y >nul
if errorlevel 1 (
  echo ERROR: Extraction failed.
  exit /b 1
)
echo Extraction complete.

:: ── Step 3: move the zip into the Backup folder (gitignored) ──
if not exist "Backup" mkdir "Backup"
move /Y "%LATEST_ZIP%" "Backup\" >nul
if errorlevel 1 (
  echo WARNING: Could not move the zip into the Backup folder - it
  echo may still be open in another program. Extraction already
  echo happened, so this is not fatal.
) else (
  echo Moved zip to Backup folder
)

echo.
echo Done. mobile\ updated from %LATEST_ZIP%.
echo Review the changes, then commit by hand when ready:
echo   git add mobile
echo   git commit -m "describe what changed"
echo   git push
exit /b 0


:: ============================================================
:: Same parsing logic as deploy.bat, but with a fix: cmd's SET /A
:: treats leading-zero numbers as octal, so "08" (August, or any
:: HH:mm before 10am) throws "Invalid number" because 8/9 aren't
:: valid octal digits. The "1%X%-100" style trick below forces
:: decimal interpretation by making the string never start with 0.
:: deploy.bat has this same latent bug in its own copy of this
:: function - worth patching there too.
:: ============================================================
:ParseZipTimestamp
setlocal
set "NAME=%~1"
for /f "tokens=2,3 delims=_" %%a in ("%NAME%") do (
  set "DATEPART=%%a"
  set "TIMEPART=%%b"
)
if "%DATEPART%"=="" (endlocal & set "%~2=-1" & exit /b)
if "%TIMEPART%"=="" (endlocal & set "%~2=-1" & exit /b)
set "DD=%DATEPART:~0,2%"
set "MM=%DATEPART:~2,2%"
set "YYYY=%DATEPART:~4,4%"
set /a "DD=1%DD%-100"
set /a "MM=1%MM%-100"
set /a "TIMEPART=1%TIMEPART%-10000"
set /a RESULT=(%YYYY%*100000000) + (%MM%*1000000) + (%DD%*10000) + %TIMEPART%
endlocal & set "%~2=%RESULT%"
exit /b
