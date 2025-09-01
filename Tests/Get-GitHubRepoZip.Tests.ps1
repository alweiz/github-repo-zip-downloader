#Requires -Version 5.1
# Pester v5。事前に: gh auth login
# 実行: Invoke-Pester -Path .\Tests -CI -Output Detailed

# ===== グローバル関数（どのブロックスコープでも可視） =====
function global:Resolve-TempRoot {
    $c = @(
        ([System.IO.Path]::GetTempPath()),
        $env:TEMP, $env:TMP,
        ($(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Temp' } else { $null })),
        ($(if ($env:USERPROFILE)  { Join-Path $env:USERPROFILE  'AppData\Local\Temp' } else { $null })),
        'C:\Windows\Temp'
    ) | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($p in $c) {
        try {
            if (Test-Path -LiteralPath $p) { return (Resolve-Path $p).Path }
            $parent = Split-Path -Parent $p
            if ($parent -and (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $p -Force | Out-Null
                return (Resolve-Path $p).Path
            }
        } catch {}
    }
    throw 'Could not resolve a writable temp directory.'
}

function global:Invoke-GrzdCli {
    param(
        [Parameter(Mandatory)][string]$CliPath,
        [Parameter(Mandatory)][string[]]$CliArgs
    )
    $quotedCli = ('"{0}"' -f $CliPath)
    $parts = @($quotedCli) + $CliArgs
    $cmd = '& ' + ($parts -join ' ')
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1
    return $out
}

function global:Invoke-GrzdCliProcess {
    param(
        [Parameter(Mandatory)][string]$CliPath,
        [Parameter(Mandatory)][string[]]$CliArgs
    )
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $CliPath) + $CliArgs
    $p = Start-Process -FilePath powershell -ArgumentList $argList -PassThru -Wait -NoNewWindow
    return $p.ExitCode
}

# ===== パス解決（script: に固定して It から必ず参照可能に） =====
try {
    if ($PSCommandPath) {
        $script:TestRoot = Split-Path -Parent $PSCommandPath
    } elseif ($MyInvocation.PSCommandPath) {
        $script:TestRoot = Split-Path -Parent $MyInvocation.PSCommandPath
    } elseif ($PSScriptRoot) {
        $script:TestRoot = $PSScriptRoot
    } else {
        $script:TestRoot = (Resolve-Path '.').Path
    }
} catch { $script:TestRoot = (Resolve-Path '.').Path }

$script:RepoRootGuess = [System.IO.Path]::GetFullPath((Join-Path $script:TestRoot '..'))
$CliCandidates = @(
    (Join-Path $script:RepoRootGuess 'Get-GitHubRepoZip.ps1'),
    (Join-Path $script:TestRoot     '..\Get-GitHubRepoZip.ps1'),
    (Join-Path (Get-Location)       'Get-GitHubRepoZip.ps1')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

if ($CliCandidates.Count -eq 0) {
    throw "Get-GitHubRepoZip.ps1 not found. Looked in:`n - $script:RepoRootGuess`n - $script:TestRoot\..\`n - $(Get-Location)"
}
$script:Cli = (Resolve-Path $CliCandidates[0]).Path

$script:TempRoot = Resolve-TempRoot
$script:OutDir   = Join-Path $script:TempRoot ('GRZD.Tests.' + [Guid]::NewGuid().ToString('N'))

Write-Host "[Tests] TestRoot: $script:TestRoot"
Write-Host "[Tests] RepoRootGuess: $script:RepoRootGuess"
Write-Host "[Tests] CLI: $script:Cli"
Write-Host "[Tests] TempRoot: $script:TempRoot"
Write-Host "[Tests] OutDir  : $script:OutDir"

# gh 利用可否（script: に固定）
$script:GhAvailable = $false
try {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh --version   | Out-Null
        gh auth status | Out-Null
        $script:GhAvailable = $true
    }
} catch { $script:GhAvailable = $false }

if (-not $script:GhAvailable) {
    Write-Warning 'gh is not available or not authenticated. Skipping E2E tests.'
}

# ===== 準備/後片付け =====
BeforeAll {
    # OutDir が未初期化/空なら再作成（スコープ耐性）
    if (-not $script:OutDir -or [string]::IsNullOrWhiteSpace($script:OutDir)) {
        $script:TempRoot = Resolve-TempRoot
        $script:OutDir   = Join-Path $script:TempRoot ('GRZD.Tests.' + [Guid]::NewGuid().ToString('N'))
        Write-Host "[Tests] Recreated OutDir in BeforeAll: $script:OutDir"
    }
    [System.IO.Directory]::CreateDirectory($script:OutDir) | Out-Null
    Get-ChildItem -LiteralPath $script:OutDir -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

AfterAll {
    if ($script:OutDir) {
        try { Remove-Item -LiteralPath $script:OutDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}

# ===== 本体テスト =====
Describe 'Get-GitHubRepoZip CLI E2E' -Skip:(-not $script:GhAvailable) {

    It 'downloads default branch ZIP of this repo' {
        [System.IO.Directory]::CreateDirectory($script:OutDir) | Out-Null  # 保険
        $repo = 'alweiz/github-repo-zip-downloader'
        $out = Invoke-GrzdCli -CliPath $script:Cli -CliArgs @('-Repo', $repo, '-OutputDir', $script:OutDir)
        $out | Out-Host  # デバッグ

        $m = ($out | Select-String -Pattern '^Saved:\s+(.+)$' | Select-Object -First 1)
        $m | Should -Not -BeNullOrEmpty
        $savedPath = $m.Matches[0].Groups[1].Value.Trim()
        Test-Path -LiteralPath $savedPath | Should -BeTrue
        (Get-Item $savedPath).Length | Should -BeGreaterThan 1024
    }

    It 'downloads a specific ref (main)' {
        [System.IO.Directory]::CreateDirectory($script:OutDir) | Out-Null
        $repo = 'alweiz/github-repo-zip-downloader'
        $out = Invoke-GrzdCli -CliPath $script:Cli -CliArgs @('-Repo', $repo, '-Ref', 'main', '-OutputDir', $script:OutDir)
        $m = ($out | Select-String -Pattern '^Saved:\s+(.+)$' | Select-Object -First 1)
        $m | Should -Not -BeNullOrEmpty
        $savedPath = $m.Matches[0].Groups[1].Value.Trim()
        $savedPath | Should -Match '-main-'
        Test-Path -LiteralPath $savedPath | Should -BeTrue
    }

    It 'downloads latest PR head when available' -Skip:(-not ( (gh pr list -R 'alweiz/github-repo-zip-downloader' --state open --limit 1 | Out-String).Trim() )) {
        [System.IO.Directory]::CreateDirectory($script:OutDir) | Out-Null
        $repo = 'alweiz/github-repo-zip-downloader'
        $out = Invoke-GrzdCli -CliPath $script:Cli -CliArgs @('-Repo', $repo, '-LatestPR', '-OutputDir', $script:OutDir)
        $m = ($out | Select-String -Pattern '^Saved:\s+(.+)$' | Select-Object -First 1)
        $m | Should -Not -BeNullOrEmpty
        $savedPath = $m.Matches[0].Groups[1].Value.Trim()
        $savedPath | Should -Not -Match '-main-'
        Test-Path -LiteralPath $savedPath | Should -BeTrue
    }

    It 'fails clearly for a non-existing repository' {
        [System.IO.Directory]::CreateDirectory($script:OutDir) | Out-Null
        $repo = 'alweiz/this-repo-does-not-exist-xyz'
        $exit = Invoke-GrzdCliProcess -CliPath $script:Cli -CliArgs @('-Repo', $repo, '-OutputDir', $script:OutDir)
        $exit | Should -Not -Be 0
    }
}
