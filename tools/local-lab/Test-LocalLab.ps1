[CmdletBinding()]
param(
  [string]$RootPath
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RootPath)) {
  $RootPath = Join-Path $PSScriptRoot "..\..\lab-data"
}
$root = [System.IO.Path]::GetFullPath($RootPath)
$tfvcRoot = Join-Path $root "TFVC-Workspace\ProjectAurora"
$nasRoot = Join-Path $root "NAS-Share\ProjectAurora"

if (-not (Test-Path -LiteralPath $tfvcRoot) -or -not (Test-Path -LiteralPath $nasRoot)) {
  throw "Local lab is missing. Run Setup-LocalLab.ps1 first."
}

$files = @(Get-ChildItem -LiteralPath $nasRoot -File -Recurse)
$writeProbe = Join-Path $nasRoot ".atlas-write-probe.tmp"
$lockBlocksSecondOpen = $false
$writeProbePassed = $false

try {
  Set-Content -LiteralPath $writeProbe -Value "Atlas local write probe" -Encoding UTF8
  $writeProbePassed = Test-Path -LiteralPath $writeProbe

  $firstHandle = [System.IO.File]::Open($writeProbe, "Open", "ReadWrite", "None")
  try {
    try {
      $secondHandle = [System.IO.File]::Open($writeProbe, "Open", "ReadWrite", "ReadWrite")
      $secondHandle.Dispose()
    } catch [System.IO.IOException] {
      $lockBlocksSecondOpen = $true
    }
  } finally {
    $firstHandle.Dispose()
  }
} finally {
  Remove-Item -LiteralPath $writeProbe -Force -ErrorAction SilentlyContinue
}

$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
if ($null -eq $totalBytes) { $totalBytes = 0 }

[ordered]@{
  LabRoot = $root
  TfvcWorkspaceExists = (Test-Path -LiteralPath $tfvcRoot)
  NasFolderExists = (Test-Path -LiteralPath $nasRoot)
  IndexedFileCount = $files.Count
  IndexedBytes = [int64]$totalBytes
  Extensions = @($files | Group-Object Extension | Sort-Object Count -Descending | ForEach-Object {
    [ordered]@{ Extension = $_.Name; Count = $_.Count }
  })
  WriteProbePassed = $writeProbePassed
  ExclusiveLockBlocksSecondOpen = $lockBlocksSecondOpen
  SourceDownloadPolicy = "on-demand"
} | ConvertTo-Json -Depth 4
