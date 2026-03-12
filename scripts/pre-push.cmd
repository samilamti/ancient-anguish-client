@echo off
REM Pre-push quality gate: sensitive files check + analysis + tests
REM Usage: scripts\pre-push.cmd
setlocal enabledelayedexpansion

set WARNINGS=0

echo === Checking for Sensitive Files ===

REM Check if key files are staged
git diff --cached --name-only 2>nul | findstr /R "^key$ ^key\.pub$" >nul 2>&1
if not errorlevel 1 (
    echo WARNING: SSH key files (key/key.pub) are staged for commit!
    echo   Consider adding them to .gitignore
    set /a WARNINGS+=1
)

REM Check if key files exist and aren't in .gitignore
for %%f in (key key.pub) do (
    if exist "%%f" (
        git check-ignore -q "%%f" 2>nul
        if errorlevel 1 (
            echo WARNING: %%f exists but is NOT in .gitignore
            set /a WARNINGS+=1
        )
    )
)

REM Check for .env files
git ls-files --others --exclude-standard 2>nul | findstr /R "\.env" >nul 2>&1
if not errorlevel 1 (
    echo WARNING: Untracked .env files found
    set /a WARNINGS+=1
)

echo.
echo === Checking Uncommitted Changes ===
for /f "delims=" %%i in ('git diff --stat 2^>nul') do (
    echo NOTE: You have unstaged changes. Tests will run against the working tree.
    git diff --stat 2>nul
    echo.
    goto :run_checks
)
:run_checks

echo === Static Analysis ===
flutter analyze --fatal-infos
if errorlevel 1 goto :fail

echo.
echo === Running Tests ===
flutter test
if errorlevel 1 goto :fail

echo.
if !WARNINGS! gtr 0 (
    echo === All checks passed with !WARNINGS! warning(s) ===
) else (
    echo === All checks passed. Safe to push. ===
)
exit /b 0

:fail
echo.
echo === Pre-push checks FAILED ===
exit /b 1
