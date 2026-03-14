@echo off
REM Tag a release version after running validation
REM Usage: scripts\tag-release.cmd <version>
REM Example: scripts\tag-release.cmd v1.0.0
REM Note: Tags are immutable on this repo. Double-check before tagging.
setlocal

if "%~1"=="" (
    echo Usage: scripts\tag-release.cmd ^<version^>
    echo Example: scripts\tag-release.cmd v1.0.0
    exit /b 1
)

set VERSION=%~1

REM Ensure version starts with v
echo %VERSION% | findstr /R "^v" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Version must start with 'v' (e.g., v1.0.0)
    exit /b 1
)

REM Check for uncommitted changes
git diff --quiet 2>nul
if errorlevel 1 (
    echo ERROR: You have uncommitted changes. Commit or stash before tagging.
    git diff --stat
    exit /b 1
)
git diff --cached --quiet 2>nul
if errorlevel 1 (
    echo ERROR: You have staged changes. Commit or stash before tagging.
    exit /b 1
)

REM Check tag doesn't already exist
git rev-parse "%VERSION%" >nul 2>&1
if not errorlevel 1 (
    echo ERROR: Tag %VERSION% already exists. Releases are immutable - bump the version.
    exit /b 1
)

echo === Running Validation ===
call scripts\validate.cmd
if errorlevel 1 (
    echo.
    echo === Validation failed. Tag not created. ===
    exit /b 1
)

echo.
echo === Creating Tag %VERSION% ===
git tag %VERSION%
if errorlevel 1 goto :fail

echo.
echo === Pushing Tag ===
git push origin %VERSION%
if errorlevel 1 goto :fail

echo.
echo === Release %VERSION% tagged and pushed ===
echo GitHub Actions will build release artifacts automatically.
exit /b 0

:fail
echo.
echo === Tag release FAILED ===
exit /b 1
