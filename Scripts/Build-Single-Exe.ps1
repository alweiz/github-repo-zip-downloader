param(
  [string]$UiPath   = ".\Get-GitHubRepoZip.UI.ps1",
  [string]$CorePath = ".\lib\Get-GitHubRepoZip.Core.ps1",
  [string]$OutExe   = ".\dist\GithubRepoZip.exe",
  [string]$Icon     = ".\assets\app.ico",
  [string]$Product  = "GitHub Repo Zip Downloader",
  [string]$Company  = "alweiz",
  [string]$Version  = "1.1.1.0"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path (Split-Path $OutExe) | Out-Null
$temp = Join-Path (Split-Path $OutExe) "Get-GitHubRepoZip.packed.ps1"

$ui   = Get-Content $UiPath   -Raw -Encoding UTF8
$core = Get-Content $CorePath -Raw -Encoding UTF8

# UI の dot-source 行を Core の中身へ置換（行全体）
$pattern = '^\s*\.\s*.*Get-GitHubRepoZip\.Core\.ps1.*$'
$packed  = [regex]::Replace($ui, $pattern, $core, 'Multiline')
Set-Content -Path $temp -Value $packed -Encoding UTF8

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
  Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}

Invoke-ps2exe -InputFile $temp -OutputFile $OutExe -NoConsole `
  -Title $Product -Product $Product -Company $Company `
  -Version $Version `
  $(if (Test-Path $Icon) { @('-Icon', $Icon) }) -Verbose 4>&1 | Tee-Object .\dist\build.log
