[CmdletBinding()]
param(
  [string]$RootPath,
  [switch]$EnableSmbShare,
  [string]$ShareName = "AtlasLab"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RootPath)) {
  $RootPath = Join-Path $PSScriptRoot "..\..\lab-data"
}

$root = [System.IO.Path]::GetFullPath($RootPath)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$tfvcRoot = Join-Path $root "TFVC-Workspace\ProjectAurora"
$nasRoot = Join-Path $root "NAS-Share\ProjectAurora"
$previewRoot = Join-Path $nasRoot "Preview"
$sourceRoot = Join-Path $nasRoot "Source"
$projectRoot = Join-Path $nasRoot "3D-Project"

@($tfvcRoot, $previewRoot, $sourceRoot, $projectRoot) | ForEach-Object {
  New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

$previewSource = Join-Path $repoRoot "public\previews"
if (Test-Path -LiteralPath $previewSource) {
  Get-ChildItem -LiteralPath $previewSource -File |
    Where-Object { $_.Extension -in @(".jpg", ".jpeg", ".png", ".webp") } |
    Select-Object -First 6 |
    Copy-Item -Destination $previewRoot -Force
}

$placeholderFiles = @(
  @{ Path = (Join-Path $sourceRoot "scene-layout.psd"); Content = "Atlas metadata-only PSD placeholder." },
  @{ Path = (Join-Path $projectRoot "aurora-scene.blend"); Content = "Atlas metadata-only 3D project placeholder." },
  @{ Path = (Join-Path $tfvcRoot "README.txt"); Content = "Local folder used to simulate a mapped TFVC workspace." }
)

foreach ($file in $placeholderFiles) {
  if (-not (Test-Path -LiteralPath $file.Path)) {
    Set-Content -LiteralPath $file.Path -Value $file.Content -Encoding UTF8
  }
}

$manifest = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  purpose = "Local connector lab. No company data."
  tfvcWorkspace = $tfvcRoot
  nasFolder = $nasRoot
  sourcePolicy = "metadata-and-preview-only"
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root "lab-manifest.json") -Encoding UTF8

$sharePath = $null
if ($EnableSmbShare) {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    throw "EnableSmbShare requires an elevated PowerShell window. The local folders were created, but no share was changed."
  }

  $existing = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
  if ($existing -and ([System.IO.Path]::GetFullPath($existing.Path) -ne [System.IO.Path]::GetFullPath((Join-Path $root "NAS-Share")))) {
    throw "SMB share '$ShareName' already exists at another path. Choose a different ShareName."
  }
  if (-not $existing) {
    New-SmbShare -Name $ShareName -Path (Join-Path $root "NAS-Share") -ChangeAccess $identity.Name | Out-Null
  }
  $sharePath = "\\$env:COMPUTERNAME\$ShareName"
}

[ordered]@{
  Root = $root
  TfvcWorkspace = $tfvcRoot
  NasFolder = $nasRoot
  SmbShare = $sharePath
  Next = "Run Test-LocalLab.ps1. Use -EnableSmbShare only from an elevated shell when SMB behavior is required."
} | ConvertTo-Json
