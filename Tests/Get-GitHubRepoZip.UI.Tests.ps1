#Requires -Version 5.1
# Pester v5
# Ensures GUI form and controls instantiate correctly.

Describe 'Get-GitHubRepoZip UI basic construction' -Skip:([System.Environment]::OSVersion.Platform -ne 'Win32NT') {
    It 'creates main form and controls without showing UI' {
        $scriptPath = Join-Path $PSScriptRoot '..\Get-GitHubRepoZip.UI.ps1'
        $content = Get-Content -Path $scriptPath -Raw
        $content = $content -replace 'Test-GhAuth',''
        $content = $content -replace '\$btnRefreshRepos\.PerformClick\(\)\s*\|\s*Out-Null',''
        $content = $content -replace '\[void\]\$form\.ShowDialog\(\)',''
        $uiScriptDir = Split-Path $scriptPath
        Push-Location $uiScriptDir
        try {
            # Load core functions needed by UI
            $corePath = Join-Path $uiScriptDir 'lib\Get-GitHubRepoZip.Core.ps1'
            if (Test-Path -LiteralPath $corePath) {
                . $corePath
            }
            Invoke-Expression $content
        }
        finally {
            Pop-Location
        }

        $form | Should -Not -BeNullOrEmpty
        $form.Text | Should -Be 'GitHub Repo ZIP Downloader'
        $btnDownload | Should -Not -BeNullOrEmpty
        $btnDownload.Text | Should -Be 'Download'
        $form.Dispose()
    }
}
