@echo off
setlocal ENABLEDELAYEDEXPANSION

:: ============================================================
:: deploy.bat
::
:: Usage: deploy.bat <branch-name>
::   e.g. deploy.bat dev
::        deploy.bat main      (only for the FIRST-ever deploy of
::                              a brand new project - after that,
::                              promote dev to main using
::                              PROMOTE.md's git reset --hard
::                              approach instead, never run this
::                              script against main again)
::
:: First run for a new project: if project.conf doesn't exist or
:: is missing values, this will ask you for them interactively and
:: save your answers into project.conf, so you're only asked once.
:: Secrets (FTP password, Supabase keys) are NEVER asked here -
:: those go into GitHub Actions secrets, see docs/NEW-PROJECT.md.
::
:: What this does, in order:
::   1. Loads project.conf, prompting for and saving anything
::      missing.
::   2. Finds the newest {PROJECT_CODE}_DDMMYYYY_HHmm.zip in your
::      downloads folder.
::   3. Extracts it ON TOP of this working directory (overwrite
::      in place - files removed from the new build are NOT
::      deleted automatically, see PROMOTE.md).
::   4. Moves that zip into .\Backup\ (gitignored, never pushed -
::      kept indefinitely, clear it out by hand if it grows large).
::   5. Regenerates the cache-busting query string across every
::      .html file and writes a fresh version.js.
::   6. Commits using CHANGES.txt as the message, then pushes to
::      the branch you named.
:: ============================================================

if "%~1"=="" (
  echo Usage: deploy.bat ^<branch-name^>
  echo   e.g. deploy.bat dev
  exit /b 1
)
set BRANCH=%~1

call :LoadOrPromptConfig
if errorlevel 1 exit /b 1

if "%DOWNLOADS_DIR%"=="" set DOWNLOADS_DIR=%USERPROFILE%\Downloads
if "%WORKING_DIR%"=="" set WORKING_DIR=%CD%

cd /d "%WORKING_DIR%"
if errorlevel 1 (
  echo ERROR: Could not switch to working directory: %WORKING_DIR%
  exit /b 1
)

:: Sanity check: does this folder's git remote actually match the
:: GITHUB_REPO_URL configured for this project? Catches the case
:: where WORKING_DIR in project.conf points at the wrong project
:: entirely (e.g. still set to the template clone, or another
:: project's folder) - everything downstream would otherwise run
:: "successfully" against the wrong repo with no error at all.
if not "%GITHUB_REPO_URL%"=="" (
  for /f "delims=" %%R in ('git config --get remote.origin.url 2^>nul') do set ACTUAL_REMOTE=%%R
  if not "!ACTUAL_REMOTE!"=="%GITHUB_REPO_URL%" (
    echo ERROR: WORKING_DIR's git remote does not match project.conf.
    echo   WORKING_DIR:        %WORKING_DIR%
    echo   Remote here is:     !ACTUAL_REMOTE!
    echo   project.conf expects: %GITHUB_REPO_URL%
    echo This usually means WORKING_DIR in project.conf points at the
    echo wrong project's folder. Fix WORKING_DIR and try again.
    exit /b 1
  )
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
  echo Expected a filename like %PROJECT_CODE%_25062026_1501.zip
  exit /b 1
)
echo Using: %LATEST_ZIP%

:: ── Step 2: extract on top of the working directory ──
echo Extracting...
powershell -NoProfile -Command "Expand-Archive -Path '%LATEST_ZIP%' -DestinationPath '%CD%' -Force"
if errorlevel 1 (
  echo ERROR: Extraction failed.
  exit /b 1
)

:: ── Step 3: move the zip into Backup\ (gitignored) ──
if not exist "Backup" mkdir "Backup"
move /Y "%LATEST_ZIP%" "Backup\" >nul
if errorlevel 1 (
  echo WARNING: Could not move the zip into Backup\ - it may still be
  echo open in another program (zip viewer, antivirus scan, sync
  echo client). Extraction already happened, so this is not fatal -
  echo but the zip wasn't archived this run. Move it manually later
  echo if you want a record of it.
) else (
  echo Moved zip to .\Backup\
)

:: ── Step 4: regenerate cache-busting strings + version.js ──
echo Regenerating cache-busting strings and version.js...

:: The published timestamp is the moment this BUILD was produced, not
:: the moment deploy.bat happens to run (which could be much later) -
:: read it from BUILD_TIMESTAMP.txt, which is part of the zip itself.
if not exist "BUILD_TIMESTAMP.txt" (
  echo ERROR: BUILD_TIMESTAMP.txt not found in this build - cannot determine published time.
  exit /b 1
)
set /p PUBLISHED_TIMESTAMP=<"BUILD_TIMESTAMP.txt"

if "%PUBLISHED_TIMESTAMP%"=="" (
  echo ERROR: BUILD_TIMESTAMP.txt was empty.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cache-bust.ps1" -PublishedTimestamp "%PUBLISHED_TIMESTAMP%"

if errorlevel 1 (
  echo ERROR: Cache-bust/version.js regeneration failed.
  exit /b 1
)

:: Verify version.js actually contains the timestamp we just asked
:: for - belt-and-braces, since errorlevel alone has previously failed
:: to catch a silent write failure here.
findstr /C:"%PUBLISHED_TIMESTAMP%" "assets\js\version.js" >nul
if errorlevel 1 (
  echo ERROR: version.js does not contain the expected timestamp after regeneration.
  echo Expected to find: %PUBLISHED_TIMESTAMP%
  echo Check assets\js\version.js manually - the write may have silently failed.
  exit /b 1
)

del "BUILD_TIMESTAMP.txt" 2>nul

:: ── Step 5: switch to the right branch, commit, push ──

:: Find out what branch we're actually on right now
for /f "delims=" %%C in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%C

if not "%CURRENT_BRANCH%"=="%BRANCH%" (
  git rev-parse --verify %BRANCH% >nul 2>&1
  if errorlevel 1 (
    echo Branch "%BRANCH%" doesn't exist yet locally - creating it from the current branch.
    git checkout -b %BRANCH%
  ) else (
    git checkout %BRANCH%
  )
  if errorlevel 1 (
    echo ERROR: Could not switch to branch "%BRANCH%".
    exit /b 1
  )
)

if not exist "CHANGES.txt" (
  echo WARNING: CHANGES.txt not found - using a generic commit message.
  echo Deploy build > CHANGES.txt
)

git add -A
for /f "usebackq delims=" %%M in ("CHANGES.txt") do set COMMIT_MSG=%%M
git commit -m "!COMMIT_MSG!"
if errorlevel 1 (
  echo ERROR: git commit failed - is there anything to commit?
  exit /b 1
)

git push -u origin %BRANCH%
if errorlevel 1 (
  echo ERROR: git push failed.
  exit /b 1
)

echo.
echo Done. Pushed to %BRANCH% - GitHub Actions will build supabase-client.js
echo from your repo secrets and deploy it shortly.
echo.
echo Published version: %APP_NAME% - %PUBLISHED_TIMESTAMP%
exit /b 0


:: ============================================================
:: Loads project.conf if present. For any non-secret value that's
:: blank or missing, prompts for it and writes the whole file back
:: out (preserving REM comments is not attempted - a fresh minimal
:: file is written instead, since batch has no clean way to do an
:: in-place key update while keeping arbitrary comment formatting).
:: Never asks about FTP_PASSWORD, FTP_USERNAME, SUPABASE_URL,
:: SUPABASE_ANON_KEY, or any other secret - those are GitHub
:: Actions secrets only, reminder printed instead.
:: ============================================================
:LoadOrPromptConfig
set APP_NAME=
set PROJECT_CODE=
set COMPANY_NAME=
set DOWNLOADS_DIR=
set WORKING_DIR=
set GITHUB_REPO_URL=
set SUPABASE_PROJECT_NAME=

if exist "project.conf" (
  for /f "usebackq tokens=1,* delims==" %%A in ("project.conf") do (
    if "%%A"=="APP_NAME"               set "APP_NAME=%%B"
    if "%%A"=="PROJECT_CODE"           set "PROJECT_CODE=%%B"
    if "%%A"=="COMPANY_NAME"           set "COMPANY_NAME=%%B"
    if "%%A"=="DOWNLOADS_DIR"          set "DOWNLOADS_DIR=%%B"
    if "%%A"=="WORKING_DIR"            set "WORKING_DIR=%%B"
    if "%%A"=="GITHUB_REPO_URL"        set "GITHUB_REPO_URL=%%B"
    if "%%A"=="SUPABASE_PROJECT_NAME"  set "SUPABASE_PROJECT_NAME=%%B"
  )
)

set NEEDS_SAVE=0
if "%APP_NAME%"=="" (
  set /p APP_NAME="App name (e.g. Acme Risk Register): "
  set NEEDS_SAVE=1
)
if "%PROJECT_CODE%"=="" (
  set /p PROJECT_CODE="Project short code, lowercase no spaces (e.g. acme): "
  set NEEDS_SAVE=1
)
if "%COMPANY_NAME%"=="" (
  set /p COMPANY_NAME="Company name for page footers (e.g. ionetiq): "
  set NEEDS_SAVE=1
)
if "%GITHUB_REPO_URL%"=="" (
  set /p GITHUB_REPO_URL="GitHub repo URL (e.g. https://github.com/you/repo.git): "
  set NEEDS_SAVE=1
)
if "%DOWNLOADS_DIR%"=="" (
  echo.
  echo Where do your build zips from Claude land? Leave blank for the
  echo default Windows Downloads folder, or type a full path if you use
  echo something else ^(e.g. a Google Drive-synced folder^).
  set /p DOWNLOADS_DIR="Downloads folder [default: %%USERPROFILE%%\Downloads]: "
  set NEEDS_SAVE=1
)
if "%WORKING_DIR%"=="" (
  echo.
  echo Where does this project actually live on disk - the folder
  echo deploy.bat should treat as the project root? Leave blank to use
  echo wherever deploy.bat is currently being run from.
  set /p WORKING_DIR="Working directory [default: current folder]: "
  set NEEDS_SAVE=1
)
if "%SUPABASE_PROJECT_NAME%"=="" (
  set /p SUPABASE_PROJECT_NAME="Supabase project name, for reference only (e.g. acme-risk): "
  set NEEDS_SAVE=1
)

if "%NEEDS_SAVE%"=="1" (
  echo.
  echo Saving these to project.conf so you won't be asked again.
  (
    echo REM project.conf - see project.conf.example for full field docs
    echo APP_NAME=%APP_NAME%
    echo PROJECT_CODE=%PROJECT_CODE%
    echo COMPANY_NAME=%COMPANY_NAME%
    echo DOWNLOADS_DIR=%DOWNLOADS_DIR%
    echo WORKING_DIR=%WORKING_DIR%
    echo GITHUB_REPO_URL=%GITHUB_REPO_URL%
    echo SUPABASE_PROJECT_NAME=%SUPABASE_PROJECT_NAME%
  ) > project.conf
  echo.
  echo REMINDER: this project also needs these set as GitHub Actions
  echo repo secrets ^(Settings ^> Secrets and variables ^> Actions^) -
  echo deploy.bat never asks for these and never stores them locally:
  echo   SUPABASE_URL, SUPABASE_ANON_KEY, FTP_HOST, FTP_USERNAME,
  echo   FTP_PASSWORD, and optionally SLACK_WEBHOOK_URL.
  echo See docs/NEW-PROJECT.md for exact steps.
  echo.
)

if "%PROJECT_CODE%"=="" (
  echo ERROR: PROJECT_CODE is required.
  exit /b 1
)
exit /b 0


:: ============================================================
:: Parses a zip's base filename (no extension) of the form
:: {code}_DDMMYYYY_HHmm into a single comparable integer
:: (YYYYMMDDHHmm, so plain integer comparison sorts correctly
:: across month/year boundaries even though the filename itself
:: stays in DDMMYYYY order for human readability).
:: %1 = base filename (e.g. "acme_25062026_1501")
:: %2 = variable name to receive the result
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
set /a RESULT=(%YYYY%*100000000) + (%MM%*1000000) + (%DD%*10000) + %TIMEPART%
endlocal & set "%~2=%RESULT%"
exit /b
