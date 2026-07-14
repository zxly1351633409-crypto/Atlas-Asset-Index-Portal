@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher\Configure-Atlas.ps1"
if errorlevel 1 (
  echo.
  echo Atlas configuration failed. Review the message above.
)
pause
