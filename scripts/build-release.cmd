@echo off
REM Build Windows release and package to releases\
REM Usage: scripts\build-release.cmd
setlocal

echo === Static Analysis ===
flutter analyze --fatal-infos
if errorlevel 1 goto :fail

echo.
echo === Running Tests ===
flutter test
if errorlevel 1 goto :fail

echo.
echo === Building Windows Release ===
flutter build windows --release
if errorlevel 1 goto :fail

echo.
echo === Packaging Release ===
set RELEASE_DIR=build\windows\x64\runner\Release
set OUT=releases\ancient-anguish-client-windows-x64.zip

if not exist "%RELEASE_DIR%" (
    echo ERROR: Build output not found at %RELEASE_DIR%
    exit /b 1
)

if not exist releases mkdir releases
powershell -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%OUT%' -Force"
if errorlevel 1 goto :fail

for %%A in ("%OUT%") do set SIZE=%%~zA
set /a SIZE_MB=%SIZE% / 1048576

echo.
echo === Release packaged ===
echo Output: %OUT% (~%SIZE_MB% MB)
exit /b 0

:fail
echo.
echo === Release build FAILED ===
exit /b 1
