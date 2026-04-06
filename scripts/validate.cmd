@echo off
REM Validate: static analysis + tests
REM Usage: scripts\validate.cmd
setlocal

echo === Static Analysis ===
flutter analyze --fatal-infos
if errorlevel 1 goto :fail

echo.
echo === Running Tests ===
flutter test
if errorlevel 1 goto :fail

echo.
echo === All checks passed ===
exit /b 0

:fail
echo.
echo === Validation FAILED ===
exit /b 1
