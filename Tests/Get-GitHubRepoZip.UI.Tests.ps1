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
        $PSScriptRoot = Split-Path $scriptPath
        Invoke-Expression $content

        $form | Should -Not -BeNullOrEmpty
        $form.Text | Should -Be 'GitHub Repo ZIP Downloader'
        $btnDownload | Should -Not -BeNullOrEmpty
        $btnDownload.Text | Should -Be 'Download'
        $form.Dispose()
    }
}
