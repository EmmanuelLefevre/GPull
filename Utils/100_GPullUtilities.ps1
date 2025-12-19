##########---------- Get local repositories information ----------##########
function Get-RepositoriesInfo {
  ######## ENVIRONMENTS VARIABLES DEFINITION ########
  # GitHub token
  $gitHubToken = $env:GITHUB_TOKEN
  # GitHub username
  $gitHubUsername = $env:GITHUB_USERNAME

  ######## WINDOWS ENVIRONMENTS VARIABLES MESSAGE CONFIG ########
  $envVarMessageTemplate = "Check {0} in Windows Environment Variables..."
  $functionNameMessage = "in Get-RepositoriesInfo !"

  ######## GUARD CLAUSE : MISSING USERNAME ########
  if ([string]::IsNullOrWhiteSpace($gitHubUsername)) {
    Show-GracefulError -Message "❌ GitHub username is missing or invalid ! ❌" -NoTrailingNewline

    # Helper called to center info message nicely
    $infoMsg = "ℹ️ " + ($envVarMessageTemplate -f "'GITHUB_USERNAME'")
    $paddingInfoStr = Get-CenteredPadding -RawMessage $infoMsg

    # Display info message
    Write-Host -NoNewline $paddingInfoStr
    Write-Host $infoMsg -ForegroundColor DarkYellow

    return $null
  }

  ######## GUARD CLAUSE : MISSING TOKEN ########
  if ([string]::IsNullOrWhiteSpace($gitHubToken)) {
    Show-GracefulError -Message "❌ GitHub token is missing or invalid ! ❌" -NoTrailingNewline

    # Helper called to center info message nicely
    $infoMsg = "ℹ️ " + ($envVarMessageTemplate -f "'GITHUB_TOKEN'")
    $paddingInfoStr = Get-CenteredPadding -RawMessage $infoMsg

    # Display info message
    Write-Host -NoNewline $paddingInfoStr
    Write-Host $infoMsg -ForegroundColor DarkYellow

    return $null
  }

  ######## LOAD PATH LOCATION CONFIG ########
  $allConfig = Get-LocationPathConfig

  ######## GUARD CLAUSE : CONFIG RETURN NOTHING ########
  if (-not $allConfig) {
    Show-GracefulError -Message "❌ Critical Error : Get-LocationPathConfig returned no data ! ❌"
    return $null
  }

  ######## FILTER AND ORDER (CHECK IsRepo = true) ########
  $gitConfig = $allConfig | Where-Object { $_.IsRepo -eq $true }
  $reposOrder = @($gitConfig.Name)

  ######## GUARD CLAUSE : EMPTY ORDER LIST ########
  if (-not $reposOrder -or $reposOrder.Count -eq 0) {
    Show-GracefulError -Message "❌ Local array repo order is empty ! ❌" -NoTrailingNewline

    # Helper called to center info message nicely
    $infoMsg = "ℹ️ Define at least one repository $functionNameMessage (order array)"
    $paddingInfoStr = Get-CenteredPadding -RawMessage $infoMsg

    # Display info message
    Write-Host -NoNewline $paddingInfoStr
    Write-Host $infoMsg -ForegroundColor DarkYellow

    return $null
  }

  ######## PATH VALIDATION 1 : SYNTAX INTEGRITY CHECK (BLOCKING) ########
  # ONLY check if path string is empty
  $invalidSyntaxItems = $gitConfig | Where-Object {
    [string]::IsNullOrWhiteSpace($_.Path)
  }

  if ($invalidSyntaxItems) {
    Show-GracefulError -Message "❌ Local repositories array contains empty paths ! ❌" -NoTrailingNewline

    Write-Host ""
    foreach ($bad in $invalidSyntaxItems) {
      Write-Host -NoNewline " └─ Empty path for : " -ForegroundColor DarkYellow
      Write-Host "📦 $($bad.Name)" -ForegroundColor DarkCyan
    }
    Write-Host ""

    $infoMsg = "ℹ️ Ensure repositories array has valid paths $functionNameMessage"
    $paddingInfoStr = Get-CenteredPadding -RawMessage $infoMsg

    Write-Host -NoNewline $paddingInfoStr
    Write-Host $infoMsg -ForegroundColor DarkYellow

    return $null
  }

  ######## PATH VALIDATION 2 : DISK CHECK (NON-BLOCKING WARNING) ########
  # Simply informing user that folder doesn't exist,
  # but no return $null => allow script to purpose clone
  $missingFolders = $gitConfig | Where-Object {
    -not (Test-Path -Path $_.Path -ErrorAction SilentlyContinue)
  }

  if ($missingFolders) {

    Write-Host ""
    foreach ($miss in $missingFolders) {
      Write-Host -NoNewline " └─ Path not found on disk : " -ForegroundColor DarkYellow
      Write-Host " $($miss.Path)" -ForegroundColor DarkCyan
    }
    Write-Host ""
  }

  ######## ARRAY CONSTRUCTION ########
  $repos = @{}
  $reposSettings = @{}

  foreach ($item in $gitConfig) {
    $repos[$item.Name] = $item.Path

    ######## SECURITY ########
    # Optional handling : if property does not exist, force $false
    if ($item.PSObject.Properties.Match('IsOnlyMain').Count) {
      $reposSettings[$item.Name] = $item.IsOnlyMain
    }
    else {
      $reposSettings[$item.Name] = $false
    }
  }

  ######## RETURN SUCCESS ########
  # Helper called to center message nicely
  $msg = "✔️ GitHub and projects configuration are nicely set ✔️"
  $paddingStr = Get-CenteredPadding -RawMessage $msg

  # Display message
  Write-Host -NoNewline $paddingStr
  Write-Host $msg -ForegroundColor Green
  Show-Separator -Length $Global:TerminalWidth -ForegroundColor Cyan
  Write-Host ""

  return @{
    Username = $gitHubUsername
    Token = $gitHubToken
    Order = $reposOrder
    Paths = $repos
    Settings = $reposSettings
  }
}

##########---------- Filter repositories list (All vs Single) ----------##########
function Get-RepoListToProcess {
  param (
    [array]$FullList,
    [string]$TargetName
  )

  # No optional parameters, return full list
  if ([string]::IsNullOrWhiteSpace($TargetName)) {
    return $FullList
  }

  # Use Where-Object to find original entry in $FullList (which is $reposOrder)
  $OriginalRepoName = $FullList | Where-Object { $_ -ieq $TargetName } | Select-Object -First 1

  # Name specified, check if it exists (case-insensitive)
  if ($OriginalRepoName) {
    # Helper called to center message nicely
    $msg = "🔎 Pull targeted on single repository 🔎"
    $paddingStr = Get-CenteredPadding -RawMessage $msg

    # Display message
    Write-Host -NoNewline $paddingStr
    Write-Host "🔎 Pull targeted on single repository 🔎" -ForegroundColor Cyan

    Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray

    # Returns repository name with original capitalization
    return @($OriginalRepoName)
  }

  # Name not found
  else {
    # Helper called to center message nicely
    $msg = "⚠️ Repository `"$($TargetName)`" not found in your configuration list ! ⚠️"
    $paddingStr = Get-CenteredPadding -RawMessage $msg

    # Display message
    Write-Host -NoNewline $paddingStr
    Write-Host -NoNewline "⚠️ Repository " -ForegroundColor Red
    Write-Host -NoNewline "`"$TargetName`"" -ForegroundColor Magenta
    Write-Host " not found in your configuration list ! ⚠️" -ForegroundColor Red

    return $null
  }
}

##########---------- Check if remote repository exists on GitHub ----------##########
function Test-RemoteRepositoryExistence {
  param (
    [string]$RepoName,
    [string]$UserName,
    [string]$Token
  )

  Write-Host "🔎 Checking remote availability..." -ForegroundColor DarkBlue

  $apiUrl = "https://api.github.com/repos/$UserName/$RepoName"

  try {
    # Try to retrieve information from the repository. If 404, go to catch
    $null = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ Authorization = "Bearer $Token" } -ErrorAction Stop

    return $true
  }
  catch {
    Write-Host ""
    Write-Host -NoNewline "⛔ Remote repository " -ForegroundColor Red
    Write-Host -NoNewline "$UserName" -ForegroundColor Magenta
    Write-Host -NoNewline "/" -ForegroundColor Red
    Write-Host -NoNewline "$RepoName" -ForegroundColor Magenta
    Write-Host " does not exist on GitHub !" -ForegroundColor Red
    Write-Host "  => Please check spelling in Get-LocationPathConfig..." -ForegroundColor DarkYellow

    return $false
  }
}

##########---------- Propose to clone missing repository via SSH ----------##########
function Invoke-InteractiveClone {
  param (
    [string]$RepoName,
    [string]$RepoPath,
    [string]$UserName
  )

  # Helper called to center message nicely
  Write-Host ""
  $msgPrefix = "⚠️ Repository "
  $msgSuffix = " not found on disk ⚠️"

  $fullMsg = $msgPrefix + $RepoName + $msgSuffix

  Write-Host -NoNewline (Get-CenteredPadding -RawMessage $fullMsg)
  Write-Host -NoNewline $msgPrefix -ForegroundColor DarkYellow
  Write-Host -NoNewline $RepoName -ForegroundColor White -BackgroundColor DarkBlue
  Write-Host $msgSuffix -ForegroundColor DarkYellow
  Write-Host ""

  Write-Host -NoNewline "Target path : " -ForegroundColor Cyan
  Write-Host " $RepoPath" -ForegroundColor DarkCyan

  ######## GUARD CLAUSE : CHECK REMOTE EXISTENCE ########
  # If remote doesn't exist, immediately exit
  if (-not (Test-RemoteRepositoryExistence -RepoName $RepoName -UserName $UserName -Token $Token)) {
    return 'Failed'
  }

  # Ask user permission
  Write-Host -NoNewline "🐑 Clone it via SSH ? (Y/n): " -ForegroundColor Magenta

  $confirm = Wait-ForUserConfirmation

  if ($confirm) {
    Write-Host -NoNewline "⏳ Cloning " -ForegroundColor DarkBlue
    Write-Host -NoNewline $RepoName -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "..." -ForegroundColor DarkBlue

    # Ensure parent directory exists
    $parentDir = Split-Path -Path $RepoPath -Parent
    if (-not (Test-Path $parentDir)) {
      New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    # Construct SSH URL
    $sshUrl = "git@github.com:$UserName/$RepoName.git"

    # Execute Clone
    git clone $sshUrl $RepoPath

    if ($LASTEXITCODE -eq 0) {
      Write-Host -NoNewline "  => " -ForegroundColor Green
      Write-Host -NoNewline "$RepoName" -ForegroundColor Magenta
      Write-Host " successfully cloned ✅" -ForegroundColor Green

      return 'Success'
    }
    else {
      Write-Host "❌ Clone failed. Check your SSH keys or internet connection. ❌" -ForegroundColor Red

      return 'Failed'
    }
  }
  else {
    Write-Host "⏩ Clone skipped by user..." -ForegroundColor DarkYellow

    return 'Skipped'
  }
}

##########---------- Check if local repository path exists ----------##########
function Test-LocalRepoExists {
  param (
    [string]$Name,
    [string]$Path,
    [switch]$Silent
  )

  ######## CHECK ########
  # Check if path variable is defined AND if folder exists on disk
  if ($Path -and (Test-Path -Path $Path)) {
    return $true
  }

  ######## ERROR HANDLING ########
  # If silent mode is ON, just return false without drama
  if ($Silent) {
    return $false
  }

  # Otherwise (Standard Mode), display the big red error
  # Helper called to center message nicely
  $msg = "⚠️ Local repository path for $Name doesn't exist ⚠️"
  $paddingStr = Get-CenteredPadding -RawMessage $msg

  # Display message
  Write-Host -NoNewline $paddingStr
  Write-Host -NoNewline "⚠️ Local repository path for " -ForegroundColor Red
  Write-Host -NoNewline "$Name" -ForegroundColor White -BackgroundColor Magenta
  Write-Host " doesn't exist ⚠️" -ForegroundColor Red
  Write-Host ""

  Write-Host "Path searched 👉 " -ForegroundColor DarkYellow
  Write-Host "$Path" -ForegroundColor DarkCyan

  return $false
}

##########---------- Check if folder is a valid git repository ----------##########
function Test-IsGitRepository {
  param (
    [string]$Name,
    [string]$Path
  )

  ######## GUARD CLAUSE : MISSING .GIT FOLDER ########
  # Check if the .git hidden folder exists inside the target path
  if (-not (Test-Path -Path "$Path\.git")) {
    # Helper called to center message nicely
    $msg = "⛔ Local folder $Name found but it's NOT a git repository ⛔"
    $paddingStr = Get-CenteredPadding -RawMessage $msg

    # Display message
    Write-Host -NoNewline $paddingStr
    Write-Host -NoNewline "⛔ Local folder " -ForegroundColor Red
    Write-Host -NoNewline "$Name" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host " found but it's NOT a git repository ⛔" -ForegroundColor Red
    Write-Host ""

    Write-Host "Missing .git folder inside 👉 " -ForegroundColor DarkYellow
    Write-Host "$Path" -ForegroundColor DarkCyan

    return $false
  }

  ######## RETURN SUCCESS ########
  return $true
}

##########---------- Check if local remote matches expected GitHub URL ----------##########
function Test-LocalRemoteMatch {
  param (
    [string]$RepoName,
    [string]$UserName
  )

  ######## DATA RETRIEVAL ########
  # Retrieve the fetch URL for 'origin'
  $rawUrl = (git remote get-url origin 2>$null)

  ######## GUARD CLAUSE : NO REMOTE CONFIGURED ########
  if ([string]::IsNullOrWhiteSpace($rawUrl)) {
    # Helper called to center error message nicely
    $errMsg = "⚠️ No remote 'origin' found for this repository ⚠️"
    $paddingErrStr = Get-CenteredPadding -RawMessage $errMsg

    # Display error message
    Write-Host -NoNewline $paddingErrStr
    Write-Host $errMsg -ForegroundColor Red

    # Helper called to center info message nicely
    $infoMsg = "ℹ️ Repository ignored !"
    $paddingInfoStr = Get-CenteredPadding -RawMessage $infoMsg

    # Helper called to center info message nicely
    Write-Host -NoNewline $paddingInfoStr
    Write-Host $infoMsg -ForegroundColor DarkYellow

    return $false
  }

  ######## GUARD CLAUSE : URL MISMATCH ########
  # Clean up URL because we know it's not empty
  $localRemoteUrl = $rawUrl.Trim()

  # Check if the local remote URL corresponds to the expected GitHub project
  if (-not ($localRemoteUrl -match "$UserName/$RepoName")) {
    # Helper called to center error message nicely
    $errMsg = "⚠️ Original local remote $localRemoteUrl doesn't match ($UserName/$RepoName) ⚠️"
    $paddingErrStr = Get-CenteredPadding -RawMessage $errMsg

    # Display error message
    Write-Host -NoNewline $paddingErrStr
    Write-Host -NoNewline "⚠️ Original local remote " -ForegroundColor Red
    Write-Host -NoNewline "$localRemoteUrl" -ForegroundColor Magenta
    Write-Host -NoNewline " doesn't match (" -ForegroundColor Red
    Write-Host -NoNewline "$UserName" -ForegroundColor Magenta
    Write-Host -NoNewline "/" -ForegroundColor Red
    Write-Host -NoNewline "$RepoName" -ForegroundColor Magenta
    Write-Host ") ⚠️" -ForegroundColor Red

    # Helper called to center info message nicely
    $InfoMsg = "ℹ️ Repository ignored !"
    $paddingInfoStr = Get-CenteredPadding -RawMessage $InfoMsg

    # Display info message
    Write-Host -NoNewline $paddingInfoStr
    Write-Host $InfoMsg -ForegroundColor DarkYellow

    return $false
  }

  ######## RETURN SUCCESS ########
  return $true
}

##########---------- Show last commit date regardless of branch ----------##########
function Show-LastCommitDate {
  ######## DATA RETRIEVAL ########
  # Retrieve all remote branches sorted by date
  $allRefs = git for-each-ref --sort=-committerdate refs/remotes --format="%(refname:short) %(committerdate:iso-strict)" 2>$null

  ######## GUARD CLAUSE : NO REFS RETRIEVED ########
  # Check if we got a result
  if ([string]::IsNullOrWhiteSpace($allRefs)) {
    return
  }

  ######## FILTERING ########
  # Exclude "HEAD" references (ex: origin/HEAD) and select most recent
  $lastCommitInfo = $allRefs | Where-Object {
    ($_ -notmatch '/HEAD\s') -and ($_ -match '/')
  } | Select-Object -First 1

  ######## GUARD CLAUSE : NO MATCHING BRANCH ########
  if ([string]::IsNullOrWhiteSpace($lastCommitInfo)) {
    return
  }

  # Separate the chain into two
  $parts = $lastCommitInfo -split ' ', 2

  ######## GUARD CLAUSE : DATA INTEGRITY FAIL ########
  # Check data integrity (must have Branch + Date)
  if ($parts.Length -ne 2) {
    return
  }

  ######## PROCESSING / DISPLAY ########
  # Clean up branch name (Remove "origin/")
  $branchName = $parts[0] -replace '^.*?/', ''
  $dateString = $parts[1]

  try {
    # Convert ISO string into [datetime] object
    [datetime]$commitDate = $dateString

    # Define culture on "en-US"
    $culture = [System.Globalization.CultureInfo]'en-US'

    # Format date (ex: Monday 13 September 2025)
    $formattedDate = $commitDate.ToString('dddd dd MMMM yyyy', $culture)

    # Display formatted message
    Write-Host -NoNewline "📈 Last repository commit : " -ForegroundColor DarkYellow
    Write-Host -NoNewline "$formattedDate" -ForegroundColor Cyan
    Write-Host -NoNewline " on " -ForegroundColor DarkYellow
    Write-Host "$branchName" -ForegroundColor Magenta

    Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
  }
  catch {
    # If date parsing fails, exit silently
    return
  }
}

##########---------- Check if git fetch succeeded ----------##########
function Test-GitFetchSuccess {
  param ([int]$ExitCode)

  ######## GUARD CLAUSE : FETCH FAILED ########
  # Check if the exit code indicates an error (non-zero)
  if ($ExitCode -ne 0) {
    Show-GracefulError -Message "⚠️ 'Git fetch' failed ! Check your Git access credentials... ⚠️" -NoCenter
    return $false
  }

  ######## RETURN SUCCESS ########
  return $true
}

##########---------- Retrieve local branches that have a remote upstream ----------##########
function Get-LocalBranchesWithUpstream {
  ######## DATA RETRIEVAL ########
  # Get raw data : LocalBranchName + RemoteUpstreamName
  $rawRefs = git for-each-ref --format="%(refname:short) %(upstream:short)" refs/heads 2>$null

  ######## GUARD CLAUSE : NO REFS ########
  if ([string]::IsNullOrWhiteSpace($rawRefs)) {
    return $null
  }

  ######## DATA PROCESSING ########
  # Convert raw text to objects
  $branchesWithUpstream = $rawRefs | ForEach-Object {
    $parts = $_ -split ' '

    # Check data integrity (Must have: Name + Upstream)
    if ($parts.Length -eq 2 -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
      [PSCustomObject]@{
        Local  = $parts[0]
        Remote = $parts[1]
      }
    }
  }

  return $branchesWithUpstream
}

##########---------- Sort branches by priority (Main > Dev > Others) ----------##########
function Get-SortedBranches {
  param (
    [Parameter(Mandatory=$true)]
    [array]$Branches
  )

  # Ensure that $Branches is at least an empty array for filters
  if ($null -eq $Branches) { $Branches = @() }

  ######## CONFIGURATION ########
  # Defines priority branches names
  $mainBranchNames = @("main", "master")
  $devBranchNames  = @("dev", "develop")

  ######## SORTING LOGIC ########
  # Create three lists to guarantee order (force an array)
  $mainList   = @($Branches | Where-Object { $mainBranchNames -icontains $_.Local })
  $devList    = @($Branches | Where-Object { $devBranchNames -icontains $_.Local })

  # Combines two priority lists for exclusion filter
  $allPriorityNames = $mainBranchNames + $devBranchNames

  # Sort other branches alphabetically
  $otherList  = @($Branches | Where-Object { -not ($allPriorityNames -icontains $_.Local) } | Sort-Object Local)

  ######## MERGE & RETURN ########
  # Use comma operator to merge arrays, ensuring an output array
  return ,($mainList + $devList + $otherList)
}

##########---------- Try to checkout branch, handle errors ----------##########
function Invoke-SafeCheckout {
  param (
    [string]$TargetBranch,
    [string]$OriginalBranch
  )

  ######## CHECKOUT ACTION ########
  git checkout $TargetBranch *> $null

  ######## GUARD CLAUSE : CHECKOUT FAILED ########
  if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ "
    Write-Host -NoNewline "Could not checkout " -ForegroundColor Magenta
    Write-Host -NoNewline "$TargetBranch" -ForegroundColor Red
    Write-Host " !!! ⚠️" -ForegroundColor Magenta

    Write-Host -NoNewline "ℹ️ Blocked by local changes on " -ForegroundColor DarkYellow
    Write-Host -NoNewline "$OriginalBranch" -ForegroundColor Magenta
    Write-Host ". Halting updates for this repository !" -ForegroundColor DarkYellow

    return $false
  }

  ######## SUCCESS FEEDBACK ########
  Write-Host -NoNewline "Inspecting branch " -ForegroundColor Cyan
  Write-Host "$TargetBranch" -ForegroundColor Magenta

  return $true
}

##########---------- Force sync for bot-managed branches (e.g. output) ----------##########
function Invoke-BotBranchSync {
  param (
    [string]$BranchName
  )

  # Branches list managed by robots
  $botBranches = @("output")

  # If branch isn't in list, nothing is done
  if ($botBranches -notcontains $BranchName) {
    return 'NotBot'
  }

  # If it's a bot branch, we force synchronization.
  Write-Host "🤖 Bot branch detected. Forcing sync... " -ForegroundColor Magenta

  # We force a reset on the server version (upstream)
  git reset --hard "@{u}" *> $null

  if ($LASTEXITCODE -eq 0) {
    return 'Updated'
  }
  else {
    return 'Failed'
  }
}

##########---------- Check for local modifications (Staged/Unstaged) ----------##########
function Test-WorkingTreeClean {
  param (
    [string]$BranchName
  )

  ######## DATA RETRIEVAL ########
  $unstagedChanges = git diff --name-only --quiet
  $stagedChanges   = git diff --cached --name-only --quiet

  ######## GUARD CLAUSE : DIRTY TREE ########
  if ($unstagedChanges -or $stagedChanges) {
    Write-Host -NoNewline "󰨈  Conflict detected on " -ForegroundColor Red
    Write-Host -NoNewline "$BranchName" -ForegroundColor Magenta
    Write-Host -NoNewline " , this branch has local changes. Pull avoided... 󰨈" -ForegroundColor Red
    Write-Host "Affected files =>" -ForegroundColor DarkCyan

    # Display details logic
    if ($unstagedChanges) {
      Write-Host "Unstaged affected files =>" -ForegroundColor DarkCyan
      git diff --name-only | ForEach-Object {
        Write-Host "   $_" -ForegroundColor DarkCyan
      }
    }
    if ($stagedChanges) {
      Write-Host "Staged affected files =>" -ForegroundColor DarkCyan
      git diff --cached --name-only | ForEach-Object {
        Write-Host "   $_" -ForegroundColor DarkCyan
      }
    }

    return $false
  }

  ######## RETURN SUCCESS ########
  return $true
}

##########---------- Check if local branch has unpushed commits ----------##########
function Test-UnpushedCommits {
  param (
    [string]$BranchName
  )

  ######## DATA RETRIEVAL ########
  $unpushed = git log "@{u}..HEAD" --oneline -q 2>$null

  ######## GUARD CLAUSE : BRANCH AHEAD ########
  if ($unpushed) {
    Write-Host -NoNewline "⚠️ Branch ahead => " -ForegroundColor Red
    Write-Host -NoNewline "$BranchName" -ForegroundColor Magenta
    Write-Host " has unpushed commits. Pull avoided to prevent a merge ! ⚠️" -ForegroundColor Red

    return $true
  }

  ######## RETURN SUCCESS ########
  return $false
}

##########---------- Check if local branch is already up to date ----------##########
function Test-IsUpToDate {
  param (
    [string]$LocalBranch,
    [string]$RemoteBranch
  )

  ######## DATA RETRIEVAL ########
  $localCommit  = git rev-parse $LocalBranch
  $remoteCommit = (git rev-parse $RemoteBranch -q 2>$null)

  ######## GUARD CLAUSE : : REMOTE MISSING ########
  # Consider "Up to date" to avoid pull errors, or handle separately
  if (-not $remoteCommit) {
    return $true
  }

  ######## GUARD CLAUSE : ALREADY SYNCED ########
  if ($localCommit -eq $remoteCommit) {
    Write-Host -NoNewline "$LocalBranch" -ForegroundColor Red
    Write-Host " is already updated ✅" -ForegroundColor Green

    return $true
  }

  ######## RETURN FAILURE ########
  # Hashes are different, so it's not up to date
  return $false
}

##########---------- Execute pull strategy (Auto vs Interactive) ----------##########
function Invoke-BranchUpdateStrategy {
  param (
    [string]$LocalBranch,
    [string]$RemoteBranch,
    [string]$RepoName
  )

  ######## GUARD CLAUSE : INVALID REFERENCES ########
  if (-not (git rev-parse --verify $LocalBranch 2>$null) -or
    -not (git rev-parse --verify $RemoteBranch 2>$null)) {
    Write-Host "⚠️ Unable to read local/remote references for $LocalBranch ! ⚠️" -ForegroundColor Red

    return 'Failed'
  }

  # Default state
  $pullStatus = 'Skipped'

  ######## STRATEGY : AUTO-UPDATE (Main/Master) ########
  if ($LocalBranch -eq "main" -or $LocalBranch -eq "master") {
    Write-Host "⏳ Updating main branch..." -ForegroundColor Magenta
    Show-LatestCommitsMessages -LocalBranch $LocalBranch -RemoteBranch $RemoteBranch -HideHashes

    git pull

    # Check if pull worked
    if ($LASTEXITCODE -eq 0) {
      $pullStatus = 'Success'
    }
    else {
      $pullStatus = 'Failed'
    }
  }

  ######## STRATEGY : AUTO-UPDATE (Dev/Develop) ########
  elseif ($LocalBranch -eq "dev" -or $LocalBranch -eq "develop") {
    Write-Host "⏳ Updating develop branch..." -ForegroundColor Magenta
    Show-LatestCommitsMessages -LocalBranch $LocalBranch -RemoteBranch $RemoteBranch -HideHashes

    git pull

    # Check if pull worked
    if ($LASTEXITCODE -eq 0) {
      $pullStatus = 'Success'
    }
    else {
      $pullStatus = 'Failed'
    }
  }

  ######## STRATEGY : INTERACTIVE ########
  # Ask user for other branches
  else {
    Write-Host -NoNewline "Branch " -ForegroundColor Magenta
    Write-Host -NoNewline "$LocalBranch" -ForegroundColor Red
    Write-Host " has updates." -ForegroundColor Magenta

    Show-LatestCommitsMessages -LocalBranch $LocalBranch -RemoteBranch $RemoteBranch -HideHashes

    Write-Host -NoNewline "Pull ? (Y/n): " -ForegroundColor Magenta

    # Helper called for a robust response
    $wantToPull = Wait-ForUserConfirmation

    if ($wantToPull) {
      Write-Host -NoNewline "⏳ Updating " -ForegroundColor Magenta
      Write-Host -NoNewline "$LocalBranch" -ForegroundColor Red
      Write-Host "..." -ForegroundColor Magenta

      git pull

      # Check if pull worked
      if ($LASTEXITCODE -eq 0) {
        $pullStatus = 'Success'
      }
      else {
        $pullStatus = 'Failed'
      }
    }
    else {
      Write-Host -NoNewline "Skipping pull for " -ForegroundColor Magenta
      Write-Host -NoNewline "$LocalBranch" -ForegroundColor Red
      Write-Host "..." -ForegroundColor Magenta

      # Reset pull success
      $pullStatus = 'Skipped'
    }
  }

  ######## RESULT FEEDBACK ########
  switch ($pullStatus) {
    'Success' {
      Write-Host -NoNewline "  => " -ForegroundColor Green
      Write-Host -NoNewline "$LocalBranch" -ForegroundColor Magenta
      Write-Host " successfully updated ✅" -ForegroundColor Green

    }
    'Failed' {
      Write-Host "❌ "
      Write-Host -NoNewline "Error updating " -ForegroundColor Red
      Write-Host -NoNewline "$LocalBranch" -ForegroundColor Magenta
      Write-Host -NoNewline " in " -ForegroundColor Red
      Write-Host -NoNewline "$RepoName" -ForegroundColor white -BackgroundColor DarkBlue
      Write-Host " ❌" -ForegroundColor Red
    }
  }

  return $pullStatus
}

##########---------- Get and show latest commit message ----------##########
function Show-LatestCommitsMessages {
  param (
    [string]$LocalBranch,
    [string]$RemoteBranch,
    [switch]$HideHashes
  )

  ######## DATA RETRIEVAL ########
  # Get HASH HEAD
  $localHash  = git rev-parse $LocalBranch 2>$null
  $remoteHash = git rev-parse $RemoteBranch 2>$null

  ######## DATA ANALYSIS : ANCESTRY ########
  $isLocalBehind  = git merge-base --is-ancestor $localHash $remoteHash 2>$null
  $isRemoteBehind = git merge-base --is-ancestor $remoteHash $localHash 2>$null

  # Divergence detection
  if (-not $isLocalBehind -and -not $isRemoteBehind) {
    # Calculate exact difference
    $counts = git rev-list --left-right --count "$LocalBranch...$RemoteBranch" 2>$null
    $ahead = 0
    $behind = 0

    if ($counts -match '(\d+)\s+(\d+)') {
      $ahead  = $Matches[1]
      $behind = $Matches[2]
    }

    Write-Host "🔀 Diverged history detected !" -ForegroundColor DarkYellow
    Write-Host -NoNewline "   └─ Your branch is ahead by " -ForegroundColor Magenta
    Write-Host -NoNewline "$ahead" -ForegroundColor DarkCyan
    Write-Host -NoNewline " and behind by " -ForegroundColor Magenta
    Write-Host "$behind" -ForegroundColor DarkCyan
  }

  # Get new commits
  $raw = git log --pretty=format:"%s" --no-merges "$LocalBranch..$RemoteBranch" 2>$null

  # Normalisation : string → array
  $newCommits = @()
  if ($raw) {
    if ($raw -is [string]) {
      $newCommits = @($raw)
    }
    else {
      $newCommits = $raw
    }
  }

  ######## GUARD CLAUSE : NO COMMITS VISIBLE ########
  # If no commits
  if ($newCommits.Count -eq 0) {
    if ($isLocalBehind) {
      Write-Host "ℹ️ Fast-forward possible (no visible commits) ℹ️" -ForegroundColor DarkYellow
    }
    else {
      Write-Host "ℹ️ No commit visible, but a pull may be needed... ℹ️" -ForegroundColor DarkYellow
    }
    return
  }

  ######## GUARD CLAUSE : SINGLE COMMIT ########
  # One commit
  if ($newCommits.Count -eq 1) {
    Write-Host "Commit message : " -ForegroundColor Magenta
    Write-Host "  - `"$newCommits[0]`"" -ForegroundColor Cyan
    return
  }

  ######## DISPLAY MULTIPLE COMMITS (PAGINATION LOGIC) ########
  # Several commits
  Write-Host "New commits received :" -ForegroundColor Magenta

  # Configuration
  $displayLimit = 5
  $totalCommits = $newCommits.Count

  # If total is less or equal to limit, we show everything normally
  if ($totalCommits -le $displayLimit) {
    foreach ($commit in $newCommits) {
      Write-Host "  - `"$commit`"" -ForegroundColor DarkCyan
    }
  }
  # If we have more than limit
  else {
    # Display first 5 commits
    for ($i = 0; $i -lt $displayLimit; $i++) {
      Write-Host "  - `"$($newCommits[$i])`"" -ForegroundColor DarkCyan
    }

    # Calculate remaining
    $remainingCount = $totalCommits - $displayLimit

    # Interactive prompt
    Write-Host -NoNewline "⚠️ $remainingCount" -ForegroundColor Red
    Write-Host -NoNewline " more commits ! Show all ? (Y/n): " -ForegroundColor DarkYellow

    # Helper called for a robust response
    $showAll = Wait-ForUserConfirmation

    if ($showAll) {
      # Display rest
      for ($i = $displayLimit; $i -lt $totalCommits; $i++) {
        Write-Host "  - `"$($newCommits[$i])`"" -ForegroundColor DarkCyan
      }
    }
  }
}

##########---------- Calculate new remote branches to track ----------##########
function Get-NewRemoteBranches {
  ######## DATA RETRIEVAL ########
  # Get all remote branches (excluding HEAD) and local branches
  $allRemoteRefs = git for-each-ref --format="%(refname:short)" refs/remotes | Where-Object { $_ -notmatch '/HEAD$' }
  $allLocalBranches = git for-each-ref --format="%(refname:short)" refs/heads

  # List to store new branches to track
  $branchesFound = @()

  ######## PROCESSING LOOP ########
  # Iterate through remote branches to find those not tracked locally
  foreach ($remoteRef in $allRemoteRefs) {

    # Extract local name from remote ref (ex: "origin/feature/x" -> "feature/x")
    if ($remoteRef -match '^[^/]+/(.+)$') {
      $localEquivalent = $Matches[1]

      ######## GUARD CLAUSE : IGNORED PREFIXES ########
      # Define prefixes to exclude (Hotfix and Release)
      $prefixesToIgnore = @('hotfix/', 'release/')
      $shouldIgnore = $false

      # Check each prefix to ignore
      foreach ($prefix in $prefixesToIgnore) {
        # Check if branch name begins with a prefix to ignore
        if ($localEquivalent.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
          $shouldIgnore = $true

          # No point in continuing to search, exit loop
          break
        }
      }

      # If branch matches an ignored prefix, skip to next iteration
      if ($isIgnored) {
        continue
      }

      ######## GUARD CLAUSE : ALREADY TRACKED ########
      # If the branch already exists locally, skip it
      if ($localEquivalent -in $allLocalBranches) {
        continue
      }

      ######## ADD TO SELECTION ########
      # If we are here, strictly valid (Not ignored AND Not already local)
      $branchesFound += $remoteRef
    }
  }

  return $branchesFound
}

##########---------- Interactive proposal to create new local branches OR delete remote ----------##########
function Invoke-NewBranchTracking {
  param (
    [array]$NewBranches
  )

  ######## GUARD CLAUSE : NO NEW BRANCHES ########
  # If the list is empty or null, nothing to do
  if (-not $NewBranches -or $NewBranches.Count -eq 0) {
    return $false
  }

  ######## CONFIGURATION ########
  # Branches that should NEVER be deleted remotely even if user doesn't track them
  $protectedBranches = @("dev", "develop", "main", "master")

  Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray

  # Flag initialization
  $hasError = $false
  $isFirstLoop = $true

  ######## USER INTERACTION LOOP ########
  foreach ($newBranchRef in $NewBranches) {
    # Extract local name (ex: origin/feature/x -> feature/x)
    $null = $newBranchRef -match '^[^/]+/(.+)$'
    $localBranchName = $Matches[1]

    ######## UI : SEPARATOR MANAGEMENT ########
    # Display separator (except first)
    if (-not $isFirstLoop) {
      Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
    }
    # Mark first loop is finished
    $isFirstLoop = $false

    # Display Branch Found
    Write-Host -NoNewline "❤️ New remote branche found => " -ForegroundColor Blue
    Write-Host "🦄 $localBranchName 🦄" -ForegroundColor Red

    # Get and show latest commit message
    $latestCommitMsg = git log -1 --format="%s" $newBranchRef 2>$null
    if ($latestCommitMsg) {
      Write-Host -NoNewline "Commit message : " -ForegroundColor Magenta
      Write-Host "$latestCommitMsg" -ForegroundColor Cyan
    }

    ######## CHOICE 1 : TRACKING ########
    # Ask user permission
    Write-Host -NoNewline "Pull " -ForegroundColor Magenta
    Write-Host -NoNewline "$localBranchName" -ForegroundColor Red
    Write-Host -NoNewline " ? (Y/n): " -ForegroundColor Magenta

    # Helper called for a robust response
    $wantToTrack = Wait-ForUserConfirmation

    ######## YES WE TRACK ########
    if ($wantToTrack) {
      Write-Host -NoNewline "⏳ Creating local branch " -ForegroundColor Magenta
      Write-Host "$localBranchName" -ForegroundColor Red

      # Create local branch tracking remote branch
      git branch --track --quiet $localBranchName $newBranchRef 2>$null

      # Check if branch creation worked
      if ($LASTEXITCODE -eq 0) {
        Write-Host -NoNewline "  => "
        Write-Host -NoNewline "$localBranchName" -ForegroundColor Red
        Write-Host " successfully pulled ✅" -ForegroundColor Green
      }
      # If branch creation failed
      else {
        Write-Host -NoNewline "$localBranchName" -ForegroundColor Red
        Write-Host "⚠️ New creation branch has failed ! ⚠️" -ForegroundColor Red

        $hasError = $true
      }
    }

    ######## CHOICE 2 : OTHERWISE WE PROPOSE REMOVAL #######
    else {
      # We NEVER suggest deleting a protected branch
      if ($protectedBranches -contains $localBranchName) {
        continue
      }

      Write-Host -NoNewline "ℹ️ You decided not to track " -ForegroundColor DarkYellow
      Write-Host -NoNewline "$localBranchName" -ForegroundColor Red
      Write-Host ". This branch is forsaken ?" -ForegroundColor DarkYellow

      ######## STEP 1 : REMOTE DELETION ########
      Write-Host -NoNewline "🗑️ Delete remote branch permanently ? (Y/n): " -ForegroundColor Magenta

      # Helper called for a robust response
      $wantToDelete = Wait-ForUserConfirmation

      if ($wantToDelete) {
        ######## STEP 2 : DOUBLE CONFIRMATION ########
        Write-Host -NoNewline (" " * 20)
        Show-Separator -Length 40 -ForegroundColor Red

        # Helper called to center message nicely
        $msg = "💀 ARE YOU SURE ? THIS ACTION IS IRREVERSIBLE ! 💀"
        $paddingStr = Get-CenteredPadding -RawMessage $msg

        # Display message
        Write-Host -NoNewline $paddingStr
        Write-Host "💀 ARE YOU SURE ? THIS ACTION IS IRREVERSIBLE ! 💀" -ForegroundColor Red
        Write-Host "Maybe you are near to delete remote branch of one of your team's member..." -ForegroundColor Red
        Write-Host -NoNewline "Confirm deletion of " -ForegroundColor Magenta
        Write-Host -NoNewline "$localBranchName" -ForegroundColor Red
        Write-Host -NoNewline " ? (Y/n): " -ForegroundColor Magenta

        # Helper called for a robust response
        $isSure = Wait-ForUserConfirmation

        if ($isSure) {
          Write-Host "  🔥 Removal of $localBranchName..." -ForegroundColor Magenta

          git push origin --delete $localBranchName 2>&1 | Out-Null

          # Check if branch deletion worked
          if ($LASTEXITCODE -eq 0) {
            Write-Host -NoNewline "  => "
            Write-Host -NoNewline "$localBranchName" -ForegroundColor Magenta
            Write-Host " successfully deleted from server ✅" -ForegroundColor Green
          }
          # If branch deletion failed
          else {
            Write-Host -NoNewline "⚠️ Failed to delete " -ForegroundColor Red
            Write-Host "origin/$localBranchName ⚠️" -ForegroundColor Magenta

            $hasError = $true
          }
        }
        else {
          Write-Host -NoNewline "👍 Remote branch " -ForegroundColor Green
          Write-Host -NoNewline "$localBranchName" -ForegroundColor Magenta
          Write-Host " kept 👍" -ForegroundColor Green
        }
      }
      else {
        Write-Host -NoNewline "👍 Remote branch " -ForegroundColor Green
        Write-Host -NoNewline "$localBranchName" -ForegroundColor Magenta
        Write-Host " kept 👍" -ForegroundColor Green
      }
    }
  }
  return $hasError
}

##########---------- Interactive cleanup of orphaned (gone) branches ----------##########
function Invoke-OrphanedCleanup {
  param (
    [string]$OriginalBranch
  )

  ######## DATA RETRIEVAL ########
  # Define protected branches (never delete them)
  $protectedBranches = @("dev", "develop", "main", "master")

  # Get current branch name to ensure we don't try to delete it
  $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

  # Find branches marked as ': gone]' in git verbose output
  $orphanedBranches = git branch -vv | Select-String -Pattern '\[.*: gone\]' | ForEach-Object {
    $line = $_.Line.Trim()
    if ($line -match '^\*?\s*([\S]+)') {
      $Matches[1]
    }
  }

  # Filter, remove protected branches
  $branchesToClean = $orphanedBranches | Where-Object {
    (-not ($protectedBranches -icontains $_))
  }

  ######## GUARD CLAUSE : NOTHING TO CLEAN ########
  # Original branch was NOT deleted (or empty list)
  if (-not $branchesToClean -or $branchesToClean.Count -eq 0) {
    return [PSCustomObject]@{ OriginalDeleted = $false; HasError = $false }
  }

  Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray

  Write-Host "🧹 Cleaning up orphaned local branches..." -ForegroundColor DarkYellow


  # Flags initialization
  $originalWasDeleted = $false
  $hasError = $false
  $isFirstBranch = $true

  ######## INTERACTIVE CLEANUP LOOP ########
  foreach ($orphaned in $branchesToClean) {
    if (-not $isFirstBranch) {
      Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
    }

    # Refresh current branch status (in case we moved in previous loop)
    $realTimeCurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

    if (-not $isFirstBranch) {
      Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
    }
    $isFirstBranch = $false

    ######## DEAD BRANCH ########
    if ($orphaned -eq $realTimeCurrentBranch) {
      Write-Host -NoNewline "👻 You are currently on the orphaned branch " -ForegroundColor Cyan
      Write-Host -NoNewline "`"$($orphaned)`"" -ForegroundColor Magenta
      Write-Host " ..." -ForegroundColor Cyan

      ######## GUARD CLAUSE : DIRTY WORKTREE ########
      if (-not (Test-WorkingTreeClean -BranchName $orphaned)) {
        Write-Host "⛔ Cannot switch branch automatically : uncommitted/unstagged changes detected ! ⛔" -ForegroundColor Red
        Write-Host "   └─> Skipping cleanup for this branch." -ForegroundColor DarkYellow

        continue
      }

      # Find safe branch
      $safeBranch = "develop"
      if (-not (git rev-parse --verify $safeBranch 2>$null)) { $safeBranch = "dev" }
      if (-not (git rev-parse --verify $safeBranch 2>$null)) { $safeBranch = "main" }
      if (-not (git rev-parse --verify $safeBranch 2>$null)) { $safeBranch = "master" }

      # Evacuate on safe branch
      Write-Host -NoNewline "🔄 Evacuating to " -ForegroundColor Cyan
      Write-Host -NoNewline "`"$($safeBranch)`"" -ForegroundColor Magenta
      Write-Host " to allow deletion 🔄" -ForegroundColor Cyan

      git checkout $safeBranch 2>$null | Out-Null

      if ($LASTEXITCODE -ne 0) {
        Write-Host -NoNewline "❌ Failed to checkout " -ForegroundColor Red
        Write-Host -NoNewline "`"$($safeBranch)`"" -ForegroundColor Magenta
        Write-Host -NoNewline ". Deletion aborted." -ForegroundColor Red

        $hasError = $true

        continue
      }
      # Success : no longer on branch, we can proceed to delete it
    }

    ######## STANDARD DELETION LOGIC ########
    # Helper called for warn about stash on branch
    Show-StashWarning -BranchName $orphaned

    # Ask user
    Write-Host -NoNewline "🗑️ Delete the orphaned local branch " -ForegroundColor Magenta
    Write-Host -NoNewline "$orphaned" -ForegroundColor Red
    Write-Host -NoNewline " ? (Y/n): " -ForegroundColor Magenta

    # Helper called for a robust response
    $wantToDelete = Wait-ForUserConfirmation

    if ($wantToDelete) {
      Write-Host "  🔥 Removal of $orphaned..." -ForegroundColor Magenta

      # Attempt secure removal
      git branch -d $orphaned *> $null

      # Check if deletion worked
      if ($LASTEXITCODE -eq 0) {
        Write-Host -NoNewline "  => "
        Write-Host -NoNewline "$orphaned" -ForegroundColor Red
        Write-Host " successfully deleted ✅" -ForegroundColor Green
        if ($orphaned -eq $OriginalBranch) {
          $originalWasDeleted = $true
        }
      }
      # If deletion failed (probably unmerged changes)
      else {
        Write-Host -NoNewline "⚠️ Branch " -ForegroundColor Red
        Write-Host -NoNewline "$orphaned" -ForegroundColor Magenta
        Write-Host " contains unmerged changes ! ⚠️" -ForegroundColor Red

        Write-Host -NoNewline "Force the deletion of " -ForegroundColor Magenta
        Write-Host -NoNewline "$orphaned" -ForegroundColor Red
        Write-Host -NoNewline " ? (Y/n): " -ForegroundColor Magenta

        # Helper called for a robust response
        $wantToForce = Wait-ForUserConfirmation

        if ($wantToForce) {
          # Forced removal
          git branch -D $orphaned *> $null

          # Check if forced deletion worked
          if ($LASTEXITCODE -eq 0) {
            Write-Host -NoNewline "  => "
            Write-Host -NoNewline "$orphaned" -ForegroundColor Red
            Write-Host " successfully deleted ✅" -ForegroundColor Green

            # Mark original branch as deleted
            if ($orphaned -eq $OriginalBranch) {
              $originalWasDeleted = $true
            }
          }
          # If forced deletion failed
          else {
            Write-Host -NoNewline "⚠️ Unexpected error. Failure to remove " -ForegroundColor Red
            Write-Host "$orphaned ⚠️" -ForegroundColor Magenta

            $hasError = $true
          }
        }
        # User refuses forced deletion
        else {
          Write-Host -NoNewline "👍 Local branch " -ForegroundColor Green
          Write-Host -NoNewline "$orphaned" -ForegroundColor Magenta
          Write-Host " kept 👍" -ForegroundColor Green
        }
      }
    }
  }

  return [PSCustomObject]@{
    OriginalDeleted = $originalWasDeleted
    HasError        = $hasError
  }
}

##########---------- Interactive cleanup of fully merged branches ----------##########
function Invoke-MergedCleanup {
  param (
    [string]$OriginalBranch
  )

  ######## DATA RETRIEVAL ########
  # Define integration branches to check against
  $integrationBranches = @("main", "master", "develop", "dev")

  # Define protected branches (never delete these)
  $protectedBranches   = @("dev", "develop", "main", "master")

  # Get current branch name to ensure we don't try to delete it
  $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

  # Use hash table to collect merged branches (avoids duplicates if merged in both dev and main)
  $allMergedBranches = @{}

  foreach ($intBranch in $integrationBranches) {
    # Check if integration branch exists locally
    if (git branch --list $intBranch) {
      # Get branches merged into this integration branch
      git branch --merged $intBranch | ForEach-Object {
        $branchName = $_ -replace '^\*\s+', ''
        $branchName = $branchName.Trim()

        $allMergedBranches[$branchName] = $true
      }
    }
  }

  ######## FILTERING ########
  # Filter list to keep only branches that can be cleaned (not current and not protected ones)
  $branchesToClean = $allMergedBranches.Keys | Where-Object {
    ($_ -ne $OriginalBranch) -and ($_ -ne $currentBranch) -and (-not ($protectedBranches -icontains $_))
  }

  ######## GUARD CLAUSE : NOTHING TO CLEAN ########
  if (-not $branchesToClean -or $branchesToClean.Count -eq 0) {
    # Original branch was NOT deleted
    return $false
  }

  Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray

  Write-Host "🧹 Cleaning up local branches that have already being merged..." -ForegroundColor DarkYellow


  # Flags initialization
  $originalWasDeleted = $false
  $hasError = $false
  $isFirstBranch = $true

  ######## INTERACTIVE CLEANUP LOOP ########
  foreach ($merged in $branchesToClean) {
    if (-not $isFirstBranch) {
      Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
    }

    $isFirstBranch = $false

    # Helper called for warn about stash on branch
    Show-StashWarning -BranchName $merged

    # Ask user
    Write-Host -NoNewline "Local branch " -ForegroundColor Magenta
    Write-Host -NoNewline "$merged" -ForegroundColor Red
    Write-Host -NoNewline " is already merged. 🗑️ Delete ? (Y/n): " -ForegroundColor Magenta

    # Helper called for a robust response
    $wantToDelete = Wait-ForUserConfirmation

    if ($wantToDelete) {
      Write-Host "  🔥 Removal of $merged..." -ForegroundColor Magenta

      # Secure removal (guaranteed to work because we checked --merged)
      git branch -D $merged *> $null

      # Check if deletion worked
      if ($LASTEXITCODE -eq 0) {
        Write-Host -NoNewline "  => "
        Write-Host -NoNewline "$merged" -ForegroundColor Red
        Write-Host " successfully deleted ✅" -ForegroundColor Green

        # Check if original branch has been deleted
        if ($merged -eq $OriginalBranch) {
          # Mark original branch as deleted
          $originalWasDeleted = $true
        }
      }
      # If deletion failed
      else {
        Write-Host -NoNewline "⚠️ Unexpected error. Failure to remove " -ForegroundColor Red
        Write-Host "$merged ⚠️" -ForegroundColor Magenta

        $hasError = $true
      }
    }
  }

  return [PSCustomObject]@{
    OriginalDeleted = $originalWasDeleted
    HasError        = $hasError
  }
}

##########---------- Check for unmerged commits in main from dev ----------##########
function Show-MergeAdvice {
  param (
    [switch]$DryRun
  )

  ######## MAIN BRANCH DATA RETRIEVAL ########
  # Identify main branch (main or master)
  $mainBranch = if (git branch --list "main") { "main" }
                elseif (git branch --list "master") { "master" }
                else { $null }

  ######## GUARD CLAUSE : MAIN BRANCH NOT FOUND ########
  if (-not $mainBranch) {
    if ($DryRun) { return $false }
    return
  }

  ######## DEV BRANCH DATA RETRIEVAL ########
  # Identify dev branch (develop or dev)
  $devBranch = if (git branch --list "develop") { "develop" }
              elseif (git branch --list "dev") { "dev" }
              else { $null }

  ######## GUARD CLAUSE : DEV BRANCH NOT FOUND ########
  if (-not $devBranch) {
    if ($DryRun) {
      return $false
    }

    return
  }

  ######## LOGIC CHECK ########
  # Check for commits in Dev that are not in Main
  $unmergedCommits = git log "$mainBranch..$devBranch" --oneline -q 2>$null

  if ($DryRun) {
    return [bool]$unmergedCommits
  }

  ######## GUARD CLAUSE : ALREADY MERGED ########
  # If result is empty, everything is merged, so we exit
  if (-not $unmergedCommits) { return }

  ######## SHOW ADVICE ########
  Write-Host -NoNewline "ℹ️ $devBranch" -ForegroundColor Magenta
  Write-Host -NoNewline " has commits that are not in " -ForegroundColor DarkYellow
  Write-Host -NoNewline "$mainBranch" -ForegroundColor Magenta
  Write-Host ". Think about merging ! ℹ️" -ForegroundColor DarkYellow
}

##########---------- Restore user to original branch ----------##########
function Restore-UserLocation {
  param (
    [bool]$RepoIsSafe,
    [string]$OriginalBranch,
    [bool]$OriginalWasDeleted,
    [switch]$DryRun
  )

  ######## GUARD CLAUSE : UNSAFE REPO STATE ########
  # Repository isn't in a safe mode, cannot switch branches safely
  if (-not $RepoIsSafe) {
    if ($DryRun) { return $false }

    Write-Host "⚠️ Repo is in an unstable state. Can't return to the branch where you were ! ⚠️" -ForegroundColor Red
    return
  }

  ######## GUARD CLAUSE : ORIGINAL BRANCH DELETED ########
  # Original branch was removed during cleaning, switch to a fallback branch
  if ($OriginalWasDeleted) {
    if ($DryRun) { return $true }

    Write-Host -NoNewline "⚡ Original branch " -ForegroundColor Magenta
    Write-Host -NoNewline "$OriginalBranch" -ForegroundColor Red
    Write-Host " has been deleted..." -ForegroundColor Magenta

    # Determine fallback branch priority
    $fallbackBranch = if (git branch --list "develop") { "develop" }
                      elseif (git branch --list "dev") { "dev" }
                      elseif (git branch --list "main") { "main" }
                      else { "master" }

    Write-Host -NoNewline "😍 You have been moved to " -ForegroundColor DarkYellow
    Write-Host -NoNewline "$fallbackBranch" -ForegroundColor Magenta
    Write-Host " branch 😍" -ForegroundColor DarkYellow

    git checkout $fallbackBranch *> $null
    return
  }

  ######## DATA RETRIEVAL ########
  # Retrieves branch on which script finished its work
  $currentBranch = git rev-parse --abbrev-ref HEAD

  ######## GUARD CLAUSE : ALREADY ON TARGET ########
  # If we are already on original branch, we do nothing and we say nothing
  if ($currentBranch -eq $OriginalBranch) {
    if ($DryRun) { return $false }

    return
  }

  ######## STANDARD RETURN ########
  if ($DryRun) { return $true }

  # Otherwise, we go there and display it
  git checkout $OriginalBranch *> $null

  Write-Host -NoNewline "👌 Place it back on the branch where you were => " -ForegroundColor Magenta
  Write-Host "$OriginalBranch" -ForegroundColor Red
}

##########---------- Check and warn about stashes on a branch ----------##########
function Show-StashWarning {
  param (
    [string]$BranchName
  )

  # Retrieves raw list as text
  $stashList = git stash list --no-color

  # Filter to keep only lines relevant to our branch
  $branchStashes = $stashList | Where-Object { $_ -match "On ${BranchName}:" }

  if ($branchStashes) {
    Write-Host -NoNewline "⚠️ WARNING : There are stashes on branch " -ForegroundColor Red
    Write-Host -NoNewline "$BranchName" -ForegroundColor Magenta
    Write-Host " ⚠️" -ForegroundColor Red

    foreach ($line in $branchStashes) {
      # Display stash line
      Write-Host "  - $line" -ForegroundColor DarkCyan

      # Extract stash Id with regex (ex: stash@{0})
      if ($line -match "stash@\{\d+\}") {
        $stashId = $matches[0].Trim()

        # Get files list in this stash
        $files = @(git stash show --name-only --include-untracked $stashId 2>&1)

        # If command fails (old Git), we try again without untracked option
        if ($LASTEXITCODE -ne 0) {
          $files = @(git stash show --name-only $stashId 2>&1)
        }

        if ($files.Count -gt 0) {
          foreach ($file in $files) {
            # Converts to string to be safe (in case it's an error object)
            $fileString = "$file".Trim()

            if (-not [string]::IsNullOrWhiteSpace($fileString)) {
              # Display files
              Write-Host "   $fileString" -ForegroundColor Gray
            }
          }
        }
      }
    }

    Write-Host "ℹ️ Deleting branch doesn't delete stash but you will lose context of it" -ForegroundColor Magenta
  }
}

##########---------- Display HTTP errors ----------##########
function Show-GitHubHttpError {
  param (
    [Parameter(Mandatory=$true)]
    [int]$StatusCode,

    [Parameter(Mandatory=$true)]
    [string]$RepoName,

    [Parameter(Mandatory=$false)]
    [string]$ErrorMessage
  )

  ######## ERROR DISPATCHING ########
  switch ($StatusCode) {
    # Server Errors (all 500+ code)
    { $_ -ge 500 } {
      Write-Host -NoNewline "🔥 "
      Write-Host -NoNewline "GitHub server error (" -ForegroundColor Red
      Write-Host -NoNewline "$StatusCode" -ForegroundColor Magenta
      Write-Host "). GitHub's fault, not yours ! Try later... 🔥" -ForegroundColor Red
      return
    }

    # Not Found
    404 {
      Write-Host -NoNewline "⚠️ "
      Write-Host -NoNewline "Remote repository " -ForegroundColor Red
      Write-Host -NoNewline "$RepoName" -ForegroundColor white -BackgroundColor DarkBlue
      Write-Host " doesn't exist ⚠️" -ForegroundColor Red
      return
    }

    # Rate Limit
    403 {
      Write-Host "󰊤 GitHub API rate limit exceeded! Try again later or authenticate to increase your rate limit. 󰊤" -ForegroundColor Red
      return
    }

    # Unauthorized
    401 {
      Write-Host "󰊤 Check your personal token defined in your settings 󰊤" -ForegroundColor Red
      return
    }

    # Default/Other HTTP errors
    Default {
      Write-Host "⚠️ HTTP Error $StatusCode : $ErrorMessage" -ForegroundColor Red
    }
  }
}

##########---------- Display Network/System errors ----------##########
function Show-NetworkOrSystemError {
  param (
    [Parameter(Mandatory=$true)]
    [string]$RepoName,

    [Parameter(Mandatory=$true)]
    [string]$Message
  )

  ######## ERROR TYPE : NETWORK ########
  # Network problem (DNS, unplugged cable, firewall, no internet ...)
  if ($Message -match "remote name could not be resolved" -or $Message -match "connect" -or $Message -match "timed out") {
    Write-Host -NoNewline "💀 "
    Write-Host -NoNewline "Network error for " -ForegroundColor Red
    Write-Host -NoNewline "$RepoName" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host ". Unable to connect to GitHub, maybe check your connection or your firewall ! 💀" -ForegroundColor Red
  }

  ######## ERROR TYPE : INTERNAL/SCRIPT ########
  # Script or Git processing error (fallback)
  else {
    Show-GracefulError -Message "💥 Internal Script/Git processing error 💥" -NoTrailingNewline

    # Debug message
    Show-TechnicalErrorDetail -Message $Message
  }
}

##########---------- Display update summary table ----------##########
function Show-UpdateSummary {
  param (
    [array]$ReportData
  )

  # If no data, no do anything
  if (-not $ReportData -or $ReportData.Count -eq 0) { return }

  Show-MainSeparator

  # Helper called to center table title nicely
  $title = "📊 UPDATE SUMMARY REPORT 📊"
  $padding = Get-CenteredPadding -RawMessage $title

  # Display table title
  Write-Host -NoNewline $padding
  Write-Host $title -ForegroundColor Cyan
  Write-Host ""


  ######## TABLE WIDTHS (fixed at 64 characters) ########
  $colRepoWidth = 24
  $colStatWidth = 24
  $colTimeWidth = 16

  $fixedTableWidth = $colRepoWidth + $colStatWidth + $colTimeWidth

  ######## TABLE CENTERING (Dynamic) ########
  $tableOuterPadding = " " * 8
  # Calculation of exterior padding based on overall width
  $outerPaddingLength = [math]::Max(0, [int](($Global:TerminalWidth - $fixedTableWidth) / 2))
  $tableOuterPadding = " " * $outerPaddingLength

  # Headers (manual format for color control)
  Write-Host -NoNewline $tableOuterPadding
  Write-Host -NoNewline "Repository              " -ForegroundColor White -BackgroundColor DarkGray
  Write-Host -NoNewline "        Status          " -ForegroundColor White -BackgroundColor DarkGray
  Write-Host -NoNewline "        Duration" -ForegroundColor White -BackgroundColor DarkGray
  Write-Host ""

  # Loop on results
  foreach ($item in $ReportData) {
    # Icon Definition + Color
    $statusText = $item.Status
    $statusColor = "White"

    switch ($item.Status) {
      "Already-Updated"   { $statusText = "✨ Already Updated";    $statusColor = "DarkCyan"   }
      "Cloned"            { $statusText = "🐙 Cloned";             $statusColor = "Cyan"       }
      "Failed"            { $statusText = "❌ Failed";             $statusColor = "Red"        }
      "Ignored"           { $statusText = "🙈 Ignored";            $statusColor = "Magenta"    }
      "Skipped"           { $statusText = "⏩ Skipped";            $statusColor = "DarkYellow" }
      "Updated"           { $statusText = "✅ Updated";            $statusColor = "Green"      }
    }

    ######## STATUS CENTERING ########
    $statLen = $statusText.Length
    # Manual adjustment for emojis that count double on screen
    if ($statusText -match "✅|✨|⏩|❌") {
      $statLen += 1
    }

    $padStatLeft = [math]::Max(0, [int](($colStatWidth - $statLen) / 2))
    $padStatStr = " " * $padStatLeft

    ######## OVERALL MARGIN ########
    Write-Host -NoNewline $tableOuterPadding

    ######## COLUMN 1 (Left aligned) ########
    Write-Host -NoNewline ("{0,-$colRepoWidth}" -f $item.Repo) -ForegroundColor Cyan

    ######## COLUMN 2 (Centered)) ########
    Write-Host -NoNewline $padStatStr
    Write-Host -NoNewline $statusText -ForegroundColor $statusColor

    # Calculating the remaining padding to align next column
    $padStatRightLen = $colStatWidth - $padStatLeft - $statLen
    if ($padStatRightLen -gt 0) {
      Write-Host -NoNewline (" " * $padStatRightLen)
    }

    ######## COLUMN 3 (Right align) ########
    $timeString = "{0,$colTimeWidth}" -f $item.Time
    Write-Host $timeString -ForegroundColor Magenta
  }
}

##########---------- Start a stopwatch timer ----------##########
function Start-OperationTimer {
  return [System.Diagnostics.Stopwatch]::StartNew()
}

##########---------- Stop timer and display elapsed time ----------##########
function Stop-OperationTimer {
  param (
    [System.Diagnostics.Stopwatch]$Watch,
    [switch]$IsGlobal,
    [string]$RepoName = ""
  )

  $Watch.Stop()
  $time = $Watch.Elapsed

  ######## TEXT TIME CALCULATION ########
  $timeString = ""
  if ($time.TotalMinutes -ge 1) {
    $timeString = "$($time.ToString("mm'm 'ss's'"))"
  }
  else {
    # If was very quick (<1s), we display in ms
    if (-not $IsGlobal -and $time.TotalSeconds -lt 1) {
      $timeString = "$($time.TotalMilliseconds.ToString("0"))ms"
    }
    else {
      $timeString = "$($time.ToString("ss's'"))"
    }
  }

  ######## GLOBAL TIME ########
  if ($IsGlobal) {
    Show-MainSeparator

    # Helper called to center message nicely
    $msg = "✨ All completed in $timeString ✨"
    $paddingStr = Get-CenteredPadding -RawMessage $msg

    # Display global timer
    Write-Host -NoNewline $paddingStr
    Write-Host -NoNewline "✨ All completed in " -ForegroundColor Green
    Write-Host -NoNewline "$timeString" -ForegroundColor Magenta
    Write-Host " ✨" -ForegroundColor Green
  }
  ######## REPOSITORY TIME ########
  else {
    Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkBlue

    # Helper called to center message nicely
    $msg = "⏱️ $RepoName updated in $timeString ⏱️"
    $paddingStr = Get-CenteredPadding -RawMessage $msg

    # Display repository timer
    Write-Host ""
    Write-Host -NoNewline $paddingStr
    Write-Host -NoNewline "⏱️ "
    Write-Host -NoNewline "$repoName" -ForegroundColor white -BackgroundColor DarkBlue
    Write-Host -NoNewline " updated in " -ForegroundColor Green
    Write-Host "$timeString ⏱️" -ForegroundColor Magenta
  }
}
