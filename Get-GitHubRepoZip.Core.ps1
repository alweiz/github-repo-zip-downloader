#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-GhAuth {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI gh not found. Install with: winget install GitHub.cli -e'
  }
  try { & gh auth status | Out-Null } catch { throw 'Run: gh auth login' }
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

function Get-GhToken {
  $t = (& gh auth token).Trim()
  if (-not $t) { throw 'Failed to obtain token from gh (gh auth token).' }
  return $t
}

function Invoke-ZipballDownload {
  param(
    [Parameter(Mandatory=$true)][string]$Repo,     # owner/repo
    [string]$Ref,                                  # branch/tag/sha
    [string]$OutputDir                             # folder
  )
  if (-not $OutputDir) { $OutputDir = Get-DownloadsPath }
  if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  $repoSafe = ($Repo -replace '[/:]', '_')
  $refTag = if ($Ref) { '-' + ($Ref -replace '[^\w\.\-]','_') } else { '' }
  $outPath = Join-Path $OutputDir ($repoSafe + $refTag + '-' + $ts + '.zip')

  $refPath = if ($Ref) { '/' + $Ref } else { '' }
  $uri = 'https://api.github.com/repos/' + $Repo + '/zipball' + $refPath

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $headers = @{
    'Authorization'        = 'Bearer ' + (Get-GhToken)
    'Accept'               = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'alweiz-zip-downloader'
  }

  try {
    $resp = Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $outPath -PassThru -ErrorAction Stop
  }
  catch {
    throw ('HTTP request failed: ' + $_.Exception.Message)
  }

  # ステータスコード確認（念押し）
  if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 300) {
    throw ("GitHub returned status {0} {1}" -f $resp.StatusCode, $resp.StatusDescription)
  }

  if (-not (Test-Path $outPath)) {
    throw 'Download failed: file was not created.'
  }

  # サイズ・内容が怪しい場合を弾く（0バイト／HTMLの可能性）
  $fi = Get-Item $outPath
  if ($fi.Length -lt 512) {
    # 500B未満なら ZIP として怪しい。HTML/テキストを誤保存していないかチェック。
    $head = Get-Content -LiteralPath $outPath -TotalCount 1 -ErrorAction SilentlyContinue
    if ($head -and ($head -match '<!DOCTYPE html' -or $head -match '<html')) {
      Remove-Item -LiteralPath $outPath -Force -ErrorAction SilentlyContinue
      throw 'Download failed: received HTML response instead of ZIP (check repo/ref and permissions).'
    }
  }

  return $outPath
}

function Get-RepoList {
  # 最近更新順 上位を返す
  $list = & gh repo list --limit 100 --json nameWithOwner,pushedAt --jq 'sort_by(.pushedAt)|reverse|.[].nameWithOwner'
  return ($list -split "`n") | Where-Object { $_ -and $_.Trim() -ne '' }
}

function Get-Branches {
  param([Parameter(Mandatory=$true)][string]$Repo)
  $json = & gh api ('repos/{0}/branches?per_page=100' -f $Repo)
  $items = $json | ConvertFrom-Json
  $pairs = foreach ($b in $items) {
    [PSCustomObject]@{ name=$b.name; updated=$b.commit.commit.author.date }
  }
  return ($pairs | Sort-Object { Get-Date $_.updated } -Descending | Select-Object -ExpandProperty name)
}

function Get-DefaultBranch {
  param([Parameter(Mandatory=$true)][string]$Repo)
  try {
    $json = & gh api ("repos/{0}" -f $Repo) 2>$null
  } catch {
    # 404 なら null 返して呼び出し側で判断（例: テストで Skip など）
    if ($_.Exception.Message -match '404') { return $null }
    throw
  }
  $obj = $json | ConvertFrom-Json
  if (-not $obj -or -not $obj.default_branch) { return $null }
  return $obj.default_branch
}

function Get-LatestOpenPrHead {
  param([Parameter(Mandatory=$true)][string]$Repo)
  try {
    $json = & gh api ("repos/{0}/pulls?state=open&per_page=50" -f $Repo) 2>$null
  } catch {
    if ($_.Exception.Message -match '404') { return $null }
    throw
  }
  $arr = $json | ConvertFrom-Json
  if (-not $arr -or $arr.Count -eq 0) { return $null }
  ($arr | Sort-Object { Get-Date $_.updated_at } -Descending | Select-Object -First 1).head.ref
}
