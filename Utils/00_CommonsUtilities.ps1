##########---------- Clear ----------##########
function c {
  clear
}

##########----------Display current directory path ----------##########
function path {
  Write-Host ""
  $currentPath = Get-Location
  Write-Host $currentPath -ForegroundColor DarkMagenta
}

##########---------- Navigate to specified folder passed as a parameter ----------##########
##########---------- Or returns to parent directory if no paramater ----------##########
function z {
  param (
    [string]$folder
  )

  # If no parameter is specified, returns to parent directory
  if (!$folder) {
    Set-Location ..
    return
  }

  # Resolve relative or absolute folder path
  $path = Resolve-Path -Path $folder -ErrorAction SilentlyContinue

  if ($path) {
    Set-Location -Path $path
  }
  else {
    Write-Host -NoNewline "⚠️ Folder " -ForegroundColor Red
    Write-Host -NoNewline "$folder" -ForegroundColor Magenta
    Write-Host " not found ⚠️" -ForegroundColor Red
  }
}

##########---------- Create a file ----------##########
function touch {
  param (
    [string]$path
  )

  # If file does not exist, create it
  if (-not (Test-Path -Path $path)) {
    New-Item -Path $path -ItemType File
  }
  # Display message if file already exists
  else {
    Show-GracefulError -Message "⚠️ File already exists ⚠️" -NoCenter
  }
}

##########---------- Jump to a specific directory ----------##########
function go {
  param (
    [string]$location
  )

  ######## GUARD CLAUSE : MISSING ARGUMENT ########
  if (-not $location) {
    Show-GracefulError -Message "⚠️ Invalid option! Type 'go help'..." -NoCenter
    return
  }

  ######## LOAD CONFIG ########
  $allLocations = Get-LocationPathConfig

  ######## GUARD CLAUSE : CONFIGURATION ERROR ########
  if (-not $allLocations) {
    Show-GracefulError -Message "❌ Critical Error : Get-LocationPathConfig returned no data !" -NoCenter
    return
  }

  ######## HELP MODE ########
  if ($location -eq "help") {
    Write-Host ""
    Write-Host ("{0,-27} {1,-60}" -f "Alias", "Path") -ForegroundColor White -BackgroundColor DarkGray

    # Alphabetical sorting
    foreach ($option in ($allLocations | Sort-Object Name)) {
      # Icon to differentiate Repo vs Folder
      $icon = if($option.IsRepo){"󰊤"}else{""}

      if ($option.Name -ne "help") {
        Write-Host -NoNewline ("{0,-28}" -f "$($option.Name)") -ForegroundColor Magenta
        Write-Host ("{0,-60}" -f "$icon $($option.Path)") -ForegroundColor DarkCyan
      }
    }

    Write-Host ""
    return
  }

  ######## NAVIGATION MODE ########
  # Search (Case Insensitive by default in PowerShell)
  $target = $allLocations | Where-Object { $_.Name -eq $location } | Select-Object -First 1

  ######## GUARD CLAUSE : ALIAS NOT FOUND ########
  if (-not $target) {
    Write-Host -NoNewline "⚠️ Alias " -ForegroundColor Red
    Write-Host -NoNewline "`"$($location)`"" -ForegroundColor Magenta
    Write-Host " not found in configuration !" -ForegroundColor Red
    Write-Host "   └─> Type 'go help' to see available options..." -ForegroundColor DarkYellow
    return
  }

  if (Test-Path -Path $target.Path) {
    Set-Location -Path $target.Path
  }
  else {
    Write-Host -NoNewline "⚠️ Path defined for alias " -ForegroundColor Red
    Write-Host -NoNewline "'$location'" -ForegroundColor Magenta
    Write-Host " does not exist on disk !" -ForegroundColor Red
    Write-Host -NoNewline "   └─> Non-existent path : " -ForegroundColor DarkYellow
    Write-Host -NoNewline "`"$($target.Path)`"" -ForegroundColor DarkCyan
  }
}

##########---------- Find path of a specified command/executable ----------##########
function whereis ($comand) {
  Get-Command -Name $comand -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

##########---------- Test GitHub SSH connection with GPG keys ----------##########
function ssh_github {
  param (
    [string]$hostname = "github.com",    # default host
    [int]$port        = 22               # default port for SSH
  )

  $msg = "🚀 Launch 󰣀 SSH connection with GPG keys 🚀"

  Write-Host ""
  Write-Host -NoNewline (Get-CenteredPadding -RawMessage $msg)
  Write-Host $msg -ForegroundColor Green

  # Test connection to SSH server
  $connection = Test-NetConnection -ComputerName $hostname -Port $port

  if ($connection.TcpTestSucceeded) {
    $msgPrefix = "󰣀 SSH connection to "
    $msgMiddle = " is open on port "
    $msgSuffix = " ✅"

    $fullMsg = $msgPrefix + $hostname + $msgMiddle + $port + $msgSuffix

    Write-Host -NoNewline (Get-CenteredPadding -RawMessage $fullMsg)
    Write-Host -NoNewline $msgPrefix -ForegroundColor Green
    Write-Host -NoNewline "`"$($hostname)`"" -ForegroundColor Magenta
    Write-Host -NoNewline $msgMiddle -ForegroundColor Green
    Write-Host -NoNewline $port -ForegroundColor Magenta
    Write-Host $msgSuffix -ForegroundColor Green
    Write-Host ""

    ########## CROSS-PLATFORM ##########
    # On Linux/Mac, simply call 'ssh'. On Windows, also prefer 'ssh' if it's in PATH
    if (Get-Command ssh -ErrorAction SilentlyContinue) {
      ssh -T git@github.com
    }
    else {
      # Fallback old Windows
      & "C:\Windows\System32\OpenSSH\ssh.exe" -T git@github.com
    }
  }
  else {
    $msgPrefix = "❌ Unable to connect to "
    $msgMiddle = " on port "
    $msgSuffix = " ❌"

    $fullMsg = $msgPrefix + $hostname + $msgMiddle + $port + $msgSuffix

    Write-Host -NoNewline $msgPrefix -ForegroundColor Red
    Write-Host -NoNewline "`"$($hostname)`"" -ForegroundColor Magenta
    Write-Host -NoNewline $msgMiddle -ForegroundColor Red
    Write-Host -NoNewline $port -ForegroundColor Magenta
    Write-Host $msgSuffix -ForegroundColor Red
    Write-Host ""
  }
}

##########---------- Display powershell colors in terminal ----------##########
function colors {
  $colors = [enum]::GetValues([System.ConsoleColor])

  foreach ($bgcolor in $colors) {
    foreach ($fgcolor in $colors) {
      Write-Host "$fgcolor|" -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine
    }

  Write-Host " on $bgcolor"
  }
}
