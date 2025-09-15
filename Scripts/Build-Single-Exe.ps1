param(
  [string]$UiPath   = ".\Get-GitHubRepoZip.UI.ps1",
  [string]$CorePath = ".\lib\Get-GitHubRepoZip.Core.ps1",
  [string]$OutExe   = ".\dist\GithubRepoZipDownloader.exe",
  [string]$Icon     = ".\assets\app.ico",
  [string]$Product  = "GitHub Repo Zip Downloader",
  [string]$Company  = "alweiz",
  [string]$Version  = "1.1.2.0"
)

$ErrorActionPreference = "Stop"

# 出力先
New-Item -ItemType Directory -Force -Path (Split-Path $OutExe) | Out-Null
$temp = Join-Path (Split-Path $OutExe) "Get-GitHubRepoZip.packed.ps1"

# 読み込み
$ui   = Get-Content $UiPath   -Raw -Encoding UTF8
$core = Get-Content $CorePath -Raw -Encoding UTF8

# 1) UI 先頭に Core をインライン
$packed = $core + "`r`n" + $ui

# 2) UI 内の「Core を dot-source している部分」を削除（if文ブロック全体を削除）
$coreLoadingPattern = '(?s)if \(-not \(Get-Command Test-GhAuth -ErrorAction SilentlyContinue\)\) \{.*?\n\}'
$packed = [regex]::Replace($packed, $coreLoadingPattern, '', 'Multiline')

# 一時 ps1 を出力
Set-Content -Path $temp -Value $packed -Encoding UTF8

# ps2exe 準備
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
  try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
  Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -Force

# アイコン（存在時のみ）
$iconArgs = @()
if (Test-Path $Icon) { $iconArgs = @('-IconFile', $Icon) }

# exe 化（コンソール無し）
Invoke-ps2exe -InputFile $temp -OutputFile $OutExe -NoConsole `
  -Title $Product -Product $Product -Company $Company `
  -Version $Version @iconArgs -Verbose 4>&1 | Tee-Object .\dist\build.log

"Done: $OutExe"
