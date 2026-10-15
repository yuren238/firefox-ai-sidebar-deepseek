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

REM ---- Firefox must be fully closed before omni.ja can be rewritten ----
REM Ask, do not fail: a browser left open is the most common reason this script
REM does not finish, and retyping the command is a bad answer to it.
set /a ff_tries=0
:wait_firefox
set /a ff_tries+=1
if %ff_tries% gtr 100 (
    echo [ERROR] Firefox was still running after 100 checks. Giving up.
    pause
    exit /b 1
)
REM Detection goes through PowerShell, not "tasklist | find": when this bat is
REM launched from a Git Bash / MSYS shell, PATH resolves "find" to the Unix tool
REM and the check silently passes even though Firefox is running.
powershell -NoProfile -Command "$ff = Get-Process firefox -ErrorAction SilentlyContinue; if ($ff) { exit 1 } else { exit 0 }"
if %errorlevel% equ 0 goto :run_patch

echo.
echo [!] Firefox is still running.
echo     Close every Firefox window - including a leftover background/tray
echo     process - then continue. Your tabs are restored on next start.
echo.
echo       [Enter] check again      [K] force-close Firefox      [Q] quit
echo.
set "ans="
set /p "ans=Choice: "
if /I "%ans%"=="Q" exit /b 1
if /I "%ans%"=="K" (
    echo Force-closing Firefox ...
    taskkill /IM firefox.exe /F >nul 2>&1
    ping -n 4 127.0.0.1 >nul
)
goto :wait_firefox

:run_patch
echo Patching Firefox AI sidebar with DeepSeek ...
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "rc=%errorlevel%"
echo ============================================================
echo.
if not "%rc%"=="0" (
    echo [FAILED] The patch did not complete. Read the SUMMARY block above -
    echo          each line says OK or FAIL.
    echo.
    echo          If it says writes were refused, the script already retried
    echo          itself as SYSTEM automatically. A second failure means some
    echo          other filter or security product is blocking the file.
    pause
    exit /b %rc%
)
echo [OK] Patch applied and verified. Start Firefox and press Ctrl+Alt+X -
echo      DeepSeek is in the provider dropdown.
pause
