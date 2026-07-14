@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher\Start-Atlas.ps1"
if errorlevel 1 (
  echo.
  echo Atlas failed to start. Review the message above.
  pause
  exit /b 1
)
echo.
echo Atlas is running. The service will continue after this window closes.
echo Press any key when you have seen the address above.
pause >nul
exit /b 0
