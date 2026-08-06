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
:: Same parsing logic as deploy.bat - see that file for comments.
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
