#Requires -Version 5.1
Describe 'Get-Branches' {
    It 'returns branch names even when commit info missing' {
    $core = Join-Path (Join-Path $PSScriptRoot '..') 'lib\Get-GitHubRepoZip.Core.ps1'
        . $core
        Mock -CommandName gh -MockWith {
            return '[{"name":"main","commit":{"commit":{"author":{"date":"2020-01-01T00:00:00Z"}}}}, {"name":"empty-branch"}]'
        }
        $branches = Get-Branches -Repo 'dummy/repo'
        $branches | Should -Contain 'main'
        $branches | Should -Contain 'empty-branch'
    }
}
