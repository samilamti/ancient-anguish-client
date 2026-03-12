@echo off
REM Run the app on Windows desktop
REM Usage: scripts\run.cmd [--release]
setlocal

if "%~1"=="--release" (
    echo === Running Windows (release) ===
    flutter run -d windows --release
) else (
    echo === Running Windows (debug) ===
    flutter run -d windows
)
