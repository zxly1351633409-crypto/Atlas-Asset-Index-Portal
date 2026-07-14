[CmdletBinding()]
param(
  [string]$CollectionUrl,
  [string]$TfvcServerPath,
  [string]$NasPath,
  [switch]$AllowNasWriteProbe
)

$ErrorActionPreference = "Stop"

function Find-TfCommand {
  $command = Get-Command tf.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $roots = @(
    "$env:ProgramFiles\Microsoft Visual Studio\2022",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019"
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

  foreach ($root in $roots) {
    $candidate = Get-ChildItem -LiteralPath $root -Filter TF.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
  }
  return $null
}

$report = [ordered]@{
  CheckedAt = (Get-Date).ToString("o")
  Mode = if ($AllowNasWriteProbe) { "read-plus-explicit-write-probe" } else { "read-only" }
}

$tf = Find-TfCommand
$report.TfCommand = $tf
if ($CollectionUrl -and $TfvcServerPath -and $tf) {
  $report.TfvcWorkspaces = @(& $tf workspaces "/collection:$CollectionUrl" 2>&1 | Select-Object -First 30)
  $report.TfvcDirectory = @(& $tf dir $TfvcServerPath "/collection:$CollectionUrl" 2>&1 | Select-Object -First 30)
} elseif ($CollectionUrl -or $TfvcServerPath) {
  $report.TfvcNote = "Both CollectionUrl and TfvcServerPath are required, and TF.exe must be installed."
} else {
  $report.TfvcNote = "Skipped. Supply the company collection URL and a non-sensitive TFVC server path."
}

if ($NasPath) {
  $report.NasReachable = Test-Path -LiteralPath $NasPath
  if ($report.NasReachable) {
    $report.NasSample = @(Get-ChildItem -LiteralPath $NasPath -File -Recurse -ErrorAction Stop | Select-Object -First 20 FullName, Length, LastWriteTime)
    if ($AllowNasWriteProbe) {
      $probe = Join-Path $NasPath ".atlas-company-write-probe.tmp"
      try {
        Set-Content -LiteralPath $probe -Value "Atlas explicit connector write probe" -Encoding UTF8
        $report.NasWriteProbe = Test-Path -LiteralPath $probe
      } finally {
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
      }
    }
  }
} else {
  $report.NasNote = "Skipped. Supply a non-sensitive UNC path such as \\\\server\\share\\pilot-folder."
}

$report | ConvertTo-Json -Depth 5
