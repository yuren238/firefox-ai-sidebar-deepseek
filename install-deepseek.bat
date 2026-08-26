@echo off
setlocal
title DeepSeek for Firefox AI Sidebar

set "SCRIPT=%~dp0Add-DeepSeekToFirefox.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] Add-DeepSeekToFirefox.ps1 not found next to this bat file.
    pause
    exit /b 1
)

REM ---- elevate to administrator via UAC ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights - please click YES on the UAC prompt...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM ---- Firefox must be fully closed ----
tasklist /FI "IMAGENAME eq firefox.exe" 2>nul | find /I "firefox.exe" >nul
if %errorlevel% equ 0 (
    echo [ERROR] Firefox is still running. Close ALL Firefox windows, then run this again.
    pause
    exit /b 1
)

echo Patching Firefox AI sidebar with DeepSeek ...
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
echo ============================================================
echo If you saw "Done. Start Firefox ..." above, success.
echo Start Firefox and press Ctrl+Alt+X to see DeepSeek.
pause
