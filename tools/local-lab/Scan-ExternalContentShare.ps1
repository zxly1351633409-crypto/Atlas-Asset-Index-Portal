[CmdletBinding()]
param(
  [string]$ShareRoot,
  [string]$PortalRoot,
  [string]$ShareName = "AtlasModelShare"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ShareRoot)) { $ShareRoot = "F:\Atlas-Company-Share" }
if ([string]::IsNullOrWhiteSpace($PortalRoot)) { $PortalRoot = Join-Path $PSScriptRoot "..\.." }

$shareRootFull = [System.IO.Path]::GetFullPath($ShareRoot)
$portalRootFull = [System.IO.Path]::GetFullPath($PortalRoot)
$configPath = Join-Path $portalRootFull "config\external-content-domains.json"
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectRoot = Join-Path $shareRootFull $config.projectFolder
$outputRoot = Join-Path $portalRootFull "public\connector-data"
$previewCache = Join-Path $outputRoot "previews"
$outputFile = Join-Path $outputRoot "external-content-share.json"
$stateRoot = Join-Path $portalRootFull "lab-data"
$stateFile = Join-Path $stateRoot "external-content-state.json"
$thumbnailGenerator = Join-Path $PSScriptRoot "Generate-PreviewThumbnail.mjs"

if (-not (Test-Path -LiteralPath $projectRoot)) {
  throw "Project folder not found: $projectRoot"
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $previewCache -Force | Out-Null
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null

function Get-RelativePath {
  param([string]$BasePath, [string]$Path)
  $baseUri = [Uri]::new(([System.IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"))
  $pathUri = [Uri]::new([System.IO.Path]::GetFullPath($Path))
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace("/", "\")
}

function Get-Slug {
  param([string]$Value)
  $slug = ($Value -replace "[^A-Za-z0-9._-]", "-").Trim("-").ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($slug)) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    $slug = ([System.BitConverter]::ToString($hash).Replace("-", "").Substring(0, 16)).ToLowerInvariant()
  }
  return $slug
}

function Get-Hash {
  param([string]$Value)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return [System.BitConverter]::ToString($hash).Replace("-", "").ToLowerInvariant()
}

function Get-MetadataValue {
  param([object]$Metadata, [string]$Name, $Fallback)
  if ($null -ne $Metadata -and $null -ne $Metadata.PSObject.Properties[$Name]) {
    $value = $Metadata.$Name
    if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return $value }
  }
  return $Fallback
}

function Get-NodeExecutable {
  $systemNode = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($systemNode) { return $systemNode.Source }
  $portableNode = Join-Path $portalRootFull ".runtime\node\node.exe"
  if (Test-Path -LiteralPath $portableNode) { return $portableNode }
  return $null
}

function Wait-ForFileStable {
  param(
    [string]$Path,
    [int]$TimeoutSeconds = 120
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $previousLength = -1L
  $previousWriteTicks = -1L
  $stableReadings = 0

  while ((Get-Date) -lt $deadline) {
    try {
      $item = Get-Item -LiteralPath $Path -ErrorAction Stop
      $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
      $stream.Dispose()

      if ($item.Length -eq $previousLength -and $item.LastWriteTimeUtc.Ticks -eq $previousWriteTicks) {
        $stableReadings += 1
      } else {
        $stableReadings = 0
        $previousLength = $item.Length
        $previousWriteTicks = $item.LastWriteTimeUtc.Ticks
      }

      if ($stableReadings -ge 2) { return $item }
    } catch {
      $stableReadings = 0
    }
    Start-Sleep -Milliseconds 650
  }

  throw "文件在 $TimeoutSeconds 秒内仍未写入完成：$Path"
}

function New-PreviewThumbnail {
  param(
    [string]$InputPath,
    [string]$OutputPath
  )

  $node = Get-NodeExecutable
  if ([string]::IsNullOrWhiteSpace($node)) {
    throw "未找到 Node.js，启动 Atlas 后会自动准备运行环境并重试。"
  }
  if (-not (Test-Path -LiteralPath $thumbnailGenerator)) {
    throw "缺少缩略图生成脚本：$thumbnailGenerator"
  }

  $output = @(& $node $thumbnailGenerator $InputPath $OutputPath 1280 960 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw (($output | ForEach-Object { [string]$_ }) -join " ").Trim()
  }
  return (($output -join "") | ConvertFrom-Json)
}

$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
$uncRoot = if ($share) { "\\$env:COMPUTERNAME\$ShareName" } else { $null }

function Convert-ToUncPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($uncRoot)) { return $null }
  $relative = Get-RelativePath -BasePath $shareRootFull -Path $Path
  return Join-Path $uncRoot $relative
}

$previousById = @{}
if (Test-Path -LiteralPath $stateFile) {
  try {
    $previousState = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($asset in @($previousState.assets)) { $previousById[$asset.id] = $asset }
  } catch {
    $previousById = @{}
  }
}

$previewExtensions = @(".jpg", ".jpeg", ".png", ".webp")
$assetGroups = @{}
$domainFileMap = @{}
$allContentFiles = [System.Collections.Generic.List[object]]::new()

foreach ($domain in $config.domains) {
  $domainRoot = Join-Path $projectRoot $domain.relativeRoot
  New-Item -ItemType Directory -Path $domainRoot -Force | Out-Null
  $moduleDirectories = @(Get-ChildItem -LiteralPath $domainRoot -Directory -ErrorAction Stop | Where-Object { -not $_.Name.StartsWith("_") })
  foreach ($moduleDirectory in $moduleDirectories) {
    $versionDirectories = @(Get-ChildItem -LiteralPath $moduleDirectory.FullName -Directory -ErrorAction Stop | Where-Object { -not $_.Name.StartsWith("_") })
    foreach ($versionDirectory in $versionDirectories) {
      $assetDirectories = @(Get-ChildItem -LiteralPath $versionDirectory.FullName -Directory -ErrorAction Stop | Where-Object { -not $_.Name.StartsWith("_") })
      foreach ($assetDirectory in $assetDirectories) {
        $groupKey = "$($domain.id)|$($moduleDirectory.Name)|$($versionDirectory.Name)|$($assetDirectory.Name)"
        if (-not $assetGroups.ContainsKey($groupKey)) {
          $assetGroups[$groupKey] = [ordered]@{
            DomainId = $domain.id
            DomainLabel = $domain.label
            DomainRoot = $domainRoot
            Module = $moduleDirectory.Name
            Version = $versionDirectory.Name
            AssetName = $assetDirectory.Name
            AssetRoot = $assetDirectory.FullName
            Files = [System.Collections.Generic.List[object]]::new()
          }
        }
      }
    }
  }
  $domainFiles = @(Get-ChildItem -LiteralPath $domainRoot -File -Recurse -ErrorAction Stop | Where-Object { -not $_.Name.StartsWith("_") })
  $domainFileMap[$domain.id] = $domainFiles

  foreach ($file in $domainFiles) {
    $allContentFiles.Add($file)
    $relative = Get-RelativePath -BasePath $domainRoot -Path $file.FullName
    $segments = @($relative -split "[\\/]")
    if ($segments.Count -lt 3) { continue }

    $module = $segments[0]
    $version = $segments[1]
    if ($segments.Count -eq 3) {
      $assetName = if ($file.Name.EndsWith(".asset.json", [System.StringComparison]::OrdinalIgnoreCase)) { $file.Name.Substring(0, $file.Name.Length - ".asset.json".Length) } else { $file.BaseName }
      $assetRoot = $file.DirectoryName
    } else {
      $assetName = $segments[2]
      $assetRoot = Join-Path (Join-Path (Join-Path $domainRoot $module) $version) $assetName
    }
    $groupKey = "$($domain.id)|$module|$version|$assetName"
    if (-not $assetGroups.ContainsKey($groupKey)) {
      $assetGroups[$groupKey] = [ordered]@{
        DomainId = $domain.id
        DomainLabel = $domain.label
        DomainRoot = $domainRoot
        Module = $module
        Version = $version
        AssetName = $assetName
        AssetRoot = $assetRoot
        Files = [System.Collections.Generic.List[object]]::new()
      }
    }
    $assetGroups[$groupKey].Files.Add($file)
  }
}

$activeAssets = [System.Collections.Generic.List[object]]::new()
$stateAssets = [System.Collections.Generic.List[object]]::new()
$desiredPreviewNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$currentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$scanTime = Get-Date

foreach ($group in @($assetGroups.Values | Sort-Object DomainId, Module, Version, AssetName)) {
  $files = @($group.Files | Sort-Object FullName)
  $metadataFile = $files | Where-Object { $_.Name -like "*.asset.json" } | Select-Object -First 1
  $metadata = $null
  if ($metadataFile) {
    try { $metadata = Get-Content -LiteralPath $metadataFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $metadata = $null }
  }

  $fallbackId = Get-Slug -Value "$($group.DomainId)-$($group.Module)-$($group.Version)-$($group.AssetName)"
  $assetId = [string](Get-MetadataValue -Metadata $metadata -Name "id" -Fallback $fallbackId)
  if (-not $currentIds.Add($assetId)) { throw "Duplicate asset id '$assetId'. Give each asset.json a unique id." }

  $displayName = [string](Get-MetadataValue -Metadata $metadata -Name "name" -Fallback $group.AssetName)
  $description = [string](Get-MetadataValue -Metadata $metadata -Name "description" -Fallback "$($group.Module) / $($group.Version) 共享盘内容")
  $owner = [string](Get-MetadataValue -Metadata $metadata -Name "owner" -Fallback $env:USERNAME)
  $actorGroup = [string](Get-MetadataValue -Metadata $metadata -Name "actorGroup" -Fallback "$($group.DomainLabel)组")
  $tags = if ($metadata -and $metadata.PSObject.Properties["tags"]) { @($metadata.tags) } else { @($group.DomainLabel, $group.Module, $group.Version) }
  $previewFile = $files | Where-Object {
    $relativeCandidate = Get-RelativePath -BasePath $group.AssetRoot -Path $_.FullName
    ($previewExtensions -contains $_.Extension.ToLowerInvariant()) -and $relativeCandidate.StartsWith("Preview\", [System.StringComparison]::OrdinalIgnoreCase)
  } | Select-Object -First 1
  if (-not $previewFile) {
    $previewFile = $files | Where-Object { $previewExtensions -contains $_.Extension.ToLowerInvariant() } | Select-Object -First 1
  }
  $previewIsDedicated = $false
  $previewUrl = $null
  $previewPath = $null
  $previewUncPath = $null
  $previewSize = 0
  $previewFormat = $null
  $previewSourceSize = 0
  $previewSourceFormat = $null
  $thumbnailStatus = if ($previewFile) { "pending" } else { "missing" }
  $thumbnailError = $null

  if ($previewFile) {
    $previewRelativePath = Get-RelativePath -BasePath $group.AssetRoot -Path $previewFile.FullName
    $previewIsDedicated = $previewRelativePath.StartsWith("Preview\", [System.StringComparison]::OrdinalIgnoreCase)
    try {
      $initialStamp = "$($previewFile.FullName)|$($previewFile.Length)|$($previewFile.LastWriteTimeUtc.Ticks)"
      $initialVersion = (Get-Hash -Value $initialStamp).Substring(0, 16)
      $cacheName = "$(Get-Slug -Value $assetId)-$initialVersion.jpg"
      $cachePath = Join-Path $previewCache $cacheName

      if (-not (Test-Path -LiteralPath $cachePath)) {
        $previewFile = Wait-ForFileStable -Path $previewFile.FullName
        $stableStamp = "$($previewFile.FullName)|$($previewFile.Length)|$($previewFile.LastWriteTimeUtc.Ticks)"
        $stableVersion = (Get-Hash -Value $stableStamp).Substring(0, 16)
        $cacheName = "$(Get-Slug -Value $assetId)-$stableVersion.jpg"
        $cachePath = Join-Path $previewCache $cacheName
        if (-not (Test-Path -LiteralPath $cachePath)) {
          [void](New-PreviewThumbnail -InputPath $previewFile.FullName -OutputPath $cachePath)
        }
      }

      $cachedPreview = Get-Item -LiteralPath $cachePath
      [void]$desiredPreviewNames.Add($cacheName)
      $previewUrl = "/connector-data/previews/$cacheName"
      $previewPath = $previewFile.FullName
      $previewUncPath = Convert-ToUncPath -Path $previewFile.FullName
      $previewSize = [int64]$cachedPreview.Length
      $previewFormat = "JPG"
      $previewSourceSize = [int64]$previewFile.Length
      $previewSourceFormat = $previewFile.Extension.TrimStart(".").ToUpperInvariant()
      $thumbnailStatus = "ready"
    } catch {
      $thumbnailStatus = "error"
      $thumbnailError = $_.Exception.Message
      Write-Warning "无法为 '$($previewFile.FullName)' 生成缩略图：$thumbnailError"
    }
  }

  $sourceFiles = [System.Collections.Generic.List[object]]::new()
  foreach ($file in $files) {
    if ($metadataFile -and $file.FullName -eq $metadataFile.FullName) { continue }
    $relativeToAsset = Get-RelativePath -BasePath $group.AssetRoot -Path $file.FullName
    $fileSegments = @($relativeToAsset -split "[\\/]")
    $sourceFiles.Add([ordered]@{
      name = $file.Name
      path = $file.FullName
      uncPath = Convert-ToUncPath -Path $file.FullName
      relativePath = $relativeToAsset
      category = if ($fileSegments.Count -gt 1) { $fileSegments[0] } else { "Files" }
      format = $file.Extension.TrimStart(".").ToUpperInvariant()
      size = [int64]$file.Length
      lastWriteTime = $file.LastWriteTime.ToString("o")
    })
  }

  $fingerprintParts = $files | ForEach-Object {
    $relativeFile = Get-RelativePath -BasePath $group.AssetRoot -Path $_.FullName
    "$relativeFile|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)"
  }
  $fingerprint = Get-Hash -Value (($fingerprintParts | Sort-Object) -join "`n")
  $previous = $previousById[$assetId]
  $operations = if ($previous) { @($previous.operations) } else { @() }
  $action = $null
  $summary = $null

  if (-not $previous) {
    $action = "上传"
    $summary = "共享盘首次发现该内容，已建立真实目录与门户索引。"
  } elseif ($previous.lifecycleStatus -eq "deleted") {
    $action = "回溯"
    $summary = "目录重新出现，按原内容标识恢复并创建新修订。"
  } elseif ($previous.fingerprint -ne $fingerprint) {
    $action = "修改"
    $summary = "共享盘文件名称、大小或更新时间发生变化，已刷新索引。"
  }

  if ($action) {
    $revisionNumber = $operations.Count + 1
    $operation = [ordered]@{
      id = "$assetId-operation-$revisionNumber-$(Get-Random)"
      action = $action
      revision = "$($group.Version)-R$revisionNumber"
      sourceRevision = "NAS-$($scanTime.ToString('yyyyMMddHHmmss'))"
      actor = $owner
      actorGroup = $actorGroup
      time = $scanTime.ToString("yyyy-MM-dd HH:mm")
      source = "NAS"
      path = if ($uncRoot) { Convert-ToUncPath -Path $group.AssetRoot } else { $group.AssetRoot }
      summary = $summary
      fileCount = $files.Count
    }
    $operations = @($operation) + @($operations)
  }

  $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
  if ($null -eq $totalBytes) { $totalBytes = 0 }
  $updatedAt = if ($files.Count -gt 0) { ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime } else { (Get-Item -LiteralPath $group.AssetRoot).LastWriteTime }
  $assetRecord = [ordered]@{
    id = $assetId
    domainId = $group.DomainId
    domainLabel = $group.DomainLabel
    name = $displayName
    module = $group.Module
    version = $group.Version
    description = $description
    owner = $owner
    actorGroup = $actorGroup
    tags = @($tags)
    rootPath = $group.AssetRoot
    uncPath = Convert-ToUncPath -Path $group.AssetRoot
    previewUrl = $previewUrl
    previewPath = $previewPath
    previewUncPath = $previewUncPath
    previewSize = $previewSize
    previewFormat = $previewFormat
    previewSourceSize = $previewSourceSize
    previewSourceFormat = $previewSourceFormat
    thumbnailStatus = $thumbnailStatus
    thumbnailError = $thumbnailError
    sourceFiles = @($sourceFiles)
    fileCount = $files.Count
    totalBytes = [int64]$totalBytes
    updatedAt = $updatedAt.ToString("o")
    lifecycleStatus = "active"
    fingerprint = $fingerprint
    operations = @($operations)
  }
  $activeAssets.Add($assetRecord)
  $stateAssets.Add($assetRecord)
}

foreach ($previous in @($previousById.Values)) {
  if ($currentIds.Contains([string]$previous.id)) { continue }
  $operations = @($previous.operations)
  if ($previous.lifecycleStatus -ne "deleted") {
    $revisionNumber = $operations.Count + 1
    $deleteOperation = [ordered]@{
      id = "$($previous.id)-operation-$revisionNumber-$(Get-Random)"
      action = "删除"
      revision = "$($previous.version)-R$revisionNumber"
      sourceRevision = "NAS-$($scanTime.ToString('yyyyMMddHHmmss'))"
      actor = $previous.owner
      actorGroup = $previous.actorGroup
      time = $scanTime.ToString("yyyy-MM-dd HH:mm")
      source = "NAS"
      path = if ($previous.uncPath) { $previous.uncPath } else { $previous.rootPath }
      summary = "共享盘中已找不到该内容目录；历史路径和操作记录继续保留。"
      fileCount = 0
    }
    $operations = @($deleteOperation) + @($operations)
  }
  $deletedRecord = $previous | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $deletedRecord.lifecycleStatus = "deleted"
  $deletedRecord.operations = @($operations)
  $stateAssets.Add($deletedRecord)
}

foreach ($cachedPreview in @(Get-ChildItem -LiteralPath $previewCache -File -ErrorAction SilentlyContinue)) {
  if (-not $desiredPreviewNames.Contains($cachedPreview.Name)) {
    Remove-Item -LiteralPath $cachedPreview.FullName -Force
  }
}

$moduleRecords = foreach ($domain in $config.domains) {
  $domainRoot = Join-Path $projectRoot $domain.relativeRoot
  $moduleDirectories = @(Get-ChildItem -LiteralPath $domainRoot -Directory -ErrorAction Stop | Where-Object { -not $_.Name.StartsWith("_") })
  foreach ($moduleDirectory in $moduleDirectories) {
    $versionRecords = foreach ($versionDirectory in @(Get-ChildItem -LiteralPath $moduleDirectory.FullName -Directory -ErrorAction Stop | Where-Object { -not $_.Name.StartsWith("_") })) {
      [ordered]@{
        label = $versionDirectory.Name
        rootPath = $versionDirectory.FullName
        uncPath = Convert-ToUncPath -Path $versionDirectory.FullName
        updatedAt = $versionDirectory.LastWriteTime.ToString("o")
        assetCount = @($activeAssets | Where-Object { $_.domainId -eq $domain.id -and $_.module -eq $moduleDirectory.Name -and $_.version -eq $versionDirectory.Name }).Count
      }
    }
    [ordered]@{
      id = Get-Slug -Value "module-$($domain.id)-$($moduleDirectory.Name)"
      domainId = $domain.id
      domainLabel = $domain.label
      name = $moduleDirectory.Name
      rootPath = $moduleDirectory.FullName
      uncPath = Convert-ToUncPath -Path $moduleDirectory.FullName
      updatedAt = $moduleDirectory.LastWriteTime.ToString("o")
      versions = @($versionRecords)
    }
  }
}

$domainSummaries = foreach ($domain in $config.domains) {
  $domainRoot = Join-Path $projectRoot $domain.relativeRoot
  $files = @($domainFileMap[$domain.id])
  $bytes = ($files | Measure-Object -Property Length -Sum).Sum
  if ($null -eq $bytes) { $bytes = 0 }
  [ordered]@{
    domainId = $domain.id
    label = $domain.label
    relativeRoot = $domain.relativeRoot
    rootPath = $domainRoot
    uncPath = Convert-ToUncPath -Path $domainRoot
    fileCount = $files.Count
    totalBytes = [int64]$bytes
    moduleCount = @($moduleRecords | Where-Object { $_.domainId -eq $domain.id }).Count
    assetCount = @($activeAssets | Where-Object { $_.domainId -eq $domain.id }).Count
  }
}

$allBytes = ($allContentFiles | Measure-Object -Property Length -Sum).Sum
if ($null -eq $allBytes) { $allBytes = 0 }
$deletedAssetCount = @($stateAssets | Where-Object { $_.lifecycleStatus -eq "deleted" }).Count
$manifest = [ordered]@{
  status = "online"
  shareName = $ShareName
  rootPath = $shareRootFull
  uncPath = $uncRoot
  projectRoot = $projectRoot
  scannedAt = $scanTime.ToString("o")
  fileCount = $allContentFiles.Count
  totalBytes = [int64]$allBytes
  deletedAssetCount = $deletedAssetCount
  domains = @($domainSummaries)
  modules = @($moduleRecords)
  assets = @($activeAssets)
}
$state = [ordered]@{ scannedAt = $manifest.scannedAt; assets = @($stateAssets) }

$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outputFile -Encoding UTF8
$state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $stateFile -Encoding UTF8

# vinext copies public files into dist during a production build. Mirror the
# generated connector data so the one-click production server can keep updating
# without rebuilding after every shared-folder change.
$productionClientRoot = Join-Path $portalRootFull "dist\client"
if (Test-Path -LiteralPath $productionClientRoot) {
  $productionOutputRoot = Join-Path $productionClientRoot "connector-data"
  $productionPreviewCache = Join-Path $productionOutputRoot "previews"
  New-Item -ItemType Directory -Path $productionPreviewCache -Force | Out-Null
  Copy-Item -LiteralPath $outputFile -Destination (Join-Path $productionOutputRoot "external-content-share.json") -Force

  foreach ($preview in @(Get-ChildItem -LiteralPath $previewCache -File -ErrorAction SilentlyContinue)) {
    Copy-Item -LiteralPath $preview.FullName -Destination (Join-Path $productionPreviewCache $preview.Name) -Force
  }
  foreach ($productionPreview in @(Get-ChildItem -LiteralPath $productionPreviewCache -File -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path -LiteralPath (Join-Path $previewCache $productionPreview.Name))) {
      Remove-Item -LiteralPath $productionPreview.FullName -Force
    }
  }
}

$manifest | ConvertTo-Json -Depth 12
