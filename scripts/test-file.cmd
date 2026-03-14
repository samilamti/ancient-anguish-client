@echo off
REM Run tests matching a partial filename
REM Usage: scripts\test-file.cmd <pattern>
REM Example: scripts\test-file.cmd emoji  (runs test/services/emoji_parser_test.dart)
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: scripts\test-file.cmd ^<pattern^>
    echo Example: scripts\test-file.cmd emoji
    exit /b 1
)

set PATTERN=%~1
set FOUND=0

echo === Searching for test files matching "%PATTERN%" ===
for /f "delims=" %%f in ('dir /s /b test\*%PATTERN%*_test.dart 2^>nul') do (
    set /a FOUND+=1
    set "LAST=%%f"
    echo   %%f
)

if %FOUND%==0 (
    echo No test files found matching "%PATTERN%"
    exit /b 1
)

if %FOUND% gtr 1 (
    echo.
    echo Multiple matches found. Running all %FOUND% matching files...
    echo.
    flutter test test\*%PATTERN%*_test.dart
) else (
    echo.
    flutter test "!LAST!"
)

if errorlevel 1 (
    echo.
    echo === Tests FAILED ===
    exit /b 1
)

echo.
echo === Tests passed ===
exit /b 0
