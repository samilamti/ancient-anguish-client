@echo off
REM Clean build artifacts and restore dependencies
REM Usage: scripts\clean.cmd
setlocal

echo === Cleaning Build Artifacts ===
flutter clean
if errorlevel 1 goto :fail

echo.
echo === Restoring Dependencies ===
flutter pub get
if errorlevel 1 goto :fail

echo.
echo === Clean complete ===
exit /b 0

:fail
echo.
echo === Clean FAILED ===
exit /b 1
