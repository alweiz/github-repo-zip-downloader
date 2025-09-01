# GitHub Repo ZIP Downloader

A simple PowerShell script to download the latest source code of public/private GitHub repositories as a ZIP archive.  
Uses `gh auth token` internally, so no need to manage PATs in your script.

## Requirements
- Windows PowerShell 5.1+ (or PowerShell 7+)
- [GitHub CLI (`gh`)](https://cli.github.com/) and `gh auth login`

## Usage

Run from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-GitHubRepoZip.ps1 owner/repo [branch-or-tag] [output-folder]
```

## Examples

Download default branch:

```powershell
.\Get-GitHubRepoZip.ps1 alweiz/github-repo-zip-downloader
```

Download specific branch to custom folder:

```powershell
.\Get-GitHubRepoZip.ps1 alweiz/github-repo-zip-downloader main "D:\Downloads"
```

## Notes
- If `[branch-or-tag]` is omitted, the default branch’s latest is downloaded.
- The script auto-detects the real **Downloads** folder location via registry (works even if moved to D:).

## Why
- One-click way to fetch the freshest ZIP for private repos without opening GitHub in a browser.
- No need to embed a PAT; uses `gh auth token` at runtime.

## License
MIT

## Contributing

Issues and pull requests are welcome!  
- Found a bug? Please open an Issue.  
- Have an idea for improvement? Feel free to send a Pull Request.  

This project is kept simple, so please keep changes small and focused.

## Tests
This repo uses Pester for CLI E2E tests.

- Local: `Invoke-Pester -Path .\Tests -CI`
- CI: GitHub Actions runs tests on push/PR (uses `GITHUB_TOKEN` for `gh`).
