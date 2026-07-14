[CmdletBinding()]
param(
  [string]$ResourceRoot,
  [int]$Port = 0,
  [switch]$SkipOpen,
  [switch]$ForcePortableNode
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$portalRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$runtimeRoot = Join-Path $portalRoot ".runtime"
$logsRoot = Join-Path $runtimeRoot "logs"
$cacheRoot = Join-Path $runtimeRoot "npm-cache"
$configPath = Join-Path $portalRoot "config\local.user.json"
$launcherVersion = "0.2.0"
New-Item -ItemType Directory -Path $logsRoot, $cacheRoot -Force | Out-Null

function Write-Step {
  param([string]$Message)
  Write-Host "[Atlas] $Message" -ForegroundColor Cyan
}

function Get-StringHash {
  param([string]$Value)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Remove-ChildDirectorySafely {
  param([string]$Path, [string]$Parent)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd("\") + "\"
  if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "拒绝清理运行目录之外的路径：$fullPath"
  }
  if (Test-Path -LiteralPath $fullPath) {
    Remove-Item -LiteralPath $fullPath -Recurse -Force
  }
}

function Get-NodeRuntime {
  $portableRoot = Join-Path $runtimeRoot "node"
  $portableNode = Join-Path $portableRoot "node.exe"
  $portableNpm = Join-Path $portableRoot "npm.cmd"
  if (Test-Path -LiteralPath $portableNode) {
    return [pscustomobject]@{ Node = $portableNode; Npm = $portableNpm; Kind = "portable" }
  }

  if (-not $ForcePortableNode) {
    $systemNode = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($systemNode) {
      try {
        $version = [version]((& $systemNode.Source --version).Trim().TrimStart("v"))
        $systemNpm = Join-Path (Split-Path $systemNode.Source -Parent) "npm.cmd"
        if ($version -ge [version]"22.13.0" -and (Test-Path -LiteralPath $systemNpm)) {
          return [pscustomobject]@{ Node = $systemNode.Source; Npm = $systemNpm; Kind = "system" }
        }
      } catch {
        Write-Warning "系统 Node.js 版本无法识别，将安装便携运行环境。"
      }
    }
  }

  Write-Step "未发现兼容的 Node.js，正在从官方站点下载便携 Node 22。"
  $architecture = if ($env:PROCESSOR_ARCHITECTURE -match "ARM64") { "win-arm64" } elseif ([Environment]::Is64BitOperatingSystem) { "win-x64" } else { "win-x86" }
  $releaseRoot = "https://nodejs.org/download/release/latest-v22.x"
  $checksums = (Invoke-WebRequest -Uri "$releaseRoot/SHASUMS256.txt" -UseBasicParsing).Content
  $pattern = "(?m)^([a-f0-9]{64})\s+(node-v22\.[^\s]+-$([regex]::Escape($architecture))\.zip)$"
  $match = [regex]::Match($checksums, $pattern)
  if (-not $match.Success) {
    throw "Node 官方校验清单中未找到 $architecture 便携包。"
  }

  $expectedHash = $match.Groups[1].Value
  $archiveName = $match.Groups[2].Value
  $downloadRoot = Join-Path $runtimeRoot "node-download"
  Remove-ChildDirectorySafely -Path $downloadRoot -Parent $runtimeRoot
  New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
  $archivePath = Join-Path $downloadRoot $archiveName
  Invoke-WebRequest -Uri "$releaseRoot/$archiveName" -OutFile $archivePath -UseBasicParsing
  $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $expectedHash) {
    throw "Node 下载文件校验失败，未继续安装。"
  }

  Expand-Archive -LiteralPath $archivePath -DestinationPath $downloadRoot -Force
  $expandedRoot = Get-ChildItem -LiteralPath $downloadRoot -Directory | Select-Object -First 1
  if (-not $expandedRoot) { throw "Node 便携包解压失败。" }
  if (Test-Path -LiteralPath $portableRoot) {
    Remove-ChildDirectorySafely -Path $portableRoot -Parent $runtimeRoot
  }
  Move-Item -LiteralPath $expandedRoot.FullName -Destination $portableRoot
  Remove-ChildDirectorySafely -Path $downloadRoot -Parent $runtimeRoot

  return [pscustomobject]@{ Node = $portableNode; Npm = $portableNpm; Kind = "portable" }
}

function Get-BuildFingerprint {
  $inputs = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
  foreach ($relativePath in @("package.json", "package-lock.json", "vite.config.ts", "next.config.ts", "tsconfig.json", ".openai\hosting.json", "build\sites-vite-plugin.ts")) {
    $path = Join-Path $portalRoot $relativePath
    if (Test-Path -LiteralPath $path) { $inputs.Add((Get-Item -LiteralPath $path)) }
  }
  foreach ($folder in @("app", "config", "db", "worker")) {
    $path = Join-Path $portalRoot $folder
    if (Test-Path -LiteralPath $path) {
      foreach ($file in @(Get-ChildItem -LiteralPath $path -Recurse -File | Where-Object { $_.Name -ne "local.user.json" })) {
        $inputs.Add($file)
      }
    }
  }
  $parts = foreach ($file in @($inputs | Sort-Object FullName)) {
    "$($file.FullName.Substring($portalRoot.Length))|$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)"
  }
  return Get-StringHash -Value ($parts -join "`n")
}

function Test-PortFree {
  param([int]$Candidate)
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Candidate)
  try {
    $listener.Start()
    return $true
  } catch {
    return $false
  } finally {
    $listener.Stop()
  }
}

try {
  if (-not (Test-Path -LiteralPath $configPath) -and [string]::IsNullOrWhiteSpace($ResourceRoot)) {
    Write-Step "首次运行需要选择资源目录。"
    & (Join-Path $PSScriptRoot "Configure-Atlas.ps1") | Out-Null
  }

  $config = if (Test-Path -LiteralPath $configPath) {
    Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } else {
    [pscustomobject]@{}
  }
  if ([string]::IsNullOrWhiteSpace($ResourceRoot)) { $ResourceRoot = [string]$config.resourceRoot }
  if ([string]::IsNullOrWhiteSpace($ResourceRoot)) { throw "尚未配置资源目录，请先运行连接资源目录.bat。" }
  $resourceRootFull = if ($ResourceRoot.StartsWith("\\")) { $ResourceRoot.TrimEnd("\") } else { [System.IO.Path]::GetFullPath($ResourceRoot) }
  if (-not (Test-Path -LiteralPath $resourceRootFull)) { throw "资源目录当前不可访问：$resourceRootFull" }

  if ($Port -eq 0) { $Port = if ($config.port) { [int]$config.port } else { 3011 } }
  $currentBuildFingerprint = Get-BuildFingerprint
  $storedBuildFingerprint = if (Test-Path -LiteralPath (Join-Path $runtimeRoot "build.hash")) {
    (Get-Content -LiteralPath (Join-Path $runtimeRoot "build.hash") -Raw).Trim()
  } else { "" }

  $sessionPath = Join-Path $runtimeRoot "session.json"
  if (Test-Path -LiteralPath $sessionPath) {
    try {
      $existingSession = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $existingServer = Get-Process -Id ([int]$existingSession.serverPid) -ErrorAction SilentlyContinue
      $existingWatcher = Get-Process -Id ([int]$existingSession.watcherPid) -ErrorAction SilentlyContinue
      $sameResourceRoot = ([string]$existingSession.resourceRoot).TrimEnd("\").Equals($resourceRootFull.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)
      $sameLauncher = ([string]$existingSession.launcherVersion) -eq $launcherVersion
      if ($existingServer -and $existingWatcher -and $sameResourceRoot -and $sameLauncher -and $storedBuildFingerprint -eq $currentBuildFingerprint) {
        $existingResponse = Invoke-WebRequest -Uri ([string]$existingSession.url) -UseBasicParsing -TimeoutSec 4
        if ($existingResponse.StatusCode -eq 200) {
          Write-Host ""
          Write-Host "Atlas 已在运行。" -ForegroundColor Green
          Write-Host "页面地址：$($existingSession.url)"
          Write-Host "资源目录：$resourceRootFull"
          if (-not $SkipOpen -and ($null -eq $config.openBrowser -or [bool]$config.openBrowser)) {
            Start-Process ([string]$existingSession.url)
          }
          return
        }
      }
    } catch {
      Write-Warning "检测到旧会话，但健康检查未通过，将自动重启。"
    }
  }

  & (Join-Path $PSScriptRoot "Stop-Atlas.ps1") -Quiet
  $effectivePort = $Port
  while (-not (Test-PortFree -Candidate $effectivePort)) {
    $effectivePort += 1
    if ($effectivePort -gt ($Port + 20)) { throw "端口 $Port 至 $($Port + 20) 均被占用。" }
  }
  if ($effectivePort -ne $Port) { Write-Warning "端口 $Port 已占用，本次改用 $effectivePort。" }

  Write-Step "检查资源目录并生成最新索引。"
  $initializer = Join-Path $portalRoot "tools\local-lab\Initialize-ExternalContentShare.ps1"
  & $initializer -ShareRoot $resourceRootFull -PortalRoot $portalRoot | Out-Null

  $runtime = Get-NodeRuntime
  $env:PATH = "$(Split-Path $runtime.Node -Parent);$env:PATH"
  $env:npm_config_cache = $cacheRoot
  Write-Step "使用 $($runtime.Kind) Node.js：$((& $runtime.Node --version).Trim())"

  $lockHash = (Get-FileHash -LiteralPath (Join-Path $portalRoot "package-lock.json") -Algorithm SHA256).Hash.ToLowerInvariant()
  $installHashPath = Join-Path $runtimeRoot "install.hash"
  $installedHash = if (Test-Path -LiteralPath $installHashPath) { (Get-Content -LiteralPath $installHashPath -Raw).Trim() } else { "" }
  $vinextCli = Join-Path $portalRoot "node_modules\vinext\dist\cli.js"
  if ($installedHash -ne $lockHash -or -not (Test-Path -LiteralPath $vinextCli)) {
    Write-Step "安装锁定依赖，首次运行可能需要数分钟。"
    Push-Location $portalRoot
    try {
      & $runtime.Npm ci --no-audit --no-fund
      if ($LASTEXITCODE -ne 0) { throw "npm ci 执行失败，退出码 $LASTEXITCODE。" }
    } finally {
      Pop-Location
    }
    Set-Content -LiteralPath $installHashPath -Value $lockHash -Encoding ASCII
  } else {
    Write-Step "依赖已就绪，无需重复安装。"
  }

  $buildHash = $currentBuildFingerprint
  $buildHashPath = Join-Path $runtimeRoot "build.hash"
  $previousBuildHash = if (Test-Path -LiteralPath $buildHashPath) { (Get-Content -LiteralPath $buildHashPath -Raw).Trim() } else { "" }
  $serverEntry = Join-Path $portalRoot "dist\server\index.js"
  if ($previousBuildHash -ne $buildHash -or -not (Test-Path -LiteralPath $serverEntry)) {
    Write-Step "构建本机门户。"
    Push-Location $portalRoot
    try {
      & $runtime.Npm run build
      if ($LASTEXITCODE -ne 0) { throw "门户构建失败，退出码 $LASTEXITCODE。" }
    } finally {
      Pop-Location
    }
    Set-Content -LiteralPath $buildHashPath -Value $buildHash -Encoding ASCII
  } else {
    Write-Step "构建产物已是最新。"
  }

  $scanner = Join-Path $portalRoot "tools\local-lab\Scan-ExternalContentShare.ps1"
  & $scanner -ShareRoot $resourceRootFull -PortalRoot $portalRoot | Out-Null

  Write-Step "启动目录监视器。"
  $watchScript = Join-Path $portalRoot "tools\local-lab\Watch-ExternalContentShare.ps1"
  $watchArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$watchScript`" -ShareRoot `"$resourceRootFull`" -PortalRoot `"$portalRoot`""
  $watcher = Start-Process -FilePath "powershell.exe" -ArgumentList $watchArguments -WorkingDirectory $portalRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logsRoot "watcher.out.log") -RedirectStandardError (Join-Path $logsRoot "watcher.err.log") -PassThru
  Set-Content -LiteralPath (Join-Path $runtimeRoot "watcher.pid") -Value $watcher.Id -Encoding ASCII

  Write-Step "启动网页服务。"
  # The local demo server intentionally uses vinext dev so connector JSON and
  # preview files written by the watcher remain available without a rebuild.
  $serverArguments = "`"$vinextCli`" dev --port $effectivePort --hostname 127.0.0.1"
  $server = Start-Process -FilePath $runtime.Node -ArgumentList $serverArguments -WorkingDirectory $portalRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logsRoot "server.out.log") -RedirectStandardError (Join-Path $logsRoot "server.err.log") -PassThru
  Set-Content -LiteralPath (Join-Path $runtimeRoot "server.pid") -Value $server.Id -Encoding ASCII

  $url = "http://127.0.0.1:$effectivePort/"
  $ready = $false
  for ($attempt = 0; $attempt -lt 60; $attempt += 1) {
    Start-Sleep -Milliseconds 500
    if ($server.HasExited) { break }
    try {
      $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) { $ready = $true; break }
    } catch {}
  }
  if (-not $ready) {
    $serverError = Join-Path $logsRoot "server.err.log"
    $tail = if (Test-Path -LiteralPath $serverError) { (Get-Content -LiteralPath $serverError -Tail 20) -join "`n" } else { "未生成错误日志。" }
    & (Join-Path $PSScriptRoot "Stop-Atlas.ps1") -Quiet
    throw "网页服务未能就绪。`n$tail"
  }

  [ordered]@{
    resourceRoot = $resourceRootFull
    port = $effectivePort
    url = $url
    serverPid = $server.Id
    watcherPid = $watcher.Id
    launcherVersion = $launcherVersion
    serverMode = "local-demo"
    startedAt = (Get-Date).ToString("o")
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeRoot "session.json") -Encoding UTF8

  Write-Host ""
  Write-Host "Atlas 已启动。" -ForegroundColor Green
  Write-Host "页面地址：$url"
  Write-Host "资源目录：$resourceRootFull"
  Write-Host "日志目录：$logsRoot"
  if (-not $SkipOpen -and ($null -eq $config.openBrowser -or [bool]$config.openBrowser)) {
    Start-Process $url
  }
} catch {
  try { & (Join-Path $PSScriptRoot "Stop-Atlas.ps1") -Quiet } catch {}
  Write-Host ""
  Write-Host "Atlas 启动失败：$($_.Exception.Message)" -ForegroundColor Red
  Write-Host "可查看日志：$logsRoot"
  exit 1
}
