function Update-GitRepositories {
  [CmdletBinding()]
  param (
    # Force repository information reloading
    [switch]$RefreshCache,
    # Optional parameter to update only one repository
    [string]$Name
  )

  if ($Name) {
    Show-HeaderFrame -Title "UPDATING LOCAL REPOSITORY"
  }
  else {
    Show-HeaderFrame -Title "UPDATING LOCAL REPOSITORIES"
  }

  ######## GUARD CLAUSE : GIT AVAILABILITY ########
  if (-not (Test-GitAvailability)) {
    return
  }

  ######## START GLOBAL TIMER ########
  $globalTimer = Start-OperationTimer

  ######## CACHE MANAGEMENT ########
  # If cache doesn't exist or if a refresh is forced
  if (-not $Global:GitReposCache -or $RefreshCache) {
    # Helper called to center message nicely
    $msg = "🔄 Updating repositories informations... 🔄"
    $paddingStr = Get-CenteredPadding -RawMessage $msg

    # Display message
    Write-Host -NoNewline $paddingStr
    Write-Host $msg -ForegroundColor Cyan

    ######## DATA RETRIEVAL ########
    # Function is called only once
    $tempReposInfo = Get-RepositoriesInfo

    ######## GUARD CLAUSE : INVALID CONFIGURATION ########
    # Validate result before caching it
    if ($tempReposInfo -eq $null) {
      # Helper called to center message nicely
      $msg = "⛔ Script stopped due to an invalid configuration ! ⛔"
      $paddingStr = Get-CenteredPadding -RawMessage $msg

      # Display message
      Write-Host -NoNewline $paddingStr
      Write-Host $msg -ForegroundColor Red

      # Exit function
      return
    }

    # If everything is valid cache is created
    $Global:GitReposCache = @{
      ReposInfo = $tempReposInfo
    }
  }

  ######## DATA RETRIEVAL ########
  # Retrieve repositories information from cache
  $reposInfo  = $Global:GitReposCache.ReposInfo

  $reposOrder    = $reposInfo.Order
  $repos         = $reposInfo.Paths
  $username      = $reposInfo.Username
  $token         = $reposInfo.Token
  $reposSettings = $reposInfo.Settings

  ######## LAUNCH SCRIPT FOR A SINGLE REPO ########
  $reposToProcess = Get-RepoListToProcess -FullList $reposOrder -TargetName $Name
  # If helper returns `$null` (repo not found), we stop everything
  if ($null -eq $reposToProcess) {
    return
  }

  # Flag initialization
  $isFirstRepo = $true

  # Init summary table list
  $summaryTableList = @()

  ######## REPOSITORY ITERATION ########
  # Iterate over each repository in the defined order
  foreach ($repoName in $reposToProcess) {
    ######## START REPOSITORY TIMER ########
    $repoTimer = Start-OperationTimer

    ######## UPDATING SUMMARY TABLE STATUS ########
    $summaryTableCurrentStatus = "Skipped"

    try {
      ######## DATA SETUP ########
      $repoPath = $repos[$repoName]

      ######## UI : SEPARATOR MANAGEMENT ########
      # Display main separator (except first)
      if (-not $isFirstRepo) {
        Show-MainSeparator
      }
      # Mark first loop is finished
      $isFirstRepo = $false

      ######## GUARD CLAUSE : PATH EXISTS / CLONE PROPOSAL ########
      # Use -Silent to avoid error message, treating absence as an opportunity
      if (-not (Test-LocalRepoExists -Path $repoPath -Name $repoName -Silent)) {

        # Call clone manager
        $cloneStatus = Invoke-InteractiveClone -RepoName $repoName -RepoPath $repoPath -UserName $username

        # Dispatch result
        if ($cloneStatus -eq 'Success') {
          $summaryTableCurrentStatus = "✨ Cloned"

          # Skip rest of loop (pull/cleanup) => fresh clone is already perfect
          continue
        }
        elseif ($cloneStatus -eq 'Skipped') {
          $summaryTableCurrentStatus = "Ignored"

          continue
        }
        else {
          $summaryTableCurrentStatus = "Failed"

          continue
        }
      }

      ######## GUARD CLAUSE : NOT A GIT REPO ########
      if (-not (Test-IsGitRepository -Path $repoPath -Name $repoName)) {
        $summaryTableCurrentStatus = "Ignored"

        # Go finally block (and after next repository)
        continue
      }

      # Change current directory to repository path
      Set-Location -Path $repoPath

      ######## GUARD CLAUSE : REMOTE MISMATCH ########
      # Check local remote matches GitHub info
      if (-not (Test-LocalRemoteMatch -UserName $username -RepoName $repoName)) {
        $summaryTableCurrentStatus = "Ignored"

        # Go finally block (and after next repository)
        continue
      }

      ######## MAIN PROCESS ########
      # Show repository name being updated
      Write-Host -NoNewline "🚀 "
      Write-Host -NoNewline "$repoName" -ForegroundColor white -BackgroundColor DarkBlue
      Write-Host " is on update process..." -ForegroundColor Green

      ######## API CALL ########
      # Check for remote repository existence using GitHub API with authentication token
      $repoUrl = "https://api.github.com/repos/$username/$repoName"
      $response = Invoke-RestMethod -Uri $repoUrl -Method Get -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop

      # Store original branch to return it later (Trim removes invisible blank spaces)
      $originalBranch = (git rev-parse --abbrev-ref HEAD).Trim()

      # Fetch latest remote changes
      git fetch --prune --quiet

      # Display date of last remote commit
      Show-LastCommitDate

      ######## GUARD CLAUSE : FETCH FAILED ########
      if (-not (Test-GitFetchSuccess -ExitCode $LASTEXITCODE)) {
        $repoIsInSafeState = $false
        $summaryTableCurrentStatus = "Failed"

        # Go finally block (and after next repository)
        continue
      }

      ######## DATA RETRIEVAL : TRACKED BRANCHES ########
      # Find all local branches that have a remote upstream
      $branchesToUpdate = @(Get-LocalBranchesWithUpstream)

      ######## LOGIC : ONLY MAIN FILTER ########
      # Check if specific repo is configured to pull only main/master
      if ($reposSettings[$repoName] -eq $true) {
        # Keep only branches strictly named "main" or "master"
        $branchesToUpdate = @($branchesToUpdate | Where-Object { $_.Local -match '^(main|master)$' })

        if ($branchesToUpdate) {
          $msgPrefix = "ℹ️ Configured to pull "
          $msgBranch = "MAIN"
          $msgSuffix = " branch only ℹ️"

          $fullMsg = $msgPrefix + $msgBranch + $msgSuffix

          Write-Host -NoNewline (Get-CenteredPadding -RawMessage $fullMsg)
          Write-Host -NoNewline $msgPrefix -ForegroundColor DarkYellow
          Write-Host -NoNewline $msgBranch -ForegroundColor Magenta
          Write-Host -NoNewline $msgSuffix -ForegroundColor DarkYellow
          Write-Host ""
        }
      }

      ######## GUARD CLAUSE : NO UPSTREAM ########
      # If no branch has an upstream defined, nothing to update or clean up
      if (-not $branchesToUpdate) {
        Write-Host "ℹ️ No upstream defined ! Nothing to update or clean up for this repository ! ℹ️" -ForegroundColor DarkYellow

        $summaryTableCurrentStatus = "Ignored"

        # Go finally block (and after next repository)
        continue
      }

      ######## BRANCH PROCESSING : SORTING ########
      # Organize branches : Main -> Dev -> Others by alphabetical
      $sortedBranchesToUpdate = Get-SortedBranches -Branches $branchesToUpdate

      # Track repository state
      $repoIsInSafeState = $true

      # Track if any branch needed a pull
      $anyBranchNeededPull = $false

      # Track if ALL branches were processed successfully (no skip, no fail)
      $allBranchesWerePulled = $true

      # Separator control
      $branchCount = $sortedBranchesToUpdate.Count
      $i = 0

      # Assume up-to-date until proven otherwise
      $summaryTableCurrentStatus = "Already-Updated"

      ######## UPDATE LOOP ########
      # Iterate over each branch found to pull updates from remote
      foreach ($branch in $sortedBranchesToUpdate) {
        # Increment iteration counter
        $i++

        ######## GUARD CLAUSE : CHECKOUT ########
        if (-not (Invoke-SafeCheckout -TargetBranch $branch.Local`
                                      -OriginalBranch $originalBranch)) {
          $repoIsInSafeState = $false
          $summaryTableCurrentStatus = "Failed"
          $allBranchesWerePulled = $false

          # Stop processing branches for this repo (fatal error)
          break
        }

        ######## STRATEGY : BOT BRANCHES (OUTPUT) ########
        $botSyncStatus = Invoke-BotBranchSync -BranchName $branch.Local

        if ($botSyncStatus -ne 'NotBot') {
          if ($botSyncStatus -eq 'Updated') {
            $summaryTableCurrentStatus = "Updated"
          }
          else {
            $summaryTableCurrentStatus = "Failed"
            $allBranchesWerePulled = $false
          }

          # If not last branch, display separator
          if ($i -lt $branchCount) {
            Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
          }

          # Jump to next branch in list
          continue
        }

        ######## GUARD CLAUSE : LOCAL CONFLICTS ########
        if (-not (Test-WorkingTreeClean -BranchName $branch.Local)) {
          if ($summaryTableCurrentStatus -ne "Failed") {
            $summaryTableCurrentStatus = "Skipped"
          }

          $allBranchesWerePulled = $false

          # Jump to next branch in list
          continue
        }

        ######## GUARD CLAUSE : UNPUSHED COMMITS ########
        if (Test-UnpushedCommits -BranchName $branch.Local) {
          if ($summaryTableCurrentStatus -ne "Failed") {
            $summaryTableCurrentStatus = "Skipped"
          }

          $allBranchesWerePulled = $false

          # Jump to next branch in list
          continue
        }

        ######## GUARD CLAUSE : ALREADY UPDATED ########
        if (Test-IsUpToDate -LocalBranch $branch.Local `
                            -RemoteBranch $branch.Remote) {

          # If not last branch, display separator
          if ($i -lt $branchCount) {
            Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
          }

          # Jump to next branch in list
          continue
        }

        ######## PULL PROCESS ########
        # If we get here, a branch needs a pull
        $anyBranchNeededPull = $true

        # Execute the update strategy and get the result status
        $updateStatus = Invoke-BranchUpdateStrategy -LocalBranch $branch.Local `
                                                    -RemoteBranch $branch.Remote `
                                                    -RepoName $repoName

        ######## GUARD CLAUSE : UPDATE FAILED ########
        # Update was successfull
        if ($updateStatus -eq 'Success') {
          if ($summaryTableCurrentStatus -ne "Failed" -and $summaryTableCurrentStatus -ne "Skipped") {
            $summaryTableCurrentStatus = "Updated"
          }
        }
        # Update failed
        elseif ($updateStatus -eq 'Failed') {
          $summaryTableCurrentStatus = "Failed"
          $repoIsInSafeState = $false
          $allBranchesWerePulled = $false

          # Stop processing branches for this repo
          break
        }
        # Update Skipped (User said No)
        elseif ($updateStatus -eq 'Skipped') {
          $allBranchesWerePulled = $false

          # Update status of summary table
          if ($summaryTableCurrentStatus -ne "Failed") {
            $summaryTableCurrentStatus = "Skipped"
          }
        }

        # If execution was successful (Success or Skipped) and not last one, display separator
        if ($updateStatus -ne 'Failed' -and $i -lt $branchCount) {
          Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
        }
      }

      ######## POST-UPDATE ACTIONS (only if safe) ########
      # We check this flag because if a checkout failed (break), we must NOT try to cleanup
      if ($repoIsInSafeState) {
        ######## STATUS REPORT ########
        # If no branch needed pull and there was more than one branch to check
        if (($anyBranchNeededPull -eq $false) -and
            ($sortedBranchesToUpdate.Count -gt 1) -and
            ($allBranchesWerePulled -eq $true)) {
          Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray

          Write-Host "All branches are being updated 🤙" -ForegroundColor Green
        }

        ######## DETECT NEW BRANCHES ########
        # Calculate which remote branches are missing locally
        $newBranchesToTrack = Get-NewRemoteBranches

        ######## USER PERMISSION TO PULL NEW BRANCHES ########
        if (Invoke-NewBranchTracking -NewBranches $newBranchesToTrack) {
          $summaryTableCurrentStatus = "Failed"
        }

        # Track whether user's branch has been deleted
        [bool]$originalBranchWasDeleted = $false

        ######## CLEANUP : ORPHANED BRANCHES ########
        # Ask to clean branches that no longer exist on remote
        $orphanResult = Invoke-OrphanedCleanup -OriginalBranch $originalBranch
        if ($orphanResult.OriginalDeleted) {
          $originalBranchWasDeleted = $true
        }
        if ($orphanResult.HasError) {
          $summaryTableCurrentStatus = "Failed"
        }

        ######## CLEANUP : MERGED BRANCHES ########
        # Ask to clean branches that are already merged into main/dev
        $mergedResult = Invoke-MergedCleanup -OriginalBranch $originalBranch
        if ($mergedResult.OriginalDeleted) {
          $originalBranchWasDeleted = $true
        }
        if ($mergedResult.HasError) {
          $summaryTableCurrentStatus = "Failed"
        }

        ######## UI : PRE-CALCULATION ########
        $mergeWillDisplayMessage   = Show-MergeAdvice -DryRun
        $restoreWillDisplayMessage = Restore-UserLocation -RepoIsSafe $repoIsInSafeState `
                                                          -OriginalBranch $originalBranch `
                                                          -OriginalWasDeleted $originalBranchWasDeleted `
                                                          -DryRun

        ######## SEPARATOR MANAGEMENT ########
        # If one OR other
        if ($mergeWillDisplayMessage -or $restoreWillDisplayMessage) {
          Show-Separator -Length $Global:TerminalWidth -ForegroundColor DarkGray
        }

        ######## WORKFLOW INFO ########
        Show-MergeAdvice

        ######## RETURN STRATEGY ########
        Restore-UserLocation -OriginalBranch $originalBranch `
                            -RepoIsSafe $repoIsInSafeState `
                            -OriginalWasDeleted $originalBranchWasDeleted
      }
    }
    catch {
      ######## UPDATING SUMMARY TABLE STATUS ########
      $summaryTableCurrentStatus = "Failed"

      ######## ERROR CONTEXT ANALYSIS ########
      # Get HTTP response if exists (regardless of the error type)
      $responseError = $null

      # Response property exists on exception, so we take it
      if ($_.Exception.PSObject.Properties.Match('Response').Count) {
        $responseError = $_.Exception.Response
      }

      ######## ERROR HANDLER : HTTP ########
      # If we have a server response
      if ($null -ne $responseError) {
        Show-GitHubHttpError -StatusCode $responseError.StatusCode `
                            -RepoName $repoName `
                            -ErrorMessage $_.Exception.Message
      }

      ######## ERROR HANDLER : NETWORK / SYSTEM ########
      # No HTTP response
      else {
        Show-NetworkOrSystemError -RepoName $repoName `
                                  -Message $_.Exception.Message
      }
    }
    finally {
      ######## STOP TIMER ########
      $repoTimer.Stop()
      $elapsed = $repoTimer.Elapsed

      ######## FORMAT TIME ########
      $timeForTable = ""
      # Less than a second (Milliseconds)
      if ($elapsed.TotalSeconds -lt 1) {
        $timeForTable = "$($elapsed.TotalMilliseconds.ToString("0"))ms"
      }
      # More than a minute (Minutes + Seconds)
      elseif ($elapsed.TotalMinutes -ge 1) {
        $timeForTable = "$($elapsed.ToString("mm'm 'ss's'"))"
      }
      # Between 1s and 59s (Seconds)
      else {
        $timeForTable = "$($elapsed.ToString("ss's'"))"
      }

      ######## ADD TO SUMMARY TABLE ########
      $summaryTableList += [PSCustomObject]@{ Repo=$repoName; Status=$summaryTableCurrentStatus; Time=$timeForTable }

      ######## STOP REPOSITORY TIMER & DISPLAY ########
      Stop-OperationTimer -Watch $repoTimer -RepoName $repoName

      ######## RETURN HOME DIRECTORY ########
      Set-Location -Path $HOME
    }
  }

  ######## STOP GLOBAL TIMER & DISPLAY SUMMARY TABLE ########
  if ($reposToProcess.Count -gt 1) {
    Show-UpdateSummary -ReportData $summaryTableList
    Stop-OperationTimer -Watch $globalTimer -IsGlobal
  }
}
