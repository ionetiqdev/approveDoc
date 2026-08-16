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
::   3. Extracts it ON TOP of this working directory using 7-Zip
::      (overwrite in place - files removed from the new build are
::      NOT deleted automatically, see PROMOTE.md).
::   4. Moves that zip into .\Backup\ (gitignored, never pushed -
::      kept indefinitely, clear it out by hand if it grows large).
::   5. Regenerates the cache-busting query string across every
::      .html file and writes a fresh version.js (via cache-bust.ps1,
::      a standalone file - not built inline as a quoted cmd.exe
::      string, which is fragile to escape correctly).
::   6. Commits using CHANGES.txt as the message, then pushes to
::      the branch you named.
::
:: Extraction uses 7-Zip (7z.exe) rather than PowerShell's
:: Expand-Archive. Expand-Archive proved unreliable when called from
:: inside a batch script via -Command with variable substitution -
:: it could fail with cryptic cmd.exe parsing errors ("X was
:: unexpected at this time") that had nothing to do with the zip or
:: destination themselves, and were never fully root-caused despite
:: extensive debugging. 7-Zip's command-line interface takes plain
:: positional arguments with no equivalent quoting fragility, and is
:: the same approach already proven reliable on other ionetiq
:: projects (e.g. RISK). Requires 7-Zip installed at the path below -
:: adjust ZIP_EXE if installed elsewhere.
:: ============================================================

set "ZIP_EXE=C:\Program Files\7-Zip\7z.exe"

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

if not exist "%ZIP_EXE%" (
  echo ERROR: 7-Zip not found at %ZIP_EXE%
  echo Install 7-Zip from https://www.7-zip.org/, or edit the
  echo ZIP_EXE path near the top of this script if it's installed
  echo somewhere else.
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
  set "FNAME=%%~nF"
  for /f "tokens=2,3 delims=_" %%a in ("%%~nF") do (
    set "DP=%%a"
    set "TP=%%b"
  )
  set /a EPOCH=(!DP:~4,4!*100000000) + (!DP:~2,2!*1000000) + (!DP:~0,2!*10000) + !TP!
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
set MOVE_RESULT=%errorlevel%
if "%MOVE_RESULT%"=="0" (
  echo Moved zip to Backup folder
) else (
  echo WARNING: Could not move the zip into the Backup folder - it
  echo may still be open in another program. Extraction already
  echo happened, so this is not fatal, but the zip was not archived
  echo this run. Move it manually later if you want a record of it.
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

:: ── Step 4b: select Supabase credentials based on branch ──
if "%BRANCH%"=="main" (
  set "SUPABASE_URL=%SUPABASE_URL_MAIN%"
  set "SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY_MAIN%"
) else (
  set "SUPABASE_URL=%SUPABASE_URL_DEV%"
  set "SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY_DEV%"
)

:: Find out what branch we're actually on right now
for /f "delims=" %%C in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set CURRENT_BRANCH=%%C

if not "%CURRENT_BRANCH%"=="%BRANCH%" (
  :: Stash any local changes (including the just-extracted files) so we can switch branches cleanly
  git stash push -m "pre-deploy-switch" --include-untracked >nul 2>&1

  git rev-parse --verify %BRANCH% >nul 2>&1
  if errorlevel 1 (
    echo Branch "%BRANCH%" doesn't exist yet locally - creating it from the current branch.
    git checkout -b %BRANCH%
  ) else (
    git checkout %BRANCH%
  )
  if errorlevel 1 (
    echo ERROR: Could not switch to branch "%BRANCH%".
    git stash pop >nul 2>&1
    exit /b 1
  )

  :: Re-apply the extracted files on top of the target branch
  git stash pop >nul 2>&1
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
echo Done. Pushed to %BRANCH%.

:: ── Step 6: substitute Supabase credentials on the server ──
:: Do this AFTER git push so the placeholder version stays in git
:: but the live server file gets the real credentials.
if not "%SUPABASE_URL%"=="" (
  echo Substituting Supabase credentials on server...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "(Get-Content 'assets\js\supabase-client.js') -replace '\{\{SUPABASE_URL\}\}', '%SUPABASE_URL%' -replace '\{\{SUPABASE_ANON_KEY\}\}', '%SUPABASE_ANON_KEY%' | Set-Content 'assets\js\supabase-client.js'"
  echo Credentials substituted. Server is live.
) else (
  echo WARNING: SUPABASE_URL not found in project.conf - server credentials NOT substituted.
  echo          Add SUPABASE_URL_MAIN and SUPABASE_URL_DEV to project.conf
)

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
set SUPABASE_URL_MAIN=
set SUPABASE_ANON_KEY_MAIN=
set SUPABASE_URL_DEV=
set SUPABASE_ANON_KEY_DEV=

if exist "project.conf" (
  for /f "usebackq tokens=1,* delims==" %%A in ("project.conf") do (
    if "%%A"=="APP_NAME"               set "APP_NAME=%%B"
    if "%%A"=="PROJECT_CODE"           set "PROJECT_CODE=%%B"
    if "%%A"=="COMPANY_NAME"           set "COMPANY_NAME=%%B"
    if "%%A"=="DOWNLOADS_DIR"          set "DOWNLOADS_DIR=%%B"
    if "%%A"=="WORKING_DIR"            set "WORKING_DIR=%%B"
    if "%%A"=="GITHUB_REPO_URL"        set "GITHUB_REPO_URL=%%B"
    if "%%A"=="SUPABASE_PROJECT_NAME"  set "SUPABASE_PROJECT_NAME=%%B"
    if "%%A"=="SUPABASE_URL_MAIN"      set "SUPABASE_URL_MAIN=%%B"
    if "%%A"=="SUPABASE_ANON_KEY_MAIN" set "SUPABASE_ANON_KEY_MAIN=%%B"
    if "%%A"=="SUPABASE_URL_DEV"       set "SUPABASE_URL_DEV=%%B"
    if "%%A"=="SUPABASE_ANON_KEY_DEV"  set "SUPABASE_ANON_KEY_DEV=%%B"
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

