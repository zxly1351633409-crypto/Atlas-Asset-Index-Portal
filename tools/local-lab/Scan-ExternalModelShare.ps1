[CmdletBinding()]
param(
  [string]$ShareRoot,
  [string]$PortalRoot,
  [string]$ShareName = "AtlasModelShare"
)

$ErrorActionPreference = "Stop"

# Compatibility entry point. The full-domain scanner also includes Models.
& (Join-Path $PSScriptRoot "Scan-ExternalContentShare.ps1") @PSBoundParameters
return

if ([string]::IsNullOrWhiteSpace($ShareRoot)) { $ShareRoot = "F:\Atlas-Company-Share" }
if ([string]::IsNullOrWhiteSpace($PortalRoot)) { $PortalRoot = Join-Path $PSScriptRoot "..\.." }

$shareRootFull = [System.IO.Path]::GetFullPath($ShareRoot)
$portalRootFull = [System.IO.Path]::GetFullPath($PortalRoot)
$modelsRoot = Join-Path $shareRootFull "ProjectAurora\Models"
$outputRoot = Join-Path $portalRootFull "public\connector-data"
$previewCache = Join-Path $outputRoot "previews"
$outputFile = Join-Path $outputRoot "external-model-share.json"

if (-not (Test-Path -LiteralPath $modelsRoot)) {
  throw "Models folder not found: $modelsRoot"
}

New-Item -ItemType Directory -Path $previewCache -Force | Out-Null

function Get-RelativePath {
  param([string]$BasePath, [string]$Path)
  $baseUri = [Uri]::new(([System.IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"))
  $pathUri = [Uri]::new([System.IO.Path]::GetFullPath($Path))
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace("/", "\")
}

$previewExtensions = @(".jpg", ".jpeg", ".png", ".webp")
$allFiles = @(Get-ChildItem -LiteralPath $modelsRoot -File -Recurse -ErrorAction Stop)
$assetGroups = @{}

foreach ($file in $allFiles) {
  $relative = Get-RelativePath -BasePath $modelsRoot -Path $file.FullName
  $segments = @($relative -split "[\\/]")
  if ($segments.Count -lt 4) { continue }

  $module = $segments[0]
  $version = $segments[1]
  $assetName = $segments[2]
  $key = "$module|$version|$assetName"
  if (-not $assetGroups.ContainsKey($key)) {
    $assetGroups[$key] = [ordered]@{
      Id = ($key -replace "[^A-Za-z0-9._-]", "-").ToLowerInvariant()
      Name = $assetName
      Module = $module
      Version = $version
      PreviewUrl = $null
      SourceFiles = [System.Collections.Generic.List[object]]::new()
    }
  }

  $asset = $assetGroups[$key]
  if ($previewExtensions -contains $file.Extension.ToLowerInvariant()) {
    if (-not $asset.PreviewUrl) {
      $cacheName = ("$module-$version-$assetName-$($file.Name)" -replace "[^A-Za-z0-9._-]", "-").ToLowerInvariant()
      Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $previewCache $cacheName) -Force
      $asset.PreviewUrl = "/connector-data/previews/$cacheName"
    }
  } elseif ($file.Extension -ne ".json") {
    $asset.SourceFiles.Add([ordered]@{
      name = $file.Name
      path = $file.FullName
      size = [int64]$file.Length
    })
  }
}

$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
$assets = @($assetGroups.Values | Sort-Object Module, Version, Name | ForEach-Object {
  [ordered]@{
    id = $_.Id
    name = $_.Name
    module = $_.Module
    version = $_.Version
    previewUrl = $_.PreviewUrl
    sourceFiles = @($_.SourceFiles)
  }
})
$totalBytes = ($allFiles | Measure-Object -Property Length -Sum).Sum
if ($null -eq $totalBytes) { $totalBytes = 0 }

$manifest = [ordered]@{
  status = "online"
  shareName = $ShareName
  rootPath = $shareRootFull
  uncPath = if ($share) { "\\$env:COMPUTERNAME\$ShareName" } else { $null }
  scannedAt = (Get-Date).ToString("o")
  fileCount = $allFiles.Count
  totalBytes = [int64]$totalBytes
  assets = $assets
}

$manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $outputFile -Encoding UTF8
$manifest | ConvertTo-Json -Depth 7
