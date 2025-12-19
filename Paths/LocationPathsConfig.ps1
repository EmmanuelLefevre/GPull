function Get-LocationPathConfig {
  # IsRepo = $true   => Included in Update-GitRepositories() process AND accessible via go()
  # IsRepo = $false  => Accessible ONLY via go() function

  # IsOnlyMain = $true   => only pull main branch
  # IsOnlyMain = $false  => pull all branches

  # Get system context
  $Sys = Get-SystemContext

  # Definition of universal root folders
  # Join-Path automatically handles "/"" or "\"" depending on specific OS
  $DesktopPath   = Join-Path $HOME "Desktop"
  $ProjectsPath  = Join-Path $DesktopPath "Projects"
  $DocumentsPath = Join-Path $HOME "Documents"
  $PicturesPath  = Join-Path $HOME "Pictures"

  # For nvim, path changes depending on OS
  if ($Sys.IsMacOS -or $Sys.IsLinux) {
    $NvimPath = Join-Path $HOME ".config/nvim"
  }
  else {
    $NvimPath = Join-Path $env:LOCALAPPDATA "nvim"
  }

  return @(
    ##########---------- REPOSITORIES (Important order for Update-GitRepositories() function) ----------##########
    [PSCustomObject]@{ Name = "<YOUR_REPOSITORIES>";   Path = Join-Path $ProjectsPath   "<YOUR_REPOSITORIES>";   IsRepo = $true;   IsOnlyMain = $false },
    [PSCustomObject]@{ Name = "<YOUR_DOCUMENTS>";      Path = Join-Path $DocumentsPath  "<YOUR_DOCUMENTS>";      IsRepo = $true;   IsOnlyMain = $true  },
    [PSCustomObject]@{ Name = "<YOUR_PICTURES>";       Path = Join-Path $PicturesPath   "<YOUR_PICTURES>";       IsRepo = $true;   IsOnlyMain = $true  },
    [PSCustomObject]@{ Name = "<YOUR_DESKTOP>";        Path = Join-Path $DesktopPath    "<YOUR_DESKTOP>";        IsRepo = $true;   IsOnlyMain = $true  },

    ##########---------- NAVIGATION ONLY (go() function) ----------##########
    [PSCustomObject]@{ Name = "desk";                  Path = $DesktopPath;                  IsRepo = $false },
    [PSCustomObject]@{ Name = "dwld";                  Path = Join-Path $HOME "Downloads";   IsRepo = $false },
    [PSCustomObject]@{ Name = "home";                  Path = $HOME;                         IsRepo = $false },
    [PSCustomObject]@{ Name = "nvim";                  Path = $NvimPath;                     IsRepo = $false },
    [PSCustomObject]@{ Name = "prof";                  Path = Split-Path $PROFILE -Parent;   IsRepo = $false },
    [PSCustomObject]@{ Name = "prj";                   Path = $ProjectsPath;                 IsRepo = $false }
  )
}
