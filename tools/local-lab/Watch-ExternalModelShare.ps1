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

& $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull | Out-Null

$watcher = [System.IO.FileSystemWatcher]::new($shareRootFull)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]"FileName, DirectoryName, LastWrite, Size"

try {
  while ($true) {
    $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 10000)
    if (-not $change.TimedOut) {
      Start-Sleep -Milliseconds 700
      & $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull | Out-Null
    }
  }
} finally {
  $watcher.Dispose()
}
