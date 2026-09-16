@echo off
setlocal
cd /d "%~dp0"

REM Prefer PowerShell 7 (pwsh); Windows PowerShell 2.x cannot run this script.
set "PS7=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not exist "%PS7%" set "PS7=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
if exist "%PS7%" (
    "%PS7%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-rules.ps1" %*
    exit /b %ERRORLEVEL%
)

where pwsh >nul 2>&1
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-rules.ps1" %*
    exit /b %ERRORLEVEL%
)

echo ERROR: PowerShell 7 (pwsh) is required. Install from https://aka.ms/powershell
echo        or run in Cursor terminal:  pwsh -File sync-rules.ps1
exit /b 1
