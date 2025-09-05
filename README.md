# GitHub Repo ZIP Downloader

PowerShell だけで **GitHub リポジトリの最新ソース ZIP** を素早く取得する軽量スクリプト集。  
内部で GitHub CLI (`gh auth token`) を使用し **PAT 不要 / 認証管理不要**。

## 特長 (Features)
- 単一スクリプト実行で ZIP 取得（[`Get-GitHubRepoZip.ps1`](Get-GitHubRepoZip.ps1)）
- Windows Forms GUI（[`Get-GitHubRepoZip.UI.ps1`](Get-GitHubRepoZip.UI.ps1)）は起動時に
  - リポジトリ一覧自動取得（`gh repo list`）
  - 先頭リポジトリのブランチ候補自動取得（PR ヘッド含む）
- 最新オープン PR の head ブランチを自動選択（`-LatestPR` / [`Get-LatestOpenPrHead`](lib/Get-GitHubRepoZip.Core.ps1)）
- ブランチ / タグ / SHA 任意指定
- 出力先フォルダ自動解決（ユーザーの Downloads 実パス: [`Get-DownloadsPath`](lib/Get-GitHubRepoZip.Core.ps1)）
- 厳格エラーチェック（HTTP ステータス / HTML 誤保存検出）
- Pester による Unit + E2E テスト

## Requirements
- Windows PowerShell 5.1 以上 または PowerShell 7+
- [GitHub CLI (gh)](https://cli.github.com/) インストール & `gh auth login`
  - CI では `GITHUB_TOKEN` を利用（`tests.yml` 参照）

## クイックスタート (Quick Start)
```powershell
# 1. リポジトリを取得
git clone https://github.com/alweiz/github-repo-zip-downloader.git
cd github-repo-zip-downloader

# 2. 既定ブランチ ZIP をダウンロード
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-GitHubRepoZip.ps1 alweiz/github-repo-zip-downloader

# 3. GUI
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-GitHubRepoZip.UI.ps1
```

## CLI 使い方
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-GitHubRepoZip.ps1 -Repo owner/repo [-Ref branch|tag|sha] [-OutputDir path] [-LatestPR] [-ChooseRepo] [-ChooseBranch] [-RepoListPath file]
```

### 主なパラメータ
| パラメータ | 説明 |
|-----------|------|
| `-Repo` | `owner/repo`。`-ChooseRepo` / `-RepoListPath` で代替可 |
| `-Ref` | ブランチ / タグ / コミット SHA。省略時は `-LatestPR` / `-ChooseBranch` / 既定ブランチ解決 |
| `-OutputDir` | ZIP 保存先。省略時は Downloads |
| `-RepoListPath` | 行ごとに `owner/repo` を記述したファイル（`#` 先頭はコメント） |
| `-ChooseRepo` | 対話メニューでリポジトリ選択（`gh repo list` 100件） |
| `-ChooseBranch` | 対話メニューでブランチ選択（[`Get-Branches`](lib/Get-GitHubRepoZip.Core.ps1)） |
| `-LatestPR` | 最新 Open PR の head ブランチを優先（無ければスキップ終了） |

### 例
```powershell
# 既定ブランチ
.\Get-GitHubRepoZip.ps1 -Repo alweiz/github-repo-zip-downloader

# ブランチ指定
.\Get-GitHubRepoZip.ps1 -Repo alweiz/github-repo-zip-downloader -Ref main -OutputDir D:\Downloads

# 最新 PR head (PR 無ければ exit code 3)
.\Get-GitHubRepoZip.ps1 -Repo alweiz/github-repo-zip-downloader -LatestPR

# 対話選択（リポジトリ → ブランチ）
.\Get-GitHubRepoZip.ps1 -ChooseRepo -ChooseBranch
```

## Exit Codes
| Code | 意味 |
|------|------|
| 0 | 正常終了 |
| 1 | 一般的な失敗（入力エラー / HTTP エラー等） |
| 3 | 条件未成立（例: `-LatestPR` 指定だがオープン PR なし） |

## 内部コア関数
| 関数 | 役割 |
|------|------|
| [`Test-GhAuth`](lib/Get-GitHubRepoZip.Core.ps1) | gh 存在 & 認証確認 |
| [`Invoke-ZipballDownload`](lib/Get-GitHubRepoZip.Core.ps1) | ZIP 取得メイン（HTTP / 検証） |
| [`Get-RepoList`](lib/Get-GitHubRepoZip.Core.ps1) | 最近更新順リポ一覧 |
| [`Get-Branches`](lib/Get-GitHubRepoZip.Core.ps1) | ブランチ一覧（存在しない commit 情報を安全参照） |
| [`Get-DefaultBranch`](lib/Get-GitHubRepoZip.Core.ps1) | 既定ブランチ取得 |
| [`Get-LatestOpenPrHead`](lib/Get-GitHubRepoZip.Core.ps1) | 最新 Open PR head ブランチ |
| [`Get-DownloadsPath`](lib/Get-GitHubRepoZip.Core.ps1) | Downloads 実パス取得 |

## GUI
実行:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-GitHubRepoZip.UI.ps1
```
起動時に:
1. リポジトリ一覧を即時取得（コンボへ投入）
2. 先頭リポのブランチ候補を取得（`Use latest open PR branch` チェック時は PR head を先頭候補）
3. 保存先は自動で Downloads

ブランチリストは:
1. チェック有りかつ PR head 存在 → それを追加
2. 通常ブランチ一覧
3. 取得できなければ既定ブランチフォールバック

## テスト
Pester 5 を使用（[Tests/](Tests/)）。
- Unit: [`Get-Branches.Tests.ps1`](Tests/Get-Branches.Tests.ps1)
- E2E: [`Get-GitHubRepoZip.Tests.ps1`](Tests/Get-GitHubRepoZip.Tests.ps1), [`Get-GitHubRepoZip.UI.Tests.ps1`](Tests/Get-GitHubRepoZip.UI.Tests.ps1)

ローカル:
```powershell
Invoke-Pester -Path .\Tests -CI -Output Detailed
```

gh 未認証・未インストールの場合 E2E は自動 Skip。

CI: GitHub Actions ([.github/workflows/tests.yml](.github/workflows/tests.yml))

生成された NUnit 形式結果: `testResults.xml`（.gitignore 済み）

## 開発 (Development)
- 主要ロジック: [`Get-GitHubRepoZip.Core.ps1`](lib/Get-GitHubRepoZip.Core.ps1)
- CLI エントリ: [`Get-GitHubRepoZip.ps1`](Get-GitHubRepoZip.ps1)
- UI エントリ: [`Get-GitHubRepoZip.UI.ps1`](Get-GitHubRepoZip.UI.ps1)

改善アイデア（今後）:
- モジュール化 & `psd1` 化
- HTTP リトライ / RateLimit 考慮
- キャッシュ（リポ / ブランチ）短期保存
- PowerShell Gallery 公開

## トラブルシュート
| 症状 | 対処 |
|------|------|
| `gh not found` | GitHub CLI をインストール（例: `winget install GitHub.cli -e`） |
| `Run: gh auth login` | `gh auth login` 実行（CI は `GITHUB_TOKEN`） |
| HTML を ZIP として保存 | 出力 ZIP が 0.5KB 未満の場合自動検出し削除、Ref / 権限を確認 |

## ライセンス
MIT （[LICENSE](LICENSE)）

## Contributing
Issue / PR 歓迎。小さく焦点を絞った変更を推奨。

---
Made with PowerShell