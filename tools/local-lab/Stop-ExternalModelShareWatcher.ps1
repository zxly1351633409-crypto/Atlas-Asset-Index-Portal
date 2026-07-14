[CmdletBinding()]
param([string]$PortalRoot)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($PortalRoot)) { $PortalRoot = Join-Path $PSScriptRoot "..\.." }
$portalRootFull = [System.IO.Path]::GetFullPath($PortalRoot)
$pidFile = Join-Path $portalRootFull ".external-share-watcher.pid"

if (-not (Test-Path -LiteralPath $pidFile)) {
  [ordered]@{ Stopped = $false; Note = "No watcher pid file was found." } | ConvertTo-Json
  exit 0
}

$watcherPid = [int](Get-Content -LiteralPath $pidFile -Raw)
$processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $watcherPid" -ErrorAction SilentlyContinue
if ($processInfo -and $processInfo.CommandLine -match "Watch-External(Content|Model)Share\.ps1") {
  Stop-Process -Id $watcherPid -Force
}
Remove-Item -LiteralPath $pidFile -Force
[ordered]@{ Stopped = $true; ProcessId = $watcherPid } | ConvertTo-Json
