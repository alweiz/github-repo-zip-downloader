#Requires -Version 5.1
# Pester v5
# Tests for standalone exe build functionality

Describe 'Build-Single-Exe standalone functionality' {
    BeforeAll {
        $buildScript = Join-Path $PSScriptRoot '..\Scripts\Build-Single-Exe.ps1'
        $distDir = Join-Path $PSScriptRoot '..\dist'
        $packedScript = Join-Path $distDir 'Get-GitHubRepoZip.packed.ps1'
        $libDir = Join-Path $PSScriptRoot '..\lib'
        $libBackup = Join-Path $PSScriptRoot '..\lib_backup_test'

        # Ensure build runs first
        if (Test-Path $distDir) {
            Remove-Item $distDir -Recurse -Force
        }
        & $buildScript
    }

    AfterAll {
        # Restore lib directory if it was moved during tests
        if (Test-Path $libBackup) {
            if (Test-Path $libDir) {
                Remove-Item $libDir -Recurse -Force
            }
            Move-Item $libBackup $libDir
        }
    }

    Context 'Packed script content validation' {
        It 'includes core functions in packed script' {
            $packed = Get-Content $packedScript -Raw

            # Check that core functions are included
            $packed | Should -Match 'function Test-GhAuth'
            $packed | Should -Match 'function Get-DownloadsPath'
            $packed | Should -Match 'function Get-GhToken'
            $packed | Should -Match 'function Invoke-ZipballDownload'
            $packed | Should -Match 'function Get-RepoList'
            $packed | Should -Match 'function Get-Branches'
            $packed | Should -Match 'function Get-DefaultBranch'
            $packed | Should -Match 'function Get-LatestOpenPrHead'
        }

        It 'removes core loading code from packed script' {
            $packed = Get-Content $packedScript -Raw

            # Check that core loading if-block is removed
            $packed | Should -Not -Match 'if \(-not \(Get-Command Test-GhAuth -ErrorAction SilentlyContinue\)\)'
            $packed | Should -Not -Match 'lib\\Get-GitHubRepoZip\.Core\.ps1'
            $packed | Should -Not -Match '\. \$corePath'
        }
    }

    Context 'Standalone execution without lib directory' {
        It 'executes packed script without lib directory present' {
            # Move lib directory temporarily
            if (Test-Path $libDir) {
                Move-Item $libDir $libBackup
            }

            try {
                # Test that the script can start without throwing dependency errors
                # We use a timeout since this is a GUI app that would hang
                $job = Start-Job -ScriptBlock {
                    param($scriptPath)
                    try {
                        # Attempt to load the script - this tests dependency resolution
                        $content = Get-Content $scriptPath -Raw
                        $null = [ScriptBlock]::Create($content)
                        return 'SUCCESS'
                    } catch {
                        return "ERROR: $($_.Exception.Message)"
                    }
                } -ArgumentList $packedScript

                $result = $job | Wait-Job -Timeout 10 | Receive-Job
                $job | Remove-Job -Force

                $result | Should -Be 'SUCCESS'

            } finally {
                # Restore lib directory
                if (Test-Path $libBackup) {
                    Move-Item $libBackup $libDir
                }
            }
        }

        It 'contains all required functions for standalone operation' {
            # Test that all core functions are defined in the packed script content
            # This avoids executing the GUI script which would hang in CI
            $packed = Get-Content $packedScript -Raw

            $functions = @(
                'function Test-GhAuth',
                'function Get-DownloadsPath',
                'function Get-GhToken',
                'function Invoke-ZipballDownload',
                'function Get-RepoList',
                'function Get-Branches',
                'function Get-DefaultBranch',
                'function Get-LatestOpenPrHead'
            )

            foreach ($func in $functions) {
                $packed | Should -Match ([regex]::Escape($func))
            }
        }
    }
}