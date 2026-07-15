[CmdletBinding()]
param([string]$Version = "0.2.1")

$ErrorActionPreference = "Stop"
$portalRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$runtimeRoot = Join-Path $portalRoot ".runtime"
$releaseRoot = Join-Path $portalRoot "release"
$stageParent = Join-Path $runtimeRoot "release-stage"
$packageName = "Atlas-Portal-Windows-v$Version"
$stageRoot = Join-Path $stageParent $packageName
$zipPath = Join-Path $releaseRoot "$packageName.zip"
$checksumPath = "$zipPath.sha256.txt"

function Assert-ChildPath {
  param([string]$Path, [string]$Parent)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd("\") + "\"
  if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the expected parent: $fullPath"
  }
}

New-Item -ItemType Directory -Path $runtimeRoot, $releaseRoot, $stageParent -Force | Out-Null
Assert-ChildPath -Path $stageRoot -Parent $stageParent
if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

$rootFiles = Get-ChildItem -LiteralPath $portalRoot -File -Force | Where-Object {
  $_.Name -notlike ".dev-server*.log" -and
  $_.Name -ne ".external-share-watcher.pid"
}
$includeDirectories = @(".github", ".openai", "app", "build", "config", "db", "docs", "drizzle", "examples", "mock-data", "public", "tests", "tools", "worker")
$files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($file in @($rootFiles)) { $files.Add($file) }

foreach ($directoryName in $includeDirectories) {
  $directoryPath = Join-Path $portalRoot $directoryName
  if (-not (Test-Path -LiteralPath $directoryPath)) { continue }
  foreach ($file in @(Get-ChildItem -LiteralPath $directoryPath -Recurse -File -Force)) {
    $relative = $file.FullName.Substring($portalRoot.Length).TrimStart("\")
    if ($relative -eq "config\local.user.json") { continue }
    if ($relative.StartsWith("docs\images\plan\", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
    if ($relative.StartsWith("docs\12-", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
    if ($relative -eq "tools\Build-ResourcePlanDocx.py") { continue }
    if ($relative.StartsWith("build\", [System.StringComparison]::OrdinalIgnoreCase) -and $relative -ne "build\sites-vite-plugin.ts") { continue }
    if ($relative.StartsWith(".openai\", [System.StringComparison]::OrdinalIgnoreCase) -and $relative -ne ".openai\hosting.json") { continue }
    if ($relative.StartsWith("public\connector-data\", [System.StringComparison]::OrdinalIgnoreCase)) { continue }
    $files.Add($file)
  }
}

foreach ($file in @($files | Sort-Object FullName -Unique)) {
  $relative = $file.FullName.Substring($portalRoot.Length).TrimStart("\")
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
if (Test-Path -LiteralPath $checksumPath) { Remove-Item -LiteralPath $checksumPath -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$hash  $packageName.zip" -Encoding ASCII
Remove-Item -LiteralPath $stageRoot -Recurse -Force

[pscustomobject]@{
  Package = $zipPath
  Bytes = (Get-Item -LiteralPath $zipPath).Length
  Sha256 = $hash
  ChecksumFile = $checksumPath
}
