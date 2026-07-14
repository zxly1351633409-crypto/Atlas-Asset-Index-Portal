[CmdletBinding()]
param(
  [string]$ShareRoot,
  [string]$ShareName = "AtlasModelShare"
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ShareRoot)) { $ShareRoot = "F:\Atlas-Company-Share" }
$shareRootFull = [System.IO.Path]::GetFullPath($ShareRoot)

if (-not (Test-Path -LiteralPath $shareRootFull)) { throw "ShareRoot not found: $shareRootFull" }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run this script from an elevated PowerShell window."
}

$existing = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if ($existing -and ([System.IO.Path]::GetFullPath($existing.Path) -ne $shareRootFull)) {
  throw "SMB share '$ShareName' already points to another folder."
}
if (-not $existing) {
  New-SmbShare -Name $ShareName -Path $shareRootFull -ChangeAccess $identity.Name | Out-Null
}

$uncPath = "\\$env:COMPUTERNAME\$ShareName"
[ordered]@{ ShareName = $ShareName; LocalPath = $shareRootFull; UncPath = $uncPath; Reachable = (Test-Path -LiteralPath $uncPath) } | ConvertTo-Json
