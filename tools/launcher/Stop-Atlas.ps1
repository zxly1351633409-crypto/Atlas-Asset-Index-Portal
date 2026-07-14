[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$portalRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$runtimeRoot = Join-Path $portalRoot ".runtime"
$stopped = [System.Collections.Generic.List[string]]::new()

foreach ($entry in @(
  @{ Name = "门户服务"; Path = (Join-Path $runtimeRoot "server.pid") },
  @{ Name = "目录监视器"; Path = (Join-Path $runtimeRoot "watcher.pid") }
)) {
  if (-not (Test-Path -LiteralPath $entry.Path)) { continue }
  $rawPid = (Get-Content -LiteralPath $entry.Path -Raw -ErrorAction SilentlyContinue).Trim()
  $processId = 0
  if ([int]::TryParse($rawPid, [ref]$processId)) {
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($process) {
      Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
      [void]$process.WaitForExit(5000)
      $stopped.Add($entry.Name)
    }
  }
  Remove-Item -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue
}

if (-not $Quiet) {
  if ($stopped.Count -gt 0) {
    Write-Host "已停止：$($stopped -join '、')。" -ForegroundColor Green
  } else {
    Write-Host "Atlas 当前没有由启动器运行的后台进程。"
  }
}
