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
$configPath = Join-Path $portalRootFull "config\external-content-domains.json"
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$projectRoot = Join-Path $shareRootFull $config.projectFolder

New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
$createdRoots = [System.Collections.Generic.List[string]]::new()

foreach ($domain in $config.domains) {
  $domainRoot = Join-Path $projectRoot $domain.relativeRoot
  New-Item -ItemType Directory -Path $domainRoot -Force | Out-Null
  $createdRoots.Add($domainRoot)
}

$guide = @"
ATLAS 本机共享盘目录

每个工作域都使用相同层级：
  <工作域>\<模块>\<版本>\<内容名>\

内容目录建议包含：
  Preview\       JPG、PNG、WEBP 轻量预览
  Source\        PSD、BLEND、MAX、C4D 等源工程
  Export\        FBX、OBJ、GLTF、成图等交付文件
  Documents\     DOCX、XLSX 等需求文档
  <内容名>.asset.json（可选元数据）

asset.json 可以填写：id、name、description、owner、actorGroup、tags。
不填写时，门户会根据目录名自动生成这些信息。
"@
Set-Content -LiteralPath (Join-Path $projectRoot "_目录说明.txt") -Value $guide -Encoding UTF8

$template = [ordered]@{
  id = "optional-stable-id"
  name = "内容显示名称"
  description = "内容说明"
  owner = $env:USERNAME
  actorGroup = "所属组"
  tags = @("可选标签")
}
$template | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $projectRoot "_asset.template.json") -Encoding UTF8

$scanner = Join-Path $PSScriptRoot "Scan-ExternalContentShare.ps1"
$scan = & $scanner -ShareRoot $shareRootFull -PortalRoot $portalRootFull | ConvertFrom-Json

[ordered]@{
  ShareRoot = $shareRootFull
  ProjectRoot = $projectRoot
  DomainRoots = @($createdRoots)
  Manifest = (Join-Path $portalRootFull "public\connector-data\external-content-share.json")
  AssetCount = @($scan.assets).Count
  Next = "Add <Module>\<Version>\<Asset> below any domain root. The watcher will refresh the portal automatically."
} | ConvertTo-Json -Depth 5
