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

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-Repo` | `owner/repo` (optional if `-RepoListPath` or `-ChooseRepo` is used) |
| `-Ref` | Branch, tag, or commit SHA. Combine with `-ChooseBranch` or `-LatestPR` to resolve automatically. |
| `-OutputDir` | Target folder for the ZIP archive. Defaults to the user's Downloads folder. |
| `-RepoListPath` | File containing `owner/repo` entries (one per line) for quick selection. |
| `-ChooseRepo` | Interactively select a repository from your `gh repo list` output. |
| `-ChooseBranch` | Interactively choose a branch after selecting a repository. |
| `-LatestPR` | Use the head branch of the latest open pull request if one exists. |

## Examples

Download default branch:

```powershell
.\Get-GitHubRepoZip.ps1 alweiz/github-repo-zip-downloader
```

Download specific branch to custom folder:

```powershell
.\Get-GitHubRepoZip.ps1 alweiz/github-repo-zip-downloader main "D:\Downloads"
```

## GUI

A simple Windows Forms front end is also included:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-GitHubRepoZip.UI.ps1
```

It lets you pick the repository, branch (including the latest PR head), and output folder through dropdowns.

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
