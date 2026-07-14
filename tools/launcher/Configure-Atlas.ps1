[CmdletBinding()]
param(
  [string]$ResourceRoot,
  [int]$Port = 0,
  [switch]$SkipInitialize
)

$ErrorActionPreference = "Stop"
$portalRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$configPath = Join-Path $portalRoot "config\local.user.json"
$domainConfigPath = Join-Path $portalRoot "config\external-content-domains.json"
$domainConfig = Get-Content -LiteralPath $domainConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$existingConfig = $null

if (Test-Path -LiteralPath $configPath) {
  try {
    $existingConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Write-Warning "现有本机配置无法读取，将重新建立。"
  }
}

$defaultRoot = Join-Path $portalRoot "Atlas-Data"
if ($existingConfig -and -not [string]::IsNullOrWhiteSpace([string]$existingConfig.resourceRoot)) {
  $defaultRoot = [string]$existingConfig.resourceRoot
}

if ([string]::IsNullOrWhiteSpace($ResourceRoot)) {
  Write-Host ""
  Write-Host "Atlas 资源目录连接" -ForegroundColor Cyan
  Write-Host "请输入本机文件夹，或输入 \\电脑名\共享名 形式的共享路径。"
  Write-Host "该目录下会建立 $($domainConfig.projectFolder) 标准演示结构。"
  $enteredRoot = Read-Host "资源根目录（直接回车使用 $defaultRoot）"
  $ResourceRoot = if ([string]::IsNullOrWhiteSpace($enteredRoot)) { $defaultRoot } else { $enteredRoot }
}

$ResourceRoot = $ResourceRoot.Trim().Trim('"')
if ([string]::IsNullOrWhiteSpace($ResourceRoot)) {
  throw "资源目录不能为空。"
}

$isUnc = $ResourceRoot.StartsWith("\\")
if ($isUnc) {
  $resourceRootFull = $ResourceRoot.TrimEnd("\")
  if (-not (Test-Path -LiteralPath $resourceRootFull)) {
    throw "无法访问共享目录：$resourceRootFull。请先在资源管理器中确认账号权限、网络和共享名。"
  }
} else {
  $resourceRootFull = [System.IO.Path]::GetFullPath($ResourceRoot)
  New-Item -ItemType Directory -Path $resourceRootFull -Force | Out-Null
}

if ($Port -eq 0) {
  $Port = if ($existingConfig -and $existingConfig.port) { [int]$existingConfig.port } else { 3011 }
}
if ($Port -lt 1024 -or $Port -gt 65535) {
  throw "端口必须在 1024 到 65535 之间。"
}

$localConfig = [ordered]@{
  resourceRoot = $resourceRootFull
  projectFolder = [string]$domainConfig.projectFolder
  port = $Port
  openBrowser = if ($existingConfig -and $null -ne $existingConfig.openBrowser) { [bool]$existingConfig.openBrowser } else { $true }
  configuredAt = (Get-Date).ToString("o")
  configuredBy = $env:USERNAME
}
$localConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8

if (-not $SkipInitialize) {
  $initializer = Join-Path $portalRoot "tools\local-lab\Initialize-ExternalContentShare.ps1"
  & $initializer -ShareRoot $resourceRootFull -PortalRoot $portalRoot | Out-Null
}

Write-Host ""
Write-Host "连接配置已保存。" -ForegroundColor Green
Write-Host "资源根目录：$resourceRootFull"
Write-Host "项目目录：$(Join-Path $resourceRootFull $domainConfig.projectFolder)"
Write-Host "访问端口：$Port"

[pscustomobject]$localConfig
