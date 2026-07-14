[CmdletBinding()]
param(
  [string]$CollectionUrl,
  [string]$TfvcServerPath,
  [string]$LocalPath = "F:\Atlas-TFVC-Workspace\ProjectAurora",
  [string]$WorkspaceName = "AtlasPilot-$env:COMPUTERNAME",
  [switch]$Apply,
  [switch]$GetLatest
)

$ErrorActionPreference = "Stop"

function Find-TfCommand {
  $command = Get-Command tf.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $vswhere) {
    $installPath = & $vswhere -latest -products * -property installationPath
    if ($installPath) {
      $candidate = Join-Path $installPath "Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe"
      if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
  }
  return $null
}

$tf = Find-TfCommand
if (-not $tf) { throw "TF.exe was not found. Install the Visual Studio 2022 Core Editor/Team Explorer components first." }

$localPathFull = [System.IO.Path]::GetFullPath($LocalPath)
$driveRoot = [System.IO.Path]::GetPathRoot($localPathFull).TrimEnd("\")
if ($localPathFull.TrimEnd("\") -eq $driveRoot) { throw "LocalPath cannot be a drive root." }

$report = [ordered]@{
  TfCommand = $tf
  CollectionUrl = $CollectionUrl
  TfvcServerPath = $TfvcServerPath
  LocalPath = $localPathFull
  WorkspaceName = $WorkspaceName
  Mode = if ($Apply) { "apply" } else { "preview" }
}

if (-not $Apply) {
  $report.Next = "Supply the company CollectionUrl and TfvcServerPath, then rerun with -Apply. Add -GetLatest only when source files should be downloaded."
  $report | ConvertTo-Json -Depth 4
  exit 0
}

if ([string]::IsNullOrWhiteSpace($CollectionUrl) -or [string]::IsNullOrWhiteSpace($TfvcServerPath)) {
  throw "CollectionUrl and TfvcServerPath are required with -Apply."
}
$collectionUri = $null
if (-not [Uri]::TryCreate($CollectionUrl, [UriKind]::Absolute, [ref]$collectionUri) -or $collectionUri.Scheme -notin @("http", "https")) {
  throw "CollectionUrl must be an absolute HTTP or HTTPS URL."
}
if (-not $TfvcServerPath.StartsWith("$/", [System.StringComparison]::Ordinal)) {
  throw "TfvcServerPath must start with '$/'."
}

New-Item -ItemType Directory -Path $localPathFull -Force | Out-Null

function Invoke-Tf {
  param([string[]]$Arguments)
  $output = @(& $tf @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
}

$workspaceOutput = Invoke-Tf -Arguments @(
  "workspace", "/new", "/noprompt", "/location:local", "/permission:private",
  "/collection:$CollectionUrl", $WorkspaceName
)
$mappingOutput = Invoke-Tf -Arguments @(
  "workfold", "/map", $TfvcServerPath, $localPathFull,
  "/workspace:$WorkspaceName", "/collection:$CollectionUrl"
)

$report.Workspace = @($workspaceOutput | Select-Object -First 20)
$report.Mapping = @($mappingOutput | Select-Object -First 20)
if ($GetLatest) {
  $report.GetLatest = @(Invoke-Tf -Arguments @("get", $localPathFull, "/recursive") | Select-Object -First 30)
} else {
  $report.GetLatest = "Skipped. The workspace is mapped without downloading all source files."
}
$report | ConvertTo-Json -Depth 5
