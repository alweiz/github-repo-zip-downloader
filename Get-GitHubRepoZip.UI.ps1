#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
# Resolve path to core script even if $PSScriptRoot is empty
$scriptDir = if($PSScriptRoot){ $PSScriptRoot } else { (Get-Location).Path }

# Core がインライン済みなら外部 Core を探さない
if (-not (Get-Command Test-GhAuth -ErrorAction SilentlyContinue)) {
  # Resolve path to core script even if $PSScriptRoot is empty
  $scriptDir = if($PSScriptRoot){ $PSScriptRoot } else { (Get-Location).Path }

  # lib 配下に移動した Core を参照
  $corePath  = Join-Path $scriptDir 'lib\Get-GitHubRepoZip.Core.ps1'
  if(-not (Test-Path -LiteralPath $corePath)){
    # fallback: 親ディレクトリから lib を参照
    $corePath = Join-Path (Split-Path -Parent $scriptDir) 'lib\Get-GitHubRepoZip.Core.ps1'
  }
  if(-not (Test-Path -LiteralPath $corePath)){
    throw 'lib/Get-GitHubRepoZip.Core.ps1 not found.'
  }
  . $corePath
}

Test-GhAuth

function Show-Error($msg){ [System.Windows.Forms.MessageBox]::Show($msg,'Error','OK','Error') | Out-Null }

$form = New-Object System.Windows.Forms.Form
$form.Text = 'GitHub Repo ZIP Downloader'
$form.Size = New-Object System.Drawing.Size(640,340)
$form.StartPosition = 'CenterScreen'
$form.MaximizeBox = $false

$lblRepo = New-Object System.Windows.Forms.Label; $lblRepo.Text='Repository'; $lblRepo.Location='20,20'; $lblRepo.AutoSize=$true
$cmbRepo = New-Object System.Windows.Forms.ComboBox; $cmbRepo.Location='20,45'; $cmbRepo.Size='460,24'; $cmbRepo.DropDownStyle='DropDownList'
$btnRefreshRepos = New-Object System.Windows.Forms.Button; $btnRefreshRepos.Text='Refresh'; $btnRefreshRepos.Location='500,44'; $btnRefreshRepos.Size='100,26'

$lblBranch = New-Object System.Windows.Forms.Label; $lblBranch.Text='Branch'; $lblBranch.Location='20,85'; $lblBranch.AutoSize=$true
$cmbBranch = New-Object System.Windows.Forms.ComboBox; $cmbBranch.Location='20,110'; $cmbBranch.Size='460,24'; $cmbBranch.DropDownStyle='DropDownList'
$btnLoadBranches = New-Object System.Windows.Forms.Button; $btnLoadBranches.Text='Load branches'; $btnLoadBranches.Location='500,109'; $btnLoadBranches.Size='100,26'

$chkLatestPR = New-Object System.Windows.Forms.CheckBox; $chkLatestPR.Text='Use latest open PR branch (if any)'; $chkLatestPR.Location='20,145'; $chkLatestPR.AutoSize=$true

$lblOut = New-Object System.Windows.Forms.Label; $lblOut.Text='Output folder'; $lblOut.Location='20,180'; $lblOut.AutoSize=$true
$txtOut = New-Object System.Windows.Forms.TextBox; $txtOut.Location='20,205'; $txtOut.Size='460,24'; $txtOut.Text=(Get-DownloadsPath)
$btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text='Browse...'; $btnBrowse.Location='500,204'; $btnBrowse.Size='100,26'

$btnDownload = New-Object System.Windows.Forms.Button; $btnDownload.Text='Download'; $btnDownload.Location='380,250'; $btnDownload.Size='100,30'
$btnClose = New-Object System.Windows.Forms.Button; $btnClose.Text='Close'; $btnClose.Location='500,250'; $btnClose.Size='100,30'

$form.Controls.AddRange(@($lblRepo,$cmbRepo,$btnRefreshRepos,$lblBranch,$cmbBranch,$btnLoadBranches,$chkLatestPR,$lblOut,$txtOut,$btnBrowse,$btnDownload,$btnClose))

function Update-RepoCombo {
  $form.Cursor='WaitCursor'
  try {
    $repos = Get-RepoList
    $cmbRepo.Items.Clear()
    foreach($r in $repos){ [void]$cmbRepo.Items.Add($r) }
    if($cmbRepo.Items.Count -gt 0 -and $cmbRepo.SelectedIndex -lt 0){ $cmbRepo.SelectedIndex=0 }
  } catch { Show-Error($_.Exception.Message) } finally { $form.Cursor='Default' }
}

function Update-BranchCombo {
  if(-not $cmbRepo.SelectedItem){ return }
  $repo = [string]$cmbRepo.SelectedItem
  $form.Cursor='WaitCursor'
  try {
    $cmbBranch.Items.Clear()
    if($chkLatestPR.Checked){
      $pr = Get-LatestOpenPrHead -Repo $repo
      if($pr){ [void]$cmbBranch.Items.Add($pr) }
    }
    if($cmbBranch.Items.Count -eq 0){
      $branches = Get-Branches -Repo $repo
      foreach($b in $branches){ [void]$cmbBranch.Items.Add($b) }
    }
    if($cmbBranch.Items.Count -eq 0){
      $def = Get-DefaultBranch -Repo $repo
      if($def){ [void]$cmbBranch.Items.Add($def) }
    }
    if($cmbBranch.Items.Count -gt 0){ $cmbBranch.SelectedIndex=0 }
  } catch { Show-Error($_.Exception.Message) } finally { $form.Cursor='Default' }
}

$btnRefreshRepos.Add_Click({ Update-RepoCombo })
$btnLoadBranches.Add_Click({ Update-BranchCombo })
$cmbRepo.Add_SelectedIndexChanged({ Update-BranchCombo })
$chkLatestPR.Add_CheckedChanged({ Update-BranchCombo })

$btnBrowse.Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description='Select output folder'
  $dlg.SelectedPath=$txtOut.Text
  if($dlg.ShowDialog() -eq 'OK'){ $txtOut.Text=$dlg.SelectedPath }
})

$btnDownload.Add_Click({
  if(-not $cmbRepo.SelectedItem){ Show-Error('Select a repository.'); return }
  $repo = [string]$cmbRepo.SelectedItem
  $ref  = if($cmbBranch.SelectedItem){ [string]$cmbBranch.SelectedItem } else { $null }
  $dir  = $txtOut.Text
  $form.Cursor='WaitCursor'
  try {
    $saved = Invoke-ZipballDownload -Repo $repo -Ref $ref -OutputDir $dir
    [System.Windows.Forms.MessageBox]::Show(('Saved: ' + $saved),'Done','OK','Information') | Out-Null
    Start-Process explorer.exe $dir | Out-Null
  } catch { Show-Error($_.Exception.Message) } finally { $form.Cursor='Default' }
})

$btnClose.Add_Click({ $form.Close() })

# 初期化（起動時にリポジトリとブランチ候補を自動取得）
Update-RepoCombo
Update-BranchCombo

# 互換: 以前のテストがこの行を正規表現で除去するため残しても副作用なし
$btnRefreshRepos.PerformClick() | Out-Null
[void]$form.ShowDialog()
