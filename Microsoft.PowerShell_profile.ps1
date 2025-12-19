# PROMPT THEMES  --------------------------------------
oh-my-posh init pwsh --config "$env:USERPROFILE/Documents/PowerShell/powershell_profile.json" | Invoke-Expression


# USE SECURITY PROTOCOL TLS 1.2  --------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# ALIASES  --------------------------------------
Set-Alias -Name gpull -Value Update-GitRepositories


# MODULES  --------------------------------------
# -- Terminal Icons
Import-Module Terminal-Icons

# -- PSReadLine
Import-Module PSReadLine
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineOption -PredictionViewStyle ListView


# GLOBAL VARIABLES  --------------------------------------
$Global:TerminalWidth = 100


# BOOTSTRAP & INITIALIZATION --------------------------------------
$BootstrapFolders = "Paths", "Utils", "Services"

foreach ($Folder in $BootstrapFolders) {
  $FolderPath = Join-Path $PSScriptRoot $Folder

  if (Test-Path $FolderPath) {
    # Get all .ps1 scripts from folder
    Get-ChildItem -Path $FolderPath -Filter *.ps1 | ForEach-Object {
      . $_.FullName
    }
  }
}

# STARTUP LOGIC --------------------------------------
Set-LoadGlobalGitIgnore
