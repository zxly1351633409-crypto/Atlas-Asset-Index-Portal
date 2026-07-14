@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher\Start-Atlas.ps1"
if errorlevel 1 (
  echo.
  echo Atlas is not ready. Review the message above.
  pause
  exit /b 1
)
echo.
echo Atlas is open. Press any key to close this window.
pause >nul
exit /b 0
