#Requires -Version 5.1
param(
  [string]$Repo,            # owner/repo（省略可）
  [string]$Ref,             # 省略可
  [string]$OutputDir,       # 省略可
  [string]$RepoListPath,    # 1行1レポ owner/repo（#でコメント）
  [switch]$ChooseRepo,      # 対話選択
  [switch]$ChooseBranch,    # 対話選択
  [switch]$LatestPR         # 最新 open PR の head ブランチ優先
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Get-GitHubRepoZip.Core.ps1"

function Select-FromList([string]$Title,[string[]]$Items,[int]$Limit=20){
  Write-Host $Title
  for($i=0;$i -lt [Math]::Min($Items.Count,$Limit);$i++){ Write-Host ('[{0}] {1}' -f ($i+1),$Items[$i]) }
  do { $ans = Read-Host 'Enter number' } while (-not ($ans -as [int]) -or [int]$ans -lt 1 -or [int]$ans -gt [Math]::Min($Items.Count,$Limit))
  return $Items[[int]$ans-1]
}

Test-GhAuth

# Repo 解決
if (-not $Repo) {
  if ($RepoListPath -and (Test-Path $RepoListPath)) {
    $list = Get-Content -Path $RepoListPath | Where-Object { $_ -and $_.Trim() -ne '' -and -not $_.Trim().StartsWith('#') } | ForEach-Object { $_.Trim() }
    if ($list.Count -gt 0) { $Repo = Select-FromList 'Select repository:' $list }
  } elseif ($ChooseRepo) {
    $repos = Get-RepoList
    if ($repos.Count -eq 0) { throw 'No repositories found via gh repo list.' }
    $Repo = Select-FromList 'Select repository:' $repos
  } else {
    throw 'Repository not specified. Provide -Repo or -RepoListPath or -ChooseRepo.'
  }
}

# Ref 解決
if (-not $Ref) {
  if ($LatestPR) {
    $pr = Get-LatestOpenPrHead -Repo $Repo
    if ($pr) { $Ref = $pr }
  }
  if (-not $Ref -and $ChooseBranch) {
    $branches = Get-Branches -Repo $Repo
    if ($branches.Count -gt 0) { $Ref = Select-FromList ('Select branch of ' + $Repo + ':') $branches }
  }
  if (-not $Ref) { $Ref = Get-DefaultBranch -Repo $Repo }
}

# ダウンロード
$out = Invoke-ZipballDownload -Repo $Repo -Ref $Ref -OutputDir $OutputDir
Write-Host ('Saved: ' + $out)
Invoke-Item -LiteralPath (Split-Path -Parent $out)
