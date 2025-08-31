#Requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Repo,
  [string]$Ref,
  [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Error 'GitHub CLI gh not found. Install with: winget install GitHub.cli -e'
  exit 1
}

try { & gh auth status | Out-Null } catch {
  Write-Error 'gh auth login is required. Run: gh auth login'
  exit 1
}

function Get-DownloadsPath {
  try {
    $reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $v1  = (Get-ItemProperty -Path $reg -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction SilentlyContinue).'{374DE290-123F-4565-9164-39C4925E467B}'
    $v2  = (Get-ItemProperty -Path $reg -Name 'Downloads' -ErrorAction SilentlyContinue).Downloads
    $val = if ($v1) { $v1 } elseif ($v2) { $v2 } else { $null }
    if ($val) { return [Environment]::ExpandEnvironmentVariables($val) }
  } catch {}
  return (Join-Path $env:USERPROFILE 'Downloads')
}

$ts       = Get-Date -Format 'yyyyMMdd_HHmmss'
$repoSafe = ($Repo -replace '[/:]', '_')
$outDir   = if ($OutputDir -and $OutputDir.Trim()) { $OutputDir } else { Get-DownloadsPath }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outPath  = Join-Path $outDir ($repoSafe + '-' + $ts + '.zip')

$refPath  = if ($Ref -and $Ref.Trim()) { '/' + $Ref.Trim() } else { '' }
$uri      = 'https://api.github.com/repos/' + $Repo + '/zipball' + $refPath

$token = (& gh auth token).Trim()
if (-not $token) { Write-Error 'Failed to obtain token from gh. Run: gh auth status'; exit 1 }

$headers = @{
  'Authorization'        = 'Bearer ' + $token
  'Accept'               = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
  'User-Agent'           = 'alweiz-zip-downloader'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $outPath

if (-not (Test-Path $outPath)) {
  Write-Error 'Download failed. Check repo, permissions, or network.'
  exit 1
}

Write-Output ('Saved: ' + $outPath)
Invoke-Item -LiteralPath $outDir
