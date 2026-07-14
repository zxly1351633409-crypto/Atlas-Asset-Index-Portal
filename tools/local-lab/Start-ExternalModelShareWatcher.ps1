[CmdletBinding()]
param(
  [string]$ShareRoot,
  [string]$PortalRoot
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ShareRoot)) { $ShareRoot = "F:\Atlas-Company-Share" }
if ([string]::IsNullOrWhiteSpace($PortalRoot)) { $PortalRoot = Join-Path $PSScriptRoot "..\.." }

$shareRootFull = [System.IO.Path]::GetFullPath($ShareRoot)
$portalRootFull = [System.IO.Path]::GetFullPath($PortalRoot)
$pidFile = Join-Path $portalRootFull ".external-share-watcher.pid"

if (Test-Path -LiteralPath $pidFile) {
  $existingPid = [int](Get-Content -LiteralPath $pidFile -Raw)
  $existing = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
  if ($existing) {
    [ordered]@{ Started = $false; ProcessId = $existingPid; Note = "Watcher is already running." } | ConvertTo-Json
    exit 0
  }
}

$watchScript = Join-Path $PSScriptRoot "Watch-ExternalModelShare.ps1"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$watchScript`" -ShareRoot `"$shareRootFull`" -PortalRoot `"$portalRootFull`""
$process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru
Set-Content -LiteralPath $pidFile -Value $process.Id -Encoding ASCII

[ordered]@{ Started = $true; ProcessId = $process.Id; ShareRoot = $shareRootFull; ManifestRefresh = "automatic" } | ConvertTo-Json
