##########---------- Get system environment context ----------##########
function Get-SystemContext {
  # PowerShell editing detection (the engine)
  # Desktop = PowerShell 5.1 (old Windows)
  # Core    = PowerShell 7+ (modern : Windows, Linux, Mac)
  $IsCore = $PSVersionTable.PSEdition -ne 'Desktop'

  # OS detection
  # In older PowerShell 5.1 versions, variables $IsLinux/$IsMacOS not exist => assume Windows
  # Also, use different names ($detect...) to avoid conflicts with system reserved variables
  $detectLinux   = $false
  $detectMacOS   = $false
  $detectWindows = $true

  if ($IsCore) {
    # In PowerShell we simply read native variables
    # If $IsLinux exists and is true, we update our internal variable
    if ($IsLinux) { $detectLinux = $true; $detectWindows = $false }
    if ($IsMacOS) { $detectMacOS = $true; $detectWindows = $false }
  }

  # Clean/easy-to-use item
  return [PSCustomObject]@{
    IsCore    = $IsCore
    IsDesktop = -not $IsCore
    IsLinux   = $detectLinux
    IsMacOS   = $detectMacOS
    IsWindows = $detectWindows
  }
}

##########---------- Write file content safely (Cross-Platform encoding) ----------##########
function Set-FileContentCrossPlatform {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [AllowEmptyCollection()]
    [object]$Content
  )

  # Retrieves system context
  $Context = Get-SystemContext

  # By default, remain cautious (UTF8 with BOM for maximum compatibility)
  $EncodingConfig = "UTF8"

  # MODERN version of PowerShell (whether Linux, Mac or Windows 7+), uses standard without BOM
  if ($Context.IsCore) {
    $EncodingConfig = "utf8NoBOM"
  }

  # File write (uses -Value $Content rather than pipeline to ensure compatibility)
  Set-Content -Path $Path -Value $Content -Encoding $EncodingConfig -Force
}

##########---------- Check if Git is installed and available ----------##########
function Test-GitAvailability {
  param (
    # Default message
    [string]$Message = "⛔ Git is not installed (or not found in path)... Install it before using this command ! ⛔",

    # By default text is centered
    [bool]$Center = $true
  )

  # Check command existence
  if (Get-Command git -ErrorAction SilentlyContinue) {
    return $true
  }

  # Display Logic
  if ($Center) {
    Show-GracefulError -Message $Message
  }
  else {
    Show-GracefulError -Message $Message -NoCenter
  }

  return $false
}

##########---------- Calculate centered padding spaces ----------##########
function Get-CenteredPadding {
  param (
    [int]$TotalWidth = $Global:TerminalWidth,
    [string]$RawMessage
  )

  # Removes invisible characters from "Variation Selector"
  $cleanMsg = $RawMessage -replace "\uFE0F", ""

  # Standard length in memory
  $visualLength = $cleanMsg.Length

  # If message contains "simple" BMP emojis (one character long but two characters wide on screen), we add 1
  $bmpEmojis = ([regex]::Matches($cleanMsg, "[\u2300-\u23FF\u2600-\u27BF]")).Count
  $visualLength += $bmpEmojis

  # (Total Width - Message Length) / 2
  # [math]::Max(0, ...) => prevents crash if message is longer than $Global:TerminalWidth characters
  $paddingCount = [math]::Max(0, [int](($TotalWidth - $visualLength) / 2))

  return " " * $paddingCount
}

##########---------- Display a frame header ----------##########
function Show-HeaderFrame {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Title,

    [ConsoleColor]$Color = "Cyan"
  )

  # Fixed constraints
  $TerminalWidth = $Global:TerminalWidth
  $FrameWidth = 64
  $FramePaddingLeft = ($TerminalWidth - $FrameWidth) / 2

  # Frame margins
  $leftMargin = " " * $FramePaddingLeft

  ######## INTERN CONTENT ########
  # Space around title inside frame
  $middleContentRaw = " $Title "

  # Length of horizontal bar between borders ╔ and ╗
  $horizontalBarLength = $FrameWidth - 2

  # Title length
  $TitleLength = $middleContentRaw.Length

  # Total space available to center title
  $TotalInternalSpace = $horizontalBarLength - $TitleLength

  # Internal margin to center title (in 62 characters)
  $InternalLeftSpaces = [System.Math]::Floor($TotalInternalSpace / 2)

  if ($InternalLeftSpaces -lt 0) {
    $InternalLeftSpaces = 0
  }

  $InternalLeftMargin = " " * $InternalLeftSpaces

  # Title with internal left padding
  $PaddedTitle = $InternalLeftMargin + $middleContentRaw

  # Fill in remaining space
  $PaddedTitle += " " * ($horizontalBarLength - $PaddedTitle.Length)

  # Create 62-character border bar
  $horizontalBar = "═" * $horizontalBarLength

  # Display frame header
  Write-Host ""
  Write-Host "$leftMargin╔$horizontalBar╗" -ForegroundColor $Color
  Write-Host "$leftMargin║$PaddedTitle║" -ForegroundColor $Color
  Write-Host "$leftMargin╚$horizontalBar╝" -ForegroundColor $Color
  Write-Host ""
}

##########---------- Wait for valid Yes/No user input ----------##########
function Wait-ForUserConfirmation {
  while ($true) {
    $input = Read-Host

    # Matches: Y, y, Yes, yes, YES, or Empty (Enter key)
    if ($input -match '^(Y|y|yes|Yes|YES|^)$') {
      return $true
    }

    # Matches: n, N, no, No, NO
    elseif ($input -match '^(n|N|no|No|NO)$') {
      return $false
    }

    # If invalid input, loop again
    Write-Host "⚠️ Invalid entry... Please type 'y' or 'n' !" -ForegroundColor DarkYellow
    Write-Host -NoNewline "Try again (Y/n): " -ForegroundColor Magenta
  }
}

##########---------- Display a separator line with custom length and colors ----------##########
function Show-Separator {
  param (
    [Parameter(Mandatory=$true)]
    [int]$Length,

    [Parameter(Mandatory=$true)]
    [System.ConsoleColor]$ForegroundColor,

    [Parameter(Mandatory=$false)]
    [System.ConsoleColor]$BackgroundColor,

    [Parameter(Mandatory=$false)]
    [switch]$NoNewline
  )

  ######## DATA PREPARATION ########
  # Create line string based on requested length
  $line = "─" * $Length

  ######## GUARD CLAUSE : WITH BACKGROUND COLOR ########
  # If a background color is specified, handle it specific way and exit
  if ($PSBoundParameters.ContainsKey('BackgroundColor')) {
    Write-Host -NoNewline:$NoNewline $line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
    return
  }

  ######## STANDARD DISPLAY ########
  # Otherwise (default behavior), display with foreground color only
  Write-Host -NoNewline:$NoNewline $line -ForegroundColor $ForegroundColor
}

##########---------- Display main separator ----------##########
function Show-MainSeparator {
  # Length configuration
  $totalWidth = $Global:TerminalWidth
  $lineLength = 54

  # Calculation of margins
  $paddingCount = [math]::Max(0, [int](($totalWidth - $lineLength) / 2))
  $paddingStr   = " " * $paddingCount

  # Separator display
  Write-Host ""
  Write-Host -NoNewline $paddingStr -ForegroundColor DarkGray
  Show-Separator -NoNewline -Length $lineLength -ForegroundColor DarkGray -BackgroundColor Gray
  Write-Host $paddingStr -ForegroundColor DarkGray
  Write-Host ""
}

##########---------- Display technical error message ----------##########
function Show-TechnicalErrorDetail {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Message
  )

  Write-Host "Error message => " -ForegroundColor Red
  Write-Host $Message -ForegroundColor DarkBlue
}

##########---------- Display error message nicely ----------##########
function Show-GracefulError {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.ErrorRecord]$ErrorDetails,

    [switch]$NoCenter,

    [switch]$NoTrailingNewline
  )

  if ($NoCenter) {
    Write-Host $Message -ForegroundColor Red
  }
  else {
    $paddingStr = Get-CenteredPadding -RawMessage $Message
    Write-Host -NoNewline $paddingStr
    Write-Host $Message -ForegroundColor Red
  }

  # Display technical details if provided
  if ($ErrorDetails) {
    Write-Host "$ErrorDetails" -ForegroundColor DarkBlue
  }

  # Adding final line break if requested
  if (-not $NoTrailingNewline) {
    Write-Host ""
  }
}
