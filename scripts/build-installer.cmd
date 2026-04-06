@echo off
REM Build Windows installer locally
REM Prerequisites: Inno Setup 6 installed, Flutter SDK
REM Usage: scripts\build-installer.cmd [version]
setlocal

set VERSION=%~1
if "%VERSION%"=="" set VERSION=0.1.0-local

echo === Building Windows Release ===
call flutter build windows --release
if errorlevel 1 goto :fail

echo === Downloading VC++ Redistributable ===
if not exist "build\vc_redist.x64.exe" (
    powershell -Command "Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile 'build\vc_redist.x64.exe'"
    if errorlevel 1 goto :fail
)

echo === Building Installer ===
if not exist releases mkdir releases
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion="%VERSION%" "installers\windows\installer.iss"
if errorlevel 1 goto :fail

echo === Installer built successfully ===
dir releases\ancient-anguish-client-windows-x64-setup-*.exe
exit /b 0

:fail
echo === Build FAILED ===
exit /b 1
