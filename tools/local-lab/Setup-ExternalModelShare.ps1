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
$driveRoot = [System.IO.Path]::GetPathRoot($shareRootFull).TrimEnd("\")
if ($shareRootFull.TrimEnd("\") -eq $driveRoot) {
  throw "ShareRoot cannot be a drive root."
}

$assetRoot = Join-Path $shareRootFull "ProjectAurora\Models\Environment\V6.2\StoneGuardian"
$previewRoot = Join-Path $assetRoot "Preview"
$sourceRoot = Join-Path $assetRoot "Source"
$exportRoot = Join-Path $assetRoot "Export"
@($previewRoot, $sourceRoot, $exportRoot) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

$samplePreview = Join-Path $portalRootFull "public\previews\stone-gate.jpg"
$targetPreview = Join-Path $previewRoot "StoneGuardian.jpg"
if ((Test-Path -LiteralPath $samplePreview) -and -not (Test-Path -LiteralPath $targetPreview)) {
  Copy-Item -LiteralPath $samplePreview -Destination $targetPreview
}

$placeholders = @(
  @{ Path = (Join-Path $sourceRoot "StoneGuardian.blend"); Text = "Atlas external-share BLEND placeholder. Replace with a personal test model." },
  @{ Path = (Join-Path $exportRoot "StoneGuardian.fbx"); Text = "Atlas external-share FBX placeholder. Replace with a personal test export." }
)
foreach ($placeholder in $placeholders) {
  if (-not (Test-Path -LiteralPath $placeholder.Path)) {
    Set-Content -LiteralPath $placeholder.Path -Value $placeholder.Text -Encoding UTF8
  }
}

$assetMetadata = [ordered]@{
  asset = "StoneGuardian"
  module = "Environment"
  version = "V6.2"
  owner = $env:USERNAME
  note = "Personal test data outside the portal repository."
}
$assetMetadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $assetRoot "StoneGuardian.asset.json") -Encoding UTF8

$scanner = Join-Path $PSScriptRoot "Scan-ExternalModelShare.ps1"
$scanResult = & $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull

[ordered]@{
  ShareRoot = $shareRootFull
  SampleAsset = $assetRoot
  PortalManifest = (Join-Path $portalRootFull "public\connector-data\external-content-share.json")
  Scan = ($scanResult | Out-String).Trim()
  Next = "Add another folder under ProjectAurora\Models\<Module>\<Version>\<Asset>, then rerun the scanner or start the watcher."
} | ConvertTo-Json -Depth 4
