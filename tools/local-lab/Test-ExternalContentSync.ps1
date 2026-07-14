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
$stateFile = Join-Path $portalRootFull "lab-data\external-content-state.json"
$scenesRoot = Join-Path $shareRootFull "ProjectAurora\Scenes"
$testModuleRoot = Join-Path $scenesRoot "AtlasSyncTest"
$testAssetRoot = Join-Path $testModuleRoot "V0.0\SyncProbe"
$previewRoot = Join-Path $testAssetRoot "Preview"
$sourceRoot = Join-Path $testAssetRoot "Source"
$previewSource = Join-Path $portalRootFull "public\previews\canyon.jpg"
$testAssetId = "atlas-sync-probe"
$originalState = if (Test-Path -LiteralPath $stateFile) { Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 } else { $null }

$resolvedScenesRoot = [System.IO.Path]::GetFullPath($scenesRoot).TrimEnd("\") + "\"
$resolvedTestRoot = [System.IO.Path]::GetFullPath($testModuleRoot)
if (-not $resolvedTestRoot.StartsWith($resolvedScenesRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Unsafe test path: $resolvedTestRoot"
}

try {
  if (Test-Path -LiteralPath $resolvedTestRoot) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force }
  New-Item -ItemType Directory -Path $previewRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
  Copy-Item -LiteralPath $previewSource -Destination (Join-Path $previewRoot "SyncProbe.jpg") -Force
  Set-Content -LiteralPath (Join-Path $sourceRoot "SyncProbe.psd") -Value "ATLAS sync probe v1" -Encoding UTF8
  [ordered]@{
    id = $testAssetId
    name = "同步测试内容"
    description = "自动化临时内容"
    owner = $env:USERNAME
    actorGroup = "场景组"
    tags = @("测试")
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $testAssetRoot "SyncProbe.asset.json") -Encoding UTF8

  $afterCreate = & $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull | ConvertFrom-Json
  $createdAsset = $afterCreate.assets | Where-Object { $_.id -eq $testAssetId } | Select-Object -First 1
  if (-not $createdAsset -or $createdAsset.domainId -ne "scene" -or $createdAsset.operations[0].action -ne "上传") {
    throw "Create synchronization failed."
  }

  Add-Content -LiteralPath (Join-Path $sourceRoot "SyncProbe.psd") -Value "ATLAS sync probe v2" -Encoding UTF8
  $afterModify = & $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull | ConvertFrom-Json
  $modifiedAsset = $afterModify.assets | Where-Object { $_.id -eq $testAssetId } | Select-Object -First 1
  if (-not $modifiedAsset -or $modifiedAsset.operations[0].action -ne "修改") {
    throw "Modify synchronization failed."
  }

  Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  [void](& $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull)
  $deletedState = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $deletedAsset = $deletedState.assets | Where-Object { $_.id -eq $testAssetId } | Select-Object -First 1
  if (-not $deletedAsset -or $deletedAsset.lifecycleStatus -ne "deleted" -or $deletedAsset.operations[0].action -ne "删除") {
    throw "Delete synchronization failed."
  }

  [ordered]@{
    Passed = $true
    Domain = $createdAsset.domainId
    Module = $createdAsset.module
    Version = $createdAsset.version
    Actions = @("上传", "修改", "删除")
  } | ConvertTo-Json -Depth 4
} finally {
  if (Test-Path -LiteralPath $resolvedTestRoot) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force }
  if ($null -eq $originalState) {
    if (Test-Path -LiteralPath $stateFile) { Remove-Item -LiteralPath $stateFile -Force }
  } else {
    Set-Content -LiteralPath $stateFile -Value $originalState -Encoding UTF8
  }
  [void](& $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull)
}
