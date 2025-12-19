# POWERSHELL UPDATE GIT REPOSITORIES SCRIPT

## SOMMAIRE

- [INTRO](#intro)
- [WHY THIS SCRIPT](#why-this-script)
- [WORKFLOW](#workflow)
- [REQUIREMENTS](#requirements)
- [INSTALLATION PROCEDURE](#installation-procedure)
- [BONUS](#bonus)
- [CONSOLE APPLICATION SCREENS](#console-application-screens)

## INTRO

🚀 No more struggling to sync Git between my desktop PC and my laptop ! 🚀  

This documentation details the architecture of Update-GitRepositories, a PowerShell automation module acting as a local orchestrator. It is designed to maintain the integrity of your development environment by updating, cleaning, and synchronizing all your local repositories with a single command or automatically at startup.  

## WHY THIS SCRIPT

😫 **The Problems =>**  

1. 🔄 **Sync Anxiety & Multi-Machine Chaos**  
Working on a desktop and a laptop often leads to "Drift". You start coding on your laptop, realizing too late that you forgot to pull the latest changes you made yesterday on your desktop.  

- **Solution,** this script runs automatically at startup. You sit down, and your machine is already up-to-date.
- **Peace of Mind,** eliminates the risk of working on an outdated version or facing avoidable merge conflicts.

2. 🧠 **Mental Load & Repetitive Tasks**  
Manually checking 10, 20, or 30 repositories every morning is a waste of mental energy. A simple batch script often fails because it blindly tries to pull without context.  

- **Solution,** an intelligent Orchestrator. It iterates through your specific list of active projects, skipping the irrelevant ones.
- **Efficiency**, one shortcut, 2 seconds of execution, 100% visibility.

3. 🛡️ **Safety & "Dirty" State Protection**  
Standard scripts break things. If you have uncommitted work (dirty tree) or unpushed commits, a blind git pull can create a mess.  

- **Solution,** the script features strict Guard Clauses. It checks if your workspace is clean before touching anything.
- **Bot Detection :** it automatically detects and resets specific bot branches (like output) to ensure they match the remote exactly.

4. 🆕 **New Machine Setup**  
When switching to a new laptop, I used to spend hours manually cloning my 30+ repositories one by one.  

- **Solution,** just copy this script and the config. Run gpull. It detects missing folders and offers to clone everything for you. Instant setup.

5. 📍 **Context Awareness (The "Smart Restore")**  
Most update scripts force a checkout to main, pulling changes, and leave you there. You lose your spot.  

- **State Preservation,** the script remembers you were on feature/login-page. It switches to main, updates it, cleans up old branches, and puts you back exactly where you were.

6. 🧹 **Hygiene & Garbage Collection**  
Over time, local repositories get cluttered with dead branches (feature/done-3-months-ago) that have already been merged or deleted remotely.  

- **Garbage Collector,** it proactively purposes to delete orphaned branches (: gone) and fully merged branches, keeping your local list clean.

🏗 **ARCHITECTURE**  

Flow Controller based on iterative & sequential, stateless and awareness.  

🧠 **PHILOSOPHY**

- **Safety First (Guard Clause)**
- **UX**
- **Cross-Platform**

⚡ **TRIGGER**

- **Event-Driven** (startup computer)
- **GUI** (desktop shortcut)
- **CLI** (alias Powershell: gpull)

🛠️ **FEATURES**

1. 📦 **Multi-Branch Update**

- **Prioritization,** main and develop branches
- **Targeting,** optional parameter for updating 1 repository
- **Read-Only Mode,** able to restrict updates to main/master only (IsOnlyMain). Ideal for documentation or course repositories where you don't need feature branches.
- **Silent Auto-Update** on integration branches
- **Interactive Mode** on incoming commits from other branches
- **Bot Detection** (sync force)

2. 🧹 **Garbage Collector**

- **Orphaned Cleanup,** detects/removes orphaned branches (interactive)
- **Merged Cleanup,** identifies/removes already merged branches (interactive)
- **Protection,** prevents the deletion of an integration branch

3. 🛡️ **Safety and Integrity (Safety Checks)**

- **Dirty Tree Protection,** pull canceled if files are not committed
- **Unpushed Protection,** pull canceled if local commits are not pushed
- **Stash Warning**

4. 🎛️ **Context Awareness & Restoration**

- **State Preservation,** remembers the active branch
- **Smart Restore,** replaces the user on the original branch
- **Fallback Logic,** if the original branch is deleted, replace the user on the development branch.

5. 🔍 **Divergence Analysis**

- **History Analysis,** calculates the number of commits Ahead/Behind
- **Log Preview,** displays the latest incoming commit messages
- **Divergence Alert,** detects divergent histories

6. 🛰️ **Discovery and Monitoring**

- **New Branch Detection,** scans the remote branch to track new remote branches
- **Tracking Proposal,** creates a local branch (or interactively deletes an obsolete branch)

7. 🏗️ **Auto-Provisioning & Onboarding**
New computer? No problem.  

- **Missing Repo Detection,** if a repository defined in your config doesn't exist locally, the script doesn't fail
- **Remote Validation,** it queries the GitHub API to ensure the repository actually exists (avoiding errors on typos)
- **Interactive Cloning,** it proposes to clone the missing repository via SSH immediately
- **Auto-Structure,** it automatically creates missing parent directories (if the Projets folder is missing, it creates it)

5. 📈 **Visual and Concise Reporting**

- **Real-Time Feedback**
- **Summary Table,** status and precise duration for each repository
- **UI Polish,** dynamic separators and text centering

9. 🔐 **GitHub API Integration and Security**

- **Repository access via GitHub API** + pre-verification of repository existence and access rights
- **Secure Configuration,** Environment Variables (Token/Username)

10. ⏱️ **Performance and Caching**

- **Metrics,** global and individual timers
- **Session Cache,** load configuration once per session

11. 🌐 **Granular and Resilient Error Handling**

- **HTTP context,** API error differentiation
- **Network Resilience,** timeout and DNS management without crashing the orchestrator
- **Isolation** in case of repository failure (Try/Catch pattern)

👌 Others many controls and features have been added 👌

## REQUIREMENTS

PowerShell Core is the cross-platform version of PowerShell, built on .NET Core. It works on Windows, Linux, and macOS. It is distinct from Windows PowerShell (v5.1 and earlier), which is still shipped with Windows but is no longer actively developed with new features.  
For cross-platform scripting and modern features, PowerShell 7 (or higher) is the recommended version.  

⚠️ You NEED to install it ! ⚠️  

## WORKFLOW

1. **Initialization :**  
The Get-DefaultGlobalGitIgnoreTemplate function holds the source of truth (OS files, IDEs, Languages...).

2. **Validation Loop :**  
Iterates through the defined repository list (triggered by Update-GitRepositories or its alias gpull).

- **Existence Check :**  
If missing : Checks GitHub API -> Proposes Clone -> Clones -> Marks as "✨ Cloned"  
If present : proceeds to standard checks
- **Integrity Check :**  
Verifies the folder exists and is a valid Git repository
- **Security Check :**  
Ensures the local origin remote matches the expected GitHub URL

3. **Update Strategy :**

- **Fetch :**  
Performs a git fetch --prune to refresh remote references
- **Prioritize :**  
Sorts branches (Main/Master -> Dev/Develop -> others)
- **Action :**  
Auto-updates integration branches + triggers Interactive Mode for feature branches

4. **Maintenance: :**

- **Safety :**  
Blocks updates if the working tree is dirty or has unpushed commits
- **Cleanup :**  
Proposes deletion for orphaned (gone) or fully merged branches

5. **Reporting :**  
Generates a summary table with execution time and status :  

- ✨ Already Updated
- 🐙 Cloned
- ❌ Failed
- 🙈 Ignored
- ⏩ Skipped
- ✅ Updated

## INSTALLATION PROCEDURE

### Setup the desktop shortkey (Windows only)

1. For Windows 10 get the fully path where PowerShell was installed :

```shell
(Get-Command pwsh).Source
```

2. Right click on desktop > "New" > "Shortcut"

3. In the window that opens, enter this line =>

💡 Consider replacing the installation path of your file "run_powershell_git_pull_script.ps1" with yours, it may be different!  

- Windows 10

```shell
Start-Process -FilePath "C:\Program Files\WindowsApps\Microsoft.PowerShell_7.5.4.0_x64__8wekyb3d8bbwe\pwsh.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"C:\Users\darka\Documents\PowerShell\run_powershell_git_pull_script.ps1`"" -NoNewWindow -Wait
```

⚠️ Also pay attention to the version of powershell installed if you use Windows 10 ...

- Windows 11

```shell
wt.exe -p "PowerShell" pwsh.exe -ExecutionPolicy Bypass -File "C:\Users\<UserName>\Documents\PowerShell\run_powershell_git_pull_script.ps1"
```

4. "Next" button

5. Give the shortcut the name you like.

6. "Finish" button

7. Create the folder (if it doesn't already exist) :  

```powershell
$dir = Split-Path $PROFILE -Parent; if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory }; Set-Location $dir
```

8. Create the file (if it doesn't already exist) :  

```powershell
if (!(Test-Path ".\Microsoft.PowerShell_profile.ps1")) { New-Item ".\Microsoft.PowerShell_profile.ps1" -ItemType File }
```

9. Copy/Paste this inside the new file

```powershell
# Load PowerShell Profile dynamically (works on all OS paths)
. $PROFILE

# Call function
Update-GitRepositories

# Close terminal
Write-Host ""
Read-Host -Prompt "Press Enter to close... "
```

10. ❤️ Additionally give the shortcut a nice icon ❤️

💡 On Windows 10, by default the created shortcut will not have the black PowerShell 7 icon but an other ugly one, you can assign the correct one like this (or the Git one).

Right click on shortcut > Properties > Change icon
Icons paths:

```shell
C:\Program Files\WindowsApps\Microsoft.PowerShell_7.5.4.0_x64__8wekyb3d8bbwe\pwsh.exe
```

```shell
C:\Program Files\Git\git-bash.exe
```

### Setup for all OS start here

1. ⚠️ I you don't use a personal token to request the Github API this script will not work. To set up an identification token on the Github API and environements variables, go lower...

![Script Screen](https://github.com/EmmanuelLefevre/MarkdownImg/blob/main/git_pull_script.png)

Request the github api with a personnal token increase the rate limit and allow you to update a private repository...

- On github.com:

Settings > Developer settings > Personal access tokens > Tokens (classic) > Generate new token > Generate new token (classic)

- Input "Note": Your token name...
- Expiration option: "No expiration"
- Tick checkbox: "repo"
- Click on "Generate token"

⚠️ Be careful to copy your token because it will no longer be visible afterwards!

### On windows

Setup your username and token in the environment variables.
![First Step](https://github.com/EmmanuelLefevre/MarkdownImg/blob/main/git_pull_script_config_environement_variable_step_1.png)  

![Second Step](https://github.com/EmmanuelLefevre/MarkdownImg/blob/main/git_pull_script_config_environement_variable_step_2.png)

Repeat operation for the username...  

### On Linux / macOS

Open your PowerShell profile with your favorite editor.  

```powershell
nano $PROFILE
```

Add these two lines at the top of the file (replace with your real credentials) :  

```powershell
$env:GITHUB_TOKEN = "ghp_YourGeneratedTokenHere..."
$env:GITHUB_USERNAME = "YourGitHubUsername"
```

Save and exit, reload your profile now :  

```powershell
. $PROFILE
```

🔒 **Security Tip :**  
Since this file contains a secret token, it is recommended to restrict read permissions to your user only.  

```powershell
chmod 600 $PROFILE
```

2. Now you must open your "Microsoft.PowerShell_profile.ps1" file in your favorite text editor.

3. Clone this repository in:

```powershell
Set-Location (Split-Path $PROFILE -Parent)
```

4. Now you can use the function in your terminal by typing the alias and press ENTER :

```powershell
gpull
```

Or launch it with the desktop shortcut 🔥🔥🔥

## Bonus

🧠 You can easily launch script automatically at your computer starts 🧠

### Windows

**Win + R** -> type `shell:startup`  
Copy (Ctrl+C) your desktop shortcut and paste it in the "Getting Started" folder...  

Now the script will be launched every time you start your PC 💪

### Linux

Unlike Windows, Linux uses .desktop files for startup items.  

1. Create the autostart directory (if it doesn't exist).

```bash
mkdir -p ~/.config/autostart
```

2. Create the shortcut file.

```bash
nano ~/.config/autostart/git-auto-update.desktop
```

3. Paste this content inside : this configuration opens a terminal, loads your profile and runs the function.

```Ini, TOML
[Desktop Entry]
Type=Application
Name=Global Git Update
Comment=Update all git repositories on login
# Command: Launch PowerShell, Load Profile, Run Function, Wait for user
Exec=pwsh -Command "& { . $PROFILE; Update-GitRepositories; Read-Host 'Press Enter to close...' }"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Terminal=true
```

4. Save and Exit.

5. Restart your session.

Now the script will be launched every time you start your PC 💪

### macOS

macOS treats files with the .command extension as clickable shell scripts that automatically open the Terminal.  

1. Create the launcher file : open your terminal and create a file in your Documents folder (or anywhere you like).

```bash
nano ~/Documents/StartGitUpdate.command
```

2. Paste this content inside : this script invokes PowerShell, loads your profile (to get tokens and functions), runs the update, and waits for user input.

```bash
#!/bin/bash
echo "🚀 Starting Global Git Update..."
pwsh -Command "& { . $PROFILE; Update-GitRepositories; Read-Host 'Press Enter to close...' }"
```

3. Save and Exit.

4. Make it executable : this step is mandatory to allow macOS to run the file.

```bash
chmod +x ~/Documents/StartGitUpdate.command
```

5. Add to Login Items :  

- Open System Settings > General > Login Items
- Click the (+) button.
- Select your file ~/Documents/StartGitUpdate.command.

Now, every time you log in, a Terminal window will pop up, update your repos, and wait for you to check the green ticks ✅ before closing.

## Console Application Screens

![Script Screen](https://github.com/EmmanuelLefevre/MarkdownImg/blob/main/git_pull_script_2.png)
<br><br><br>
![Script Screen](https://github.com/EmmanuelLefevre/MarkdownImg/blob/main/git_pull_script_3.png)

***

⭐⭐⭐ I hope you enjoy it, if so don't hesitate to leave a star on this repository. Thanks 🤗
