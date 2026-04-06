@echo off
REM Build the Windows desktop app (debug or release)
REM Usage: scripts\build.cmd [--release]
setlocal

set MODE=debug
if "%~1"=="--release" set MODE=release

echo === Building Windows (%MODE%) ===
flutter build windows --%MODE%
if errorlevel 1 goto :fail

if "%MODE%"=="release" (
    echo Output: build\windows\x64\runner\Release\
) else (
    echo Output: build\windows\x64\runner\Debug\
)

echo === Build complete ===
exit /b 0

:fail
echo === Build FAILED ===
exit /b 1
