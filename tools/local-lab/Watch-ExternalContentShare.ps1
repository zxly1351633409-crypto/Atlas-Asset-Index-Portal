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
$scanner = Join-Path $PSScriptRoot "Scan-ExternalContentShare.ps1"

function Invoke-ScanWithRetry {
  for ($attempt = 1; $attempt -le 3; $attempt += 1) {
    try {
      & $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull | Out-Null
      return
    } catch {
      Write-Warning "Directory scan failed (attempt $attempt of 3): $($_.Exception.Message)"
      if ($attempt -lt 3) { Start-Sleep -Seconds (2 * $attempt) }
    }
  }
  Write-Warning "This scan did not complete. The watcher is still running and will retry after the next directory change."
}

Invoke-ScanWithRetry

$watcher = [System.IO.FileSystemWatcher]::new($shareRootFull)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]"FileName, DirectoryName, LastWrite, Size"

try {
  while ($true) {
    $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 10000)
    if (-not $change.TimedOut) {
      $quietUntil = (Get-Date).AddMilliseconds(1400)
      while ((Get-Date) -lt $quietUntil) {
        $nextChange = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 350)
        if (-not $nextChange.TimedOut) { $quietUntil = (Get-Date).AddMilliseconds(1400) }
      }
      Invoke-ScanWithRetry
    }
  }
} finally {
  $watcher.Dispose()
}
