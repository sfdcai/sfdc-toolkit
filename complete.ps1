<#
.SYNOPSIS
    The definitive, professional-grade PowerShell toolkit for Salesforce DevOps, featuring a
    full folder-based project structure, advanced deployment capabilities, and a 100% accurate,
    optimized delta generation engine.

.DESCRIPTION
    This script is a one-stop, interactive toolkit for Salesforce developers and admins.
    It provides a powerful, modern menu-driven interface to manage multiple, folder-based project
    profiles, check system readiness, authorize and manage orgs, generate manifests,
    and perform highly accurate org comparisons.

    It features a robust two-level logging system, a self-updating metadata map, comprehensive
    error handling, and an intelligent caching mechanism to avoid redundant retrievals.
    This version is fully portable and centrally managed via a remote configuration file.

.NOTES
    Author:      Amit Bhardwaj (Remotely Configured)
    Version:     14.1.3 (Parser and Logic Correction Release)
    Created:     2025-07-14
    License:     MIT
    Requires:    PowerShell 5.1+, Windows Terminal (Recommended), Salesforce CLI.
#>

#Requires -Version 5.1

#region Script Configuration and State
[CmdletBinding()]
param()

$Script:VERSION = "14.1.3"
$Script:AuthorName = "Amit Bhardwaj" # Default author name
$Script:AuthorLinkedIn = "linkedin.com/in/salesforce-technical-architect" # Default author link
$Script:TOOLKIT_ROOT_CONFIG_DIR = Join-Path -Path $PSScriptRoot -ChildPath ".sfdc-toolkit"
$Script:REMOTE_CONTROL_URL = "https://raw.githubusercontent.com/sfdcai/sfdc-toolkit/main/control.json"
$Script:ROOT_PROJECT_LIST_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "projects.json"
$Script:METADATA_MAP_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "metadata_map.json"
$Script:GLOBAL_LOG_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "toolkit.log"

# These variables are loaded on startup and after project selection
$Script:MetadataMap = @{}
$Script:ProjectRoot = $null
$Script:ProjectSettingsFile = $null
$Script:ProjectLogFile = $null
$Script:Settings = $null
#endregion

#region Core: Logging and Utilities

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("INFO", "WARN", "ERROR", "DEBUG")][string]$Level = "INFO"
    )

    # Respect the log level setting for the current project
    if ($Script:Settings -and $Script:Settings.logLevel -eq "INFO") {
        if ($Level -eq "DEBUG") { return }
    }

    $logFileToUse = if ($Script:ProjectRoot) { $Script:ProjectLogFile } else { $Script:GLOBAL_LOG_FILE }
    
    try {
        if (-not (Test-Path $logFileToUse)) {
            $logDir = Split-Path -Path $logFileToUse -Parent
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null }
            New-Item -Path $logFileToUse -ItemType File -Force -ErrorAction Stop | Out-Null
            $initialTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $initialLogEntry = "[$initialTimestamp] [INFO] Log file created at '$logFileToUse'."
            Add-Content -Path $logFileToUse -Value $initialLogEntry -ErrorAction Stop
        }
    } catch {
        Write-Warning "CRITICAL: Could not create log file at '$logFileToUse'. Error: $($_.Exception.Message)"
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -Path $logFileToUse -Value $logEntry -ErrorAction Stop
    } catch { Write-Warning "Failed to write to log file: '$logFileToUse'" }

    $color = switch ($Level) {
        "INFO"  { "Gray" } "WARN"  { "Yellow" } "ERROR" { "Red" } "DEBUG" { "Cyan" } default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}

function Start-Operation {
    param([string]$OperationName)
    Write-Log -Level INFO -Message "▶️ Starting operation: $OperationName"
    return Get-Date
}

function End-Operation {
    param([Parameter(Mandatory = $true)][datetime]$StartTime, [string]$OperationName = "Operation")
    $duration = New-TimeSpan -Start $StartTime -End (Get-Date)
    Write-Log -Level INFO -Message "✅ $OperationName completed in $($duration.ToString('g'))"
}

function Test-CommandExists {
    param([string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Show-CreditHeader {
    $credit = "Created by $($Script:AuthorName) ($($Script:AuthorLinkedIn))"
    Write-Host "`n$credit" -ForegroundColor DarkGray
}

function Initialize-Toolkit {
    try {
        Write-Host "Checking for remote configuration..." -ForegroundColor DarkGray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $cacheBustingUrl = "$($Script:REMOTE_CONTROL_URL)?t=$((Get-Date).Ticks)"
        Write-Log -Level DEBUG "Fetching remote control file from: $cacheBustingUrl"
        $headers = @{ "Cache-Control" = "no-cache"; "Pragma" = "no-cache" }
        $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
        $response = Invoke-WebRequest -Uri $cacheBustingUrl -UseBasicParsing -Headers $headers -Method Get -UserAgent $userAgent
        $controlConfig = $response.Content | ConvertFrom-Json
        Write-Log -Level DEBUG "Fetched remote config content: $($response.Content)"

        if ($controlConfig.author) {
            $Script:AuthorName = $controlConfig.author.name
            $Script:AuthorLinkedIn = $controlConfig.author.linkedin
        }
        
        Show-Banner -Title $controlConfig.welcomeText
        
        if ($controlConfig.isActive -eq $false) {
            Write-Host "`nTOOL DEACTIVATED BY ADMIN:" -ForegroundColor Red
            Write-Host $controlConfig.message -ForegroundColor Yellow
            Read-Host "`nPress Enter to exit."
            exit
        }

        if ($Script:VERSION -ne $controlConfig.latestVersion) {
            Write-Host "`nUPDATE AVAILABLE: A newer version ($($controlConfig.latestVersion)) of the toolkit is available." -ForegroundColor Green
        }

        if (-not [string]::IsNullOrWhiteSpace($controlConfig.message)) {
            Write-Host "`nREMOTE MESSAGE:" -ForegroundColor Cyan
            Write-Host $controlConfig.message -ForegroundColor Yellow
        }
        Read-Host "`nPress Enter to begin..."

    } catch {
        Write-Log -Level WARN "Could not fetch remote control file. Continuing in offline mode. Error: $($_.Exception.Message)"
        Show-Banner -Title "SFDC DevOps Toolkit (Offline Mode)"
        Read-Host "`nPress Enter to continue in offline mode..."
    }
    
    Write-Log -Level INFO -Message "=================== SFDC DevOps Toolkit v$($Script:VERSION) Initializing ==================="
    if (-not (Test-Path $Script:TOOLKIT_ROOT_CONFIG_DIR)) {
        try {
            New-Item -ItemType Directory -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ErrorAction Stop | Out-Null
            Write-Log -Level INFO "Created toolkit directory at '$($Script:TOOLKIT_ROOT_CONFIG_DIR)'."
        } catch {
            Write-Log -Level ERROR "FATAL: Could not create toolkit directory. Please check permissions. Error: $($_.Exception.Message)"
            Read-Host "Press Enter to exit."; exit
        }
    }
}
#endregion

#region Core: Project and Settings Management
function Select-Project {
    Show-Banner -Title "Project Selection"
    Write-Log -Level DEBUG "Entering function 'Select-Project'."
    
    $projects = New-Object -TypeName PSObject 

    try {
        if (Test-Path $Script:ROOT_PROJECT_LIST_FILE) {
            $content = Get-Content $Script:ROOT_PROJECT_LIST_FILE -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $projects = $content | ConvertFrom-Json 
            }
        }
    } catch {
        Write-Log -Level ERROR "Could not read or parse project list at '$($Script:ROOT_PROJECT_LIST_FILE)'. Error: $($_.Exception.Message)"
    }

    $projectKeys = @($projects.PSObject.Properties.Name | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($projectKeys.Count -eq 0) {
        Write-Log -Level INFO "No valid projects found. Prompting to create a new one."
        return Create-Project
    }

    Write-Host "Please select a project:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $projectKeys.Count; $i++) {
        $key = $projectKeys[$i]
        Write-Host "  [$($i+1)] $key"
        Write-Host "    Path: $($projects.$key)" -ForegroundColor DarkGray
    }
    Write-Host "  [N] Create a New Project"

    $choice = Read-Host "> Enter your choice"
    if ($choice.ToLower() -eq 'n') {
        Write-Log -Level INFO "User chose to create a new project."
        return Create-Project
    }
    elseif ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $projectKeys.Count) {
        $selectedProjectName = $projectKeys[[int]$choice - 1]
        $selectedProjectPath = $projects.$selectedProjectName
        Write-Log -Level INFO "User selected project '$selectedProjectName'."
        return Initialize-Project -ProjectName $selectedProjectName -ProjectPath $selectedProjectPath
    }
    else {
        Write-Log -Level WARN "Invalid project selection '$choice'. Exiting."
        Exit
    }
}

function Create-Project {
    Write-Log -Level DEBUG "Entering function 'Create-Project'."
    $projectName = Read-Host "Enter a name for your new project (e.g., My-Awesome-Project)"
    if ([string]::IsNullOrWhiteSpace($projectName)) { Write-Log -Level WARN "Project name cannot be empty."; return $false }

    $projectBasePath = Read-Host "Enter path to create project folder (default: current directory, i.e., $PSScriptRoot)"
    if ([string]::IsNullOrWhiteSpace($projectBasePath)) { $projectBasePath = $PSScriptRoot }
    
    $projectFullPath = Join-Path -Path $projectBasePath -ChildPath $projectName
    if (Test-Path $projectFullPath) { Write-Log -Level ERROR "A folder named '$projectName' already exists at that location."; return $false }

    try {
        Write-Log -Level INFO "Creating new project folder at '$projectFullPath'."
        New-Item -Path $projectFullPath -ItemType Directory -ErrorAction Stop | Out-Null
        
        $allProjects = if(Test-Path $Script:ROOT_PROJECT_LIST_FILE) { Get-Content $Script:ROOT_PROJECT_LIST_FILE | ConvertFrom-Json } else { New-Object -TypeName PSObject }
        $allProjects | Add-Member -MemberType NoteProperty -Name $projectName -Value $projectFullPath -Force
        $allProjects | ConvertTo-Json | Out-File $Script:ROOT_PROJECT_LIST_FILE -Encoding utf8 -ErrorAction Stop
        Write-Log -Level INFO "Added '$projectName' to the project list."

        return Initialize-Project -ProjectName $projectName -ProjectPath $projectFullPath
    } catch {
        Write-Log -Level ERROR "Failed to create project. Error: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-Project {
    param([string]$ProjectName, [string]$ProjectPath)
    if (-not (Test-Path $ProjectPath)) { Write-Log -Level ERROR "Project path '$ProjectPath' not found!"; return $false }

    $Script:ProjectRoot = $ProjectPath
    try {
        Set-Location -Path $Script:ProjectRoot
    } catch {
        Write-Log -Level ERROR "Cannot access project path '$($Script:ProjectRoot)'. Please check permissions. Error: $($_.Exception.Message)"
        return $false
    }

    $projectConfigDir = Join-Path -Path $Script:ProjectRoot -ChildPath ".sfdc-toolkit"
    $Script:ProjectSettingsFile = Join-Path -Path $projectConfigDir -ChildPath "settings.json"
    $Script:ProjectLogFile = Join-Path -Path $projectConfigDir -ChildPath "session.log"
    
    Write-Log -Level INFO "Project '$ProjectName' selected. Switching to project-specific log."
    Write-Log -Level INFO "For further details, see the log at: '$($Script:ProjectLogFile)'"
    
    Write-Log -Level INFO "=================== Toolkit Session Started for Project '$ProjectName' ==================="
    Load-Settings
    return $true
}

function Load-Settings {
    Write-Log -Level DEBUG "Entering function 'Load-Settings'."
    if (Test-Path -Path $Script:ProjectSettingsFile) {
        try {
            $Script:Settings = Get-Content $Script:ProjectSettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json
            Write-Log -Level INFO "Project settings loaded from '$($Script:ProjectSettingsFile)'."
        } catch {
            Write-Log -Level ERROR "Project settings file is corrupt. Using defaults. Error: $($_.Exception.Message)"
            $Script:Settings = [pscustomobject]@{ ApiVersion = "61.0"; logLevel = "INFO" }
        }
    } else {
        Write-Log -Level WARN "No settings file found. Creating new default settings."
        $Script:Settings = [pscustomobject]@{ SourceOrgAlias = $null; DestinationOrgAlias = $null; ApiVersion = "61.0"; logLevel = "INFO" }
    }
    
    if (-not $Script:Settings.PSObject.Properties['ApiVersion']) {
        $Script:Settings | Add-Member -MemberType NoteProperty -Name 'ApiVersion' -Value "61.0"
    }
    if (-not $Script:Settings.PSObject.Properties['logLevel']) {
        $Script:Settings | Add-Member -MemberType NoteProperty -Name 'logLevel' -Value "INFO"
    }
    Save-Settings
}

function Save-Settings {
    if (-not $Script:ProjectRoot) { return }
    try {
        $Script:Settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $Script:ProjectSettingsFile -Encoding utf8 -ErrorAction Stop
    } catch { Write-Log -Level ERROR "Failed to save settings: $($_.Exception.Message)" }
}
#endregion

#region UI and Menus
function Show-Banner {
    param([string]$Title)
    Clear-Host
    
    $textColor = "Cyan"
    $header = @"
    _____ ____  ____  ____    _______          _ _  _ _  _
 / ____/ __ \| _ \ / ____|  |__   __|          | | | (_) | | |
| (___| |  | | |_) | |        ___  | | ___  ___ | | | _| |_| |_
 \___ \ |  | |  _ <| |       / _ \  | |/ _ \ / _ \| | | | | __| __|
 ____) | |__| | |_) | |____| (_) | | | (_) | (_) | | | | | |_| |_
|_____/ \____/|____/ \____/ \___/  |_|\___/ \___/|_|_|_|_|\__|\__|
"@
    Write-Host $header -ForegroundColor $textColor
    Show-CreditHeader

    $projectName = if ($Script:ProjectRoot) { Split-Path -Path $Script:ProjectRoot -Leaf } else { "No Project Selected" }
    Write-Host ("-" * 75) -ForegroundColor "Blue"
    Write-Host ("  $Title | v$($Script:VERSION) | Project: " + $projectName) -ForegroundColor $textColor
    Write-Host ("-" * 75) -ForegroundColor "Blue"
    Write-Host ""
}

function Show-SystemInfo {
    function Get-OrgDisplayInfo {
        param([string]$alias)
        if (-not $alias) { return [pscustomobject]@{ Display = "Not Set"; Color = "Yellow"; Api = "N/A" } }
        if ($Script:Settings.Orgs) {
            $org = $Script:Settings.Orgs | Where-Object { $_.alias -eq $alias }
            if ($org) {
                # Ensure these properties exist or default gracefully
                $apiVersion = if ($org.PSObject.Properties['instanceApiVersion']) { $org.instanceApiVersion } else { "Unknown" }
                return [pscustomobject]@{ Display = "$($org.alias) ($($org.username))"; Color = "Green"; Api = $apiVersion }
            }
        }
        return [pscustomobject]@{ Display = "$alias (details not cached)"; Color = "Yellow"; Api = "Unknown" }
    }

    $sourceInfo = Get-OrgDisplayInfo -alias $Script:Settings.SourceOrgAlias
    $destInfo = Get-OrgDisplayInfo -alias $Script:Settings.DestinationOrgAlias
    
    Write-Host "  Project Context" -ForegroundColor White
    Write-Host "  -------------------------"
    Write-Host ("    Source Org:        ") -NoNewline; Write-Host "$($sourceInfo.Display) | API: $($sourceInfo.Api)" -ForegroundColor $sourceInfo.Color
    Write-Host ("    Destination Org: ") -NoNewline; Write-Host "$($destInfo.Display) | API: $($destInfo.Api)" -ForegroundColor $destInfo.Color
    Write-Host ("    Project Default API: ") -NoNewline; Write-Host $Script:Settings.ApiVersion -ForegroundColor "Gray"
    Write-Host ("    Current Log Level:    ") -NoNewline; Write-Host $Script:Settings.logLevel -ForegroundColor "Gray"
    Write-Host ("-" * 75) -ForegroundColor "Blue"
}

function Show-MainMenu {
    Show-Banner -Title "Main Menu"
    Show-SystemInfo
    Write-Log -Level DEBUG "Displaying Main Menu."
    
    Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "  ║          SFDC DevOps Toolkit v$($Script:VERSION)  ║" -ForegroundColor Cyan
    Write-Host "  ╠═══════════════════════════════════════════════════╣" -ForegroundColor Blue
    Write-Host "  ║                                                   ║" -ForegroundColor Blue
    Write-Host "  ║  [1] Compare and Deploy                           ║" -ForegroundColor Yellow
    Write-Host "  ║  [2] Project and Org Setup                        ║" -ForegroundColor White
    Write-Host "  ║  [3] System and Utilities                         ║" -ForegroundColor White
    Write-Host "  ║                                                   ║" -ForegroundColor Blue
    Write-Host "  ║  [Q] Quit                                         ║" -ForegroundColor Red
    Write-Host "  ║                                                   ║" -ForegroundColor Blue
    Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}
#endregion

#region Salesforce Operations

function Check-Prerequisites {
    param([switch]$ForceRefresh)
    $startTime = Start-Operation -OperationName "System Readiness Check"
    $allGood = $true
    try {
        if (-not $ForceRefresh -and $Script:Settings.SystemInfo -and ( (New-TimeSpan -Start ([datetime]$Script:Settings.SystemInfo.LastCheck) -End (Get-Date)).TotalHours -lt 24) ) {
            Write-Log -Level INFO "System check results from cache."
            foreach($item in $Script:Settings.SystemInfo.Software) {
                Write-Host ("  [*] $($item.Name)... ") -NoNewline
                if($item.Installed) { Write-Host "[INSTALLED]" -ForegroundColor Green }
                else { Write-Host "[MISSING]" -ForegroundColor Red }
            }
            End-Operation -StartTime $startTime
            return $true
        }
        $tools = @(
            @{ Name = "Salesforce CLI"; Command = "sf"; Required = $true },
            @{ Name = "Git"; Command = "git"; Required = $false },
            @{ Name = "Visual Studio Code"; Command = "code"; Required = $false }
        )
        Write-Log -Level INFO "Performing live check for required tools..."
        $liveSoftwareStatus = @()
        foreach ($tool in $tools) {
            $swObject = [pscustomobject]@{ Name = $tool.Name; Installed = $false; Required = $tool.Required }
            Write-Host "  [*] Checking for $($tool.Name)..." -NoNewline
            if (Test-CommandExists -CommandName $tool.Command) {
                Write-Host " [INSTALLED]" -ForegroundColor Green; $swObject.Installed = $true
            } else {
                Write-Host " [MISSING]" -ForegroundColor Yellow
                if ($tool.Required) { $allGood = $false }
            }
            $liveSoftwareStatus += $swObject
        }
        if (-not $Script:Settings.PSObject.Properties['SystemInfo']) { $Script:Settings | Add-Member -MemberType NoteProperty -Name 'SystemInfo' -Value ([pscustomobject]@{}) }
        $Script:Settings.SystemInfo.Software = $liveSoftwareStatus # Assign the software status directly
        $Script:Settings.SystemInfo.LastCheck = (Get-Date -Format "o") # Update LastCheck here
        Save-Settings
    } catch {
        Write-Log -Level ERROR "An error occurred during prerequisite check: $($_.Exception.Message)"
    }
    End-Operation -StartTime $startTime
    if (-not $allGood) { Write-Log -Level ERROR "One or more required tools are missing."; Read-Host "Press Enter to exit..."; exit }
    return $true
}

function Authorize-Org {
    Write-Log -Level DEBUG "Entering function 'Authorize-Org'."
    $alias = Read-Host "`nEnter an alias for the new org"
    if ([string]::IsNullOrWhiteSpace($alias)) { Write-Log -Level WARN "Auth cancelled by user."; return }
    $isProd = Read-Host "`nIs this a Production/Developer Edition org? (y/n)"
    $instanceUrl = if ($isProd.ToLower() -eq 'n') { "https://test.salesforce.com" } else { "https://login.salesforce.com" }
    try {
        Write-Log -Level INFO "Attempting web login for alias '$alias' with instance URL '$instanceUrl'."
        sf org login web --alias $alias --instance-url $instanceUrl --set-default
        if($LASTEXITCODE -ne 0) { throw "Salesforce CLI reported an error during login." }
        Write-Log -Level INFO "Successfully authorized org '$alias'."
        Clear-ProjectCache -property "Orgs"
    } catch {
        Write-Log -Level ERROR "Failed to authorize org. Error: $($_.Exception.Message | Out-String)"
    }
    Read-Host "`nPress Enter..."
}

function Select-Org {
    Write-Log -Level DEBUG "Entering function 'Select-Org'."
    while ($true) {
        if (-not $Script:Settings.Orgs) {
            Write-Log -Level INFO "No cached orgs, fetching live list from Salesforce CLI..."
            try {
                $orgsJson = sf org list --json | ConvertFrom-Json
                if ($LASTEXITCODE -ne 0) { throw "Salesforce CLI failed to list orgs."}
                if (-not $Script:Settings.PSObject.Properties['Orgs']) { $Script:Settings | Add-Member -MemberType NoteProperty -Name 'Orgs' -Value $null }
                $Script:Settings.Orgs = @($orgsJson.result.nonScratchOrgs) + @($orgsJson.result.scratchOrgs)
                Save-Settings
                Write-Log -Level INFO "Fetched and cached $($Script:Settings.Orgs.Count) orgs."
            } catch { Write-Log -Level ERROR "Failed to list orgs: $($_.Exception.Message | Out-String)"; Read-Host; return }
        }
        $orgs = $Script:Settings.Orgs
        if ($orgs.Count -eq 0) {
            Write-Log -Level WARN "No Salesforce orgs have been authorized with the CLI."
            if ((Read-Host "Refresh list now? (y/n)").ToLower() -eq 'y') { Clear-ProjectCache -property 'Orgs'; continue }
            Read-Host; return
        }
        Write-Host "`nAvailable Orgs:" -ForegroundColor Green
        for ($i=0; $i -lt $orgs.Count; $i++) { Write-Host "  [$($i+1)] Alias: $($orgs[$i].alias) | User: $($orgs[$i].username)" }
        Write-Host "  [R] Refresh Org List"
        Write-Host "  [Q] Back to calling menu"
        $choice = Read-Host "`nSelect an org to set as SOURCE"
        Write-Log -Level DEBUG "User selection for SOURCE: '$choice'"
        if ($choice.ToLower() -eq 'q') { break }
        if ($choice.ToLower() -eq 'r') { Clear-ProjectCache -property 'Orgs'; continue }
        if ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $orgs.Count) {
            $Script:Settings.SourceOrgAlias = $orgs[[int]$choice - 1].alias
            Write-Log -Level INFO "Set Source Org to '$($Script:Settings.SourceOrgAlias)'."
            $destChoice = Read-Host "Select an org to set as DESTINATION (or press Enter to skip)"
            Write-Log -Level DEBUG "User selection for DESTINATION: '$destChoice'"
            if ($destChoice -match '^\d+$' -and $destChoice -gt 0 -and $destChoice -le $orgs.Count) {
                $Script:Settings.DestinationOrgAlias = $orgs[[int]$destChoice - 1].alias
                Write-Log -Level INFO "Set Destination Org to '$($Script:Settings.DestinationOrgAlias)'."
            } else {
                $Script:Settings.DestinationOrgAlias = $null
                Write-Log -Level INFO "Destination Org was not set."
            }
            Save-Settings; break
        } else { Write-Log -Level WARN "Invalid selection." }
    }
}

function Display-OrgInfo {
    if (-not $Script:Settings.SourceOrgAlias) { Write-Log -Level ERROR "No Source Org selected."; Read-Host; return }
    Write-Log -Level INFO "Displaying information for org '$($Script:Settings.SourceOrgAlias)'."
    try {
        sf org display --target-org $Script:Settings.SourceOrgAlias | Out-Host
    } catch { Write-Log -Level ERROR "Failed to display org info. Error: $($_.Exception.Message | Out-String)" }
    Read-Host "`nPress Enter..."
}

function Open-Org {
    if (-not $Script:Settings.SourceOrgAlias) { Write-Log -Level ERROR "No Source Org selected."; Read-Host; return }
    Write-Log -Level INFO "Opening org '$($Script:Settings.SourceOrgAlias)' in browser."
    try {
        sf org open --target-org $Script:Settings.SourceOrgAlias
    } catch { Write-Log -Level ERROR "Failed to open org. Error: $($_.Exception.Message | Out-String)" }
}

function Ensure-Orgs-Selected {
    if (-not ($Script:Settings.SourceOrgAlias -and $Script:Settings.DestinationOrgAlias)) {
        Write-Log -Level WARN "Source and/or Destination org is not set for this operation."
        Write-Host "You must select both orgs to proceed." -ForegroundColor Yellow
        Select-Org
        if (-not ($Script:Settings.SourceOrgAlias -and $Script:Settings.DestinationOrgAlias)) {
            Write-Log -Level WARN "Org selection was cancelled. Returning to main menu."
            return $false
        }
    }
    return $true
}
#endregion

#region Delta Generation Functions

function Handle-CompareAndDeploy-SubMenu {
    while($true) {
        Show-Banner -Title "Compare and Deploy"
        Write-Host "  [1] Compare Orgs and Generate Delta Package" -ForegroundColor "Yellow"
        Write-Host "  [2] Quick Visual Compare in VS Code"
        Write-Host "  [3] Deploy Metadata"
        Write-Host ""
        Write-Host "  [B] Back to Main Menu"
        $choice = Read-Host "> Enter your choice"
        Write-Log -Level INFO "User selected Compare and Deploy option '$choice'."
        switch ($choice) {
            '1' { Handle-Comparison-SubMenu }
            '2' { Run-Quick-Visual-Compare; Read-Host "`nPress Enter to return..." }
            '3' { Deploy-Metadata-Advanced }
            'b' { return }
            default { Write-Log -Level WARN "Invalid option." }
        }
    }
}

function Handle-Comparison-SubMenu {
    if (-not (Ensure-Orgs-Selected)) { return }
    
    Write-Log -Level DEBUG "Entering 'Compare Orgs and Generate Delta' menu."
    
    $continue = Check-And-Prompt-For-Retrieval
    if (-not $continue) {
        Write-Log -Level INFO "Comparison cancelled by user."
        return
    }

    while ($true) {
        Show-Banner -Title "Comparison Actions"
        Write-Host "Metadata is ready. What would you like to do?" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Generate Delta Package"
        Write-Host "  [2] View Visual Diff in VS Code"
        Write-Host ""
        Write-Host "  [Q] Return to Compare and Deploy Menu"
        $choice = Read-Host "> Enter your choice"
        Write-Log -Level INFO "User selected comparison action '$choice'."
        switch ($choice) {
            '1' { Generate-Delta-From-Local }
            '2' { Run-Quick-Visual-Compare -NoRetrieval }
            'q' { return }
            default { Write-Log -Level WARN "Invalid option." }
        }
        if ($choice -ne 'q') { Read-Host "`nPress Enter to return..." }
    }
}
function Check-And-Prompt-For-Retrieval {
    $sourceDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_source_metadata"
    $destDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_target_metadata"
    $performFreshRetrieval = $true

    if ((Test-Path $sourceDir) -and (Test-Path $destDir)) {
        Write-Log -Level INFO "Previously retrieved metadata found."
        Write-Host "`nPreviously retrieved metadata found." -ForegroundColor Yellow
        Write-Host "[1] Use Existing Local Data (Fast)" -ForegroundColor Cyan
        Write-Host "[2] Perform Fresh Retrieval (Slow, Recommended for accuracy)" -ForegroundColor Cyan
        $choice = Read-Host "> Enter your choice"
        if ($choice -eq '1') {
            $performFreshRetrieval = $false
        }
    }
    
    if ($performFreshRetrieval) {
        Write-Log -Level INFO "Proceeding with fresh retrieval."
        return Retrieve-For-Full-Comparison
    } else {
        Write-Log -Level INFO "User chose to use existing local data."
        return $true
    }
}

function Retrieve-For-Full-Comparison {
    $startTime = Start-Operation "Full Metadata Retrieval for Comparison"
    $success = $false
    try {
        Write-Host "`nWARNING: This process retrieves ALL metadata from both orgs based on a full manifest." -ForegroundColor Yellow
        Write-Host "This can take a very long time (10-60+ minutes) depending on the size of your orgs." -ForegroundColor Yellow
        Read-Host "Press ENTER to continue, or CTRL+C to cancel"

        $sourceManifestPath = Join-Path $Script:ProjectRoot "_source_manifest.xml"
        $targetManifestPath = Join-Path $Script:ProjectRoot "_target_manifest.xml"
        $sourceDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_source_metadata"
        $destDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_target_metadata"

        # --- Source Org Retrieval ---
        Write-Log -Level INFO "Generating manifest from Source Org: '$($Script:Settings.SourceOrgAlias)'..."
        Invoke-InTempProject -ScriptBlock {
            param($org, $path, $apiVersion)
            sf project generate manifest --from-org $org --output-dir (Split-Path $path -Parent) --name ([System.IO.Path]::GetFileNameWithoutExtension($path)) --api-version $apiVersion
            if ($LASTEXITCODE -ne 0) { throw "Failed to generate manifest from $org" }
        } -ArgumentList @($Script:Settings.SourceOrgAlias, $sourceManifestPath, $Script:Settings.ApiVersion)
        
        Write-Log -Level INFO "Retrieving from SOURCE org into '$sourceDir'..."
        sf project retrieve start --manifest $sourceManifestPath --target-org $Script:Settings.SourceOrgAlias --output-dir $sourceDir --api-version $Script:Settings.ApiVersion | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Source retrieval failed." }
        Write-Host "✅ Source retrieval complete." -ForegroundColor Green

        # --- Target Org Retrieval ---
        Write-Log -Level INFO "Generating manifest from Target Org: '$($Script:Settings.DestinationOrgAlias)'..."
        Invoke-InTempProject -ScriptBlock {
            param($org, $path, $apiVersion)
            sf project generate manifest --from-org $org --output-dir (Split-Path $path -Parent) --name ([System.IO.Path]::GetFileNameWithoutExtension($path)) --api-version $apiVersion
            if ($LASTEXITCODE -ne 0) { throw "Failed to generate manifest from $org" }
        } -ArgumentList @($Script:Settings.DestinationOrgAlias, $targetManifestPath, $Script:Settings.ApiVersion)

        Write-Log -Level INFO "Retrieving from DESTINATION org into '$destDir'..."
        sf project retrieve start --manifest $targetManifestPath --target-org $Script:Settings.DestinationOrgAlias --output-dir $destDir --api-version $Script:Settings.ApiVersion | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Destination retrieval failed." }
        Write-Host "✅ Destination retrieval complete." -ForegroundColor Green
        $success = $true
    } catch {
        Write-Log -Level ERROR "An error occurred during retrieval: $($_.Exception.Message | Out-String)"
        $success = $false
    } finally {
        if (Test-Path $sourceManifestPath) { Remove-Item $sourceManifestPath -Force }
        if (Test-Path $targetManifestPath) { Remove-Item $targetManifestPath -Force }
    }
    End-Operation -StartTime $startTime
    return $success
}

function Generate-Delta-From-Local {
    $startTime = Start-Operation "Delta Package Generation from Local Files"
    try {
        $sourcePath = Join-Path -Path $Script:ProjectRoot -ChildPath "_source_metadata"
        $targetPath = Join-Path -Path $Script:ProjectRoot -ChildPath "_target_metadata"
        $deltaPackageDir = Join-Path -Path $Script:ProjectRoot -ChildPath "delta-deployment"

        if (-not (Test-Path $sourcePath) -or -not (Test-Path $targetPath)) {
            throw "Could not find retrieved metadata folders (_source_metadata and _target_metadata). Please run retrieval first."
        }
        if(Test-Path $deltaPackageDir) {
            Write-Log -Level INFO "Clearing previous delta-deployment directory."
            Remove-Item -Path $deltaPackageDir -Recurse -Force
        }
        New-Item -Path $deltaPackageDir -ItemType Directory -ErrorAction Stop | Out-Null
        
        Create-Delta-Package -SourcePath $sourcePath -TargetPath $targetPath -DeltaPackageDir $deltaPackageDir -ApiVersion $Script:Settings.ApiVersion
    } catch {
        Write-Log -Level ERROR "Failed to generate delta from local files: $($_.Exception.Message | Out-String)"
    }
    End-Operation -StartTime $startTime
}

function Create-Delta-Package {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$DeltaPackageDir,
        [string]$ApiVersion
    )
    Write-Log -Level INFO "Comparing source and target folders to generate delta package..."

    $additiveTypes = @{}
    $destructiveTypes = @{}
    $unrecognizedFolders = New-Object System.Collections.Generic.HashSet[string]

    function Normalize-Relative-Path {
        param([string]$FullPath, [string]$BasePath)
        $relativePath = $FullPath.Substring($BasePath.Length).TrimStart('\/')
        if ($relativePath.StartsWith("unpackaged" + [System.IO.Path]::DirectorySeparatorChar)) {
            return $relativePath.Substring("unpackaged".Length + 1)
        }
        return $relativePath
    }

    Write-Log -Level INFO "--- Pass 1: Analyzing source for new/modified files... ---"
    Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
        $sourceFile = $_
        $relativeSourcePath = Normalize-Relative-Path -FullPath $sourceFile.FullName -BasePath $SourcePath
        $targetFile = Join-Path -Path $TargetPath -ChildPath $relativeSourcePath
        if (-not (Test-Path $targetFile)) {
            $targetFileUnpackaged = Join-Path -Path (Join-Path -Path $TargetPath -ChildPath "unpackaged") -ChildPath $relativeSourcePath
            if (Test-Path $targetFileUnpackaged) { $targetFile = $targetFileUnpackaged }
        }

        $isNew = -not (Test-Path $targetFile)
        $isModified = $false
        if (-not $isNew) {
            $sourceHash = (Get-FileHash $sourceFile.FullName -Algorithm SHA256).Hash
            $targetHash = (Get-FileHash $targetFile -Algorithm SHA256).Hash
            if ($sourceHash -ne $targetHash) { $isModified = $true }
        }

        if ($isNew -or $isModified) {
            $componentAdded = Add-Component-To-Types -TypesHashtable $additiveTypes -FullPath $sourceFile.FullName -BasePath $SourcePath -UnrecognizedFolders $unrecognizedFolders
            if($componentAdded) {
                $destinationFileInPackage = Join-Path -Path $DeltaPackageDir -ChildPath $sourceFile.FullName.Substring($SourcePath.Length)
                $destinationDirInPackage = Split-Path -Path $destinationFileInPackage -Parent
                if (-not (Test-Path $destinationDirInPackage)) { New-Item -Path $destinationDirInPackage -ItemType Directory | Out-Null }
                Copy-Item -Path $sourceFile.FullName -Destination $destinationFileInPackage -Force
            }
        }
    }

    Write-Log -Level INFO "--- Pass 2: Analyzing target for deleted files... ---"
    Get-ChildItem -Path $TargetPath -Recurse -File | ForEach-Object {
        $targetFile = $_
        $relativeTargetPath = Normalize-Relative-Path -FullPath $targetFile.FullName -BasePath $TargetPath
        $sourceFile = Join-Path -Path $SourcePath -ChildPath $relativeTargetPath
        if (-not (Test-Path $sourceFile)) {
             $sourceFileUnpackaged = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath "unpackaged") -ChildPath $relativeTargetPath
             if (Test-Path $sourceFileUnpackaged) { $sourceFile = $sourceFileUnpackaged }
        }
        
        if (-not (Test-Path $sourceFile)) {
            Add-Component-To-Types -TypesHashtable $destructiveTypes -FullPath $targetFile.FullName -BasePath $TargetPath -UnrecognizedFolders $unrecognizedFolders | Out-Null
        }
    }

    Write-Log -Level INFO "--- Pass 3: Generating output files... ---"
    $foundChanges = $false
    if ($additiveTypes.Keys.Count -gt 0) {
        $foundChanges = $true
        $outputPath = Join-Path -Path $DeltaPackageDir -ChildPath "package.xml"
        Generate-Package-Xml -TypesHashtable $additiveTypes -OutputPath $outputPath -ApiVersion $ApiVersion
        Write-Log -Level INFO "Additive changes found. Created 'package.xml' in '$DeltaPackageDir'"
    } else {
        Generate-Package-Xml -TypesHashtable @{} -OutputPath (Join-Path -Path $DeltaPackageDir -ChildPath "package.xml") -ApiVersion $ApiVersion
    }

    if ($destructiveTypes.Keys.Count -gt 0) {
        $foundChanges = $true
        $destructiveXmlPath = Join-Path -Path $DeltaPackageDir -ChildPath "destructiveChanges.xml"
        Generate-Package-Xml -TypesHashtable $destructiveTypes -OutputPath $destructiveXmlPath -ApiVersion $ApiVersion
        Write-Log -Level INFO "Destructive changes found. Created 'destructiveChanges.xml' in '$DeltaPackageDir'"
    }

    if ($unrecognizedFolders.Count -gt 0) {
        Write-Log -Level WARN "The following unrecognized metadata folders were found during comparison:"
        $unrecognizedFolders | ForEach-Object { Write-Log -Level WARN "  - $_" }
        Write-Log -Level WARN "Their contents were NOT included in the package. To add support, run 'Update Metadata Mappings'."
    }

    if (-not $foundChanges) {
        Write-Log -Level INFO "No differences found between source and target orgs."
    } else {
        Write-Host "`n✅ Delta package created successfully at: $DeltaPackageDir" -ForegroundColor Green
    }
}

function Add-Component-To-Types {
    param(
        [hashtable]$TypesHashtable,
        [string]$FullPath,
        [string]$BasePath,
        [System.Collections.Generic.HashSet[string]]$UnrecognizedFolders
    )
    try {
        $RelativePath = $FullPath.Substring($BasePath.Length).TrimStart('\/')
        $pathParts = $RelativePath.Split([System.IO.Path]::DirectorySeparatorChar) | Where-Object { $_.Length -gt 0 }
        
        # Handle unpackaged/ folder if present
        if ($pathParts.Count -gt 1 -and $pathParts[0] -eq 'unpackaged') {
            $pathParts = $pathParts[1..($pathParts.Count - 1)]
        }
        
        # Handle standard sfdx force-app/main/default structure
        if ($pathParts.Count -gt 3 -and $pathParts[0] -eq 'force-app' -and $pathParts[1] -eq 'main' -and $pathParts[2] -eq 'default') {
            $pathParts = $pathParts[3..($pathParts.Count - 1)]
        }

        if ($pathParts.Count -lt 2) { return $false } # Not enough parts to determine type and member

        $metadataTypeFolder = $pathParts[0]
        if (-not $Script:MetadataMap.ContainsKey($metadataTypeFolder)) {
            # Handle nested metadata like fields, layouts, etc. inside an 'objects' folder
            if ($metadataTypeFolder -eq 'objects' -and $pathParts.Count -ge 4) {
                $metadataTypeFolder = $pathParts[2] # e.g., 'fields', 'layouts'
                if (-not $Script:MetadataMap.ContainsKey($metadataTypeFolder)) {
                    $UnrecognizedFolders.Add($pathParts[0] + '/' + $pathParts[2]) | Out-Null
                    return $false
                }
            } else {
                   $UnrecognizedFolders.Add($metadataTypeFolder) | Out-Null
                   return $false
            }
        }
        
        $metadataTypeName = $Script:MetadataMap[$metadataTypeFolder]
        $memberName = ''

        # Bundled Components (LWC, Aura, ExperienceBundle, StaticResource)
        if ($metadataTypeName -in @("LightningComponentBundle", "AuraDefinitionBundle", "ExperienceBundle", "StaticResource", "ContentAsset")) {
            $memberName = $pathParts[1]
        }
        # Nested Components (Fields, Layouts, etc.)
        elseif ($pathParts[0] -eq 'objects' -and $pathParts.Count -ge 4) {
            $objectName = $pathParts[1]
            $componentFile = $pathParts[3]
            $componentNamePart = [System.IO.Path]::GetFileNameWithoutExtension($componentFile).Split('.')[0]
            $memberName = "$objectName.$componentNamePart"
        }
        # Standard, non-nested, non-bundled components
        else {
            $componentFile = $pathParts[-1]
            $memberName = [System.IO.Path]::GetFileNameWithoutExtension($componentFile).Split('.')[0]
        }

        if (-not [string]::IsNullOrWhiteSpace($memberName)) {
            if (-not $TypesHashtable.ContainsKey($metadataTypeName)) {
                $TypesHashtable[$metadataTypeName] = New-Object System.Collections.Generic.HashSet[string]
            }
            $TypesHashtable[$metadataTypeName].Add($memberName) | Out-Null
            return $true
        }
    } catch {
        Write-Log -Level WARN "Could not parse component path '$FullPath'. Error: $($_.Exception.Message)"
    }
    return $false
}


function Generate-Package-Xml {
    param(
        [hashtable]$TypesHashtable,
        [string]$OutputPath,
        [string]$ApiVersion
    )
    $manifest = [xml]"<?xml version=`"1.0`" encoding=`"UTF-8`"?><Package xmlns=`"http://soap.sforce.com/2006/04/metadata`"></Package>"
    $packageNode = $manifest.Package

    foreach ($typeName in ($TypesHashtable.Keys | Sort-Object)) {
        $typeNode = $manifest.CreateElement("types", $packageNode.NamespaceURI)
        foreach ($member in ($TypesHashtable[$typeName] | Sort-Object)) {
            $memberNode = $manifest.CreateElement("members", $packageNode.NamespaceURI)
            $memberNode.InnerText = $member
            $typeNode.AppendChild($memberNode) | Out-Null
        }
        $nameNode = $manifest.CreateElement("name", $packageNode.NamespaceURI)
        $nameNode.InnerText = $typeName
        $typeNode.AppendChild($nameNode) | Out-Null
        $packageNode.AppendChild($typeNode) | Out-Null
    }

    $versionNode = $manifest.CreateElement("version", $packageNode.NamespaceURI)
    $versionNode.InnerText = $ApiVersion
    $packageNode.AppendChild($versionNode) | Out-Null

    $manifest.Save($OutputPath)
}

function Run-Quick-Visual-Compare {
    param([switch]$NoRetrieval)
    if (-not (Ensure-Orgs-Selected)) { return }
    if (-not (Test-CommandExists 'code')) {
        Write-Log -Level ERROR "Visual Studio Code ('code' command) not found in your PATH."
        Read-Host; return
    }

    $retrievalSuccess = $true
    if (-not $NoRetrieval) {
        $retrievalSuccess = Check-And-Prompt-For-Retrieval
    }
    
    if ($retrievalSuccess) {
        Write-Log -Level INFO "Launching VS Code to compare retrieved metadata..."
        $sourceDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_source_metadata"
        $destDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_target_metadata"
        if ((Test-Path $sourceDir) -and (Test-Path $destDir)) {
            code --diff $sourceDir $destDir
        } else {
            Write-Log -Level ERROR "Could not find local metadata folders to compare."
        }
    } else {
        Write-Log -Level ERROR "Could not run visual compare because metadata retrieval failed or was cancelled."
    }
}
#endregion

#region Advanced Functions

function Handle-ProjectSetup-SubMenu {
    while($true) {
        Show-Banner -Title "Project and Org Setup"
        Write-Host "  [1] List and Select Source/Destination Orgs"
        Write-Host "  [2] Edit Project Settings (API, Log Level)"
        Write-Host "  [3] Authorize a New Org"
        Write-Host "  [4] Switch to a Different Project"
        Write-Host ""
        Write-Host "  [B] Back to Main Menu"
        $choice = Read-Host "> Enter your choice"
        Write-Log -Level INFO "User selected Project Setup option '$choice'."
        switch ($choice) {
            '1' { Select-Org }
            '2' { Edit-ProjectSettings }
            '3' { Authorize-Org }
            '4' { return "switch" } # Special return value to signal a project switch
            'b' { return }
            default { Write-Log -Level WARN "Invalid option." }
        }
    }
}

function Handle-Utilities-SubMenu {
    while($true) {
        Show-Banner -Title "System and Utilities"
        Write-Host "  [1] Update Metadata Mappings from Org"
        Write-Host "  [2] Generate Deployment Manifest (package.xml)"
        Write-Host "  [3] Open Org in Browser"
        Write-Host "  [4] Analyze Local Profile/Permission Set Files"
        Write-Host "  [5] View Project Log File"
        Write-Host "  [6] Clear Project Cache"
        Write-Host "  [7] Re-run System Readiness Check"
        Write-Host ""
        Write-Host "  [B] Back to Main Menu"
        $choice = Read-Host "> Enter your choice"
        Write-Log -Level INFO "User selected Utilities option '$choice'."
        switch ($choice) {
            '1' { Update-Metadata-Mappings }
            '2' { Handle-Manifest-Generation }
            '3' { Open-Org }
            '4' { Analyze-Permissions-Local }
            '5' { View-LogFile }
            '6' { Clear-ProjectCache }
            '7' { Check-Prerequisites -ForceRefresh }
            'b' { return }
            default { Write-Log -Level WARN "Invalid option." }
        }
        Read-Host "`nPress Enter to return to the Utilities menu..."
    }
}

function Invoke-InTempProject {
    param([Parameter(Mandatory=$true)][scriptblock]$ScriptBlock, [Parameter(Mandatory=$false)][array]$ArgumentList)
    $tempProjectDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "sfdx-temp-project-$([System.Guid]::NewGuid().ToString())"
    $originalLocation = Get-Location
    try {
        New-Item -ItemType Directory -Path $tempProjectDir -Force -ErrorAction Stop | Out-Null
        @{ packageDirectories = @(@{path = "force-app"; default = $true}); namespace = ""; sfdcLoginUrl = "https://login.salesforce.com"; sourceApiVersion = $Script:Settings.ApiVersion } | ConvertTo-Json | Set-Content -Path (Join-Path $tempProjectDir "sfdx-project.json") -ErrorAction Stop
        Set-Location -Path $tempProjectDir
        Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    }
    catch {
        throw
    }
    finally {
        Set-Location -Path $originalLocation
        if (Test-Path -Path $tempProjectDir) { Remove-Item -Path $tempProjectDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Handle-Manifest-Generation {
    Write-Log -Level DEBUG "Entering function 'Handle-Manifest-Generation'"
    if (-not $Script:Settings.SourceOrgAlias) { Write-Log -Level ERROR "No Source Org selected."; Read-Host; return }
    Write-Host "`nThis utility creates a 'package.xml' in your project root for targeted deployments." -ForegroundColor Gray
    Write-Host "[1] Generate FULL Manifest from Org" -ForegroundColor Cyan
    Write-Host "[2] Interactively Build a CUSTOM Manifest" -ForegroundColor Cyan
    $choice = Read-Host "Enter your choice"
    Write-Log -Level INFO "User selected manifest generation option '$choice'."
    switch ($choice) {
        '1' { Generate-Full-Manifest }
        '2' { Generate-Custom-Manifest-Interactive }
        default { Write-Log -Level WARN "Invalid choice." }
    }
    Read-Host "`nPress Enter..."
}

function Generate-Full-Manifest {
    $startTime = Start-Operation "Generate Full Deployment Manifest"
    try {
        $orgAlias = $Script:Settings.SourceOrgAlias
        $manifestPath = Join-Path -Path $Script:ProjectRoot -ChildPath "package.xml"
        if ([string]::IsNullOrWhiteSpace($Script:Settings.ApiVersion)) {
            throw "API Version not found in project settings. Please set it via option [6]."
        }
        Invoke-InTempProject -ScriptBlock {
            param($org, $path, $apiVersion)
            Write-Log -Level INFO "Generating deployment manifest from '$org' with API v$apiVersion."
            sf project generate manifest --from-org $org --output-dir (Split-Path $path -Parent) --name ([System.IO.Path]::GetFileNameWithoutExtension($path)) --api-version $apiVersion
            if ($LASTEXITCODE -ne 0) { throw "Salesforce CLI failed to generate the manifest." }
            Write-Host "`n✅ Full manifest generated successfully." -ForegroundColor Green
            Write-Log -Level INFO "Deployment manifest successfully created at: $path"
        } -ArgumentList @($orgAlias, $manifestPath, $Script:Settings.ApiVersion)
    } catch {
        Write-Log -Level ERROR "Failed to generate full manifest: $($_.Exception.Message | Out-String)"
    }
    End-Operation -startTime $startTime
}

function Generate-Custom-Manifest-Interactive {
    Write-Log -Level DEBUG "Entering function 'Generate-Custom-Manifest-Interactive'."
    $orgAlias = $Script:Settings.SourceOrgAlias
    $metadataResult = $null
    try {
        if ($Script:Settings.MetadataTypes -and $Script:Settings.MetadataTypes.$orgAlias) {
            $metadataResult = $Script:Settings.MetadataTypes.$orgAlias
        } else {
            Write-Log -Level INFO "Fetching metadata types from '$orgAlias' for custom manifest builder."
            $metadataJson = sf org list metadata-types --target-org $orgAlias --json | ConvertFrom-Json
            if ($metadataJson.status -ne 0) { throw $metadataJson.message }
            $metadataResult = $metadataJson.result
            if (-not $Script:Settings.PSObject.Properties['MetadataTypes']) { $Script:Settings | Add-Member -MemberType NoteProperty -Name 'MetadataTypes' -Value (New-Object -TypeName psobject) }
            $Script:Settings.MetadataTypes | Add-Member -MemberType NoteProperty -Name $orgAlias -Value $metadataResult -Force; Save-Settings
        }
        
        for($i=0; $i -lt $metadataResult.Length; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $metadataResult[$i].xmlName) }
        $choices = Read-Host "`nEnter numbers to include (e.g., 1,5,12), or 'all'"
        if($choices -eq 'all') { $selectedTypes = $metadataResult.xmlName }
        else { $selectedTypes = $choices -split ',' | ForEach-Object { if($_.Trim() -match '^\d+$') { $metadataResult[[int]$_.Trim() - 1].xmlName } } }
        
        if($selectedTypes.Count -eq 0) { Write-Log -Level WARN "No valid types selected."; return }
        
        $manifestContent = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<Package xmlns=`"http://soap.sforce.com/2006/04/metadata`">"
        $selectedTypes | ForEach-Object { $manifestContent += "`n  <types>`n    <members>*</members>`n    <name>$_</name>`n  </types>" }
        $manifestContent += "`n  <version>$($Script:Settings.ApiVersion)</version>`n</Package>"
        
        $manifestPath = Join-Path -Path $Script:ProjectRoot -ChildPath "package.xml"
        $manifestContent | Out-File -FilePath $manifestPath -Encoding UTF8
        Write-Log -Level INFO "Custom manifest generated at '$manifestPath'"
    } catch {
        Write-Log -Level ERROR "Failed to generate custom manifest. Error: $($_.Exception.Message | Out-String)"
    }
}

function Deploy-Metadata-Advanced {
    Write-Log -Level DEBUG "Entering function 'Deploy-Metadata-Advanced'."
    if (-not (Ensure-Orgs-Selected)) { return }
    
    try {
        Write-Host "`nReminder: For best results, commit all changes to Git before deploying." -ForegroundColor DarkGray
        $targetOrg = $Script:Settings.DestinationOrgAlias
        
        $deltaPackageDir = Join-Path -Path $Script:ProjectRoot -ChildPath "delta-deployment"
        
        $pathToDeploy = ""
        if (Test-Path $deltaPackageDir) {
            if ((Read-Host "A `delta-deployment` package was found. Do you want to deploy it? (y/n)").ToLower() -eq 'y') {
                $pathToDeploy = $deltaPackageDir
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($pathToDeploy)) {
            $pathToDeploy = Read-Host "Enter the path to the directory containing the metadata to deploy (e.g., force-app)"
        }

        if (-not (Test-Path $pathToDeploy)) { throw "Invalid path. Directory not found at '$pathToDeploy'." }
        
        Write-Log -Level INFO "Starting deployment of folder '$pathToDeploy' to org '$targetOrg'."
        $deployCommand = "sf project deploy start --metadata-dir `"$pathToDeploy`" --target-org $targetOrg --api-version $($Script:Settings.ApiVersion)"

        $testLevel = Read-Host "Enter test level (NoTestRun, RunLocalTests, RunAllTestsInOrg, RunSpecifiedTests)"
        $deployCommand += " --test-level $testLevel"
        
        if ($testLevel -eq "RunSpecifiedTests") {
            $testsToRun = Read-Host 'Enter comma-separated test classes'
            if (-not [string]::IsNullOrWhiteSpace($testsToRun)) { $deployCommand += " --tests `"$testsToRun`"" }
        }

        Write-Host ""
        if ((Read-Host "Do you want to VALIDATE first before deploying? (y/n)").ToLower() -eq 'y') {
            Write-Log -Level INFO "Running validation..."
            Invoke-Expression "$($deployCommand) --dry-run" | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Validation failed." }
            Write-Log -Level INFO "Validation successful."
            if ((Read-Host "`nValidation successful. To proceed with deployment, type alias '$targetOrg' again") -ne $targetOrg) {
                Write-Log -Level INFO "Deployment cancelled by user."; return
            }
        }

        Write-Log -Level INFO "Running final deployment command: $deployCommand"
        Invoke-Expression $deployCommand | Out-Host
        if($LASTEXITCODE -ne 0) { throw "Deployment failed."}

        Write-Host "`n✅ DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green

    } catch {
           Write-Log -Level ERROR "Deployment failed. Error: $($_.Exception.Message | Out-String)"
    }
    Read-Host "`nPress Enter..."
}


function Update-Metadata-Mappings {
    $startTime = Start-Operation "Update Metadata Mappings"
    if (-not $Script:Settings.SourceOrgAlias) { Write-Log -Level ERROR "Please select a Source Org first using option [4]."; Read-Host; return }
    
    try {
        Write-Log -Level INFO "Fetching all metadata types from org '$($Script:Settings.SourceOrgAlias)'..."
        $rawJsonOutput = sf org list metadata-types --target-org $Script:Settings.SourceOrgAlias --json --api-version $Script:Settings.ApiVersion
        if ($LASTEXITCODE -ne 0) { throw "The 'sf org list metadata-types' command failed. Output: $rawJsonOutput" }
        Write-Log -Level DEBUG "Raw JSON from sf: $rawJsonOutput"
        $metadataJson = $rawJsonOutput | ConvertFrom-Json

        $mappingData = @{}
        $newTypesFound = 0
        
        # CORRECTED: Loop directly over the 'result' array, not a non-existent 'metadataObjects' property.
        foreach ($type in @($metadataJson.result)) {
            if ($type.directoryName) {
                $mappingData[$type.directoryName] = $type.xmlName
                if (-not $Script:MetadataMap.ContainsKey($type.directoryName)) {
                    $newTypesFound++
                }
            }
        }
        
        $Script:MetadataMap = $mappingData

        $fileContent = @{
            lastUpdated = (Get-Date -Format "o")
            mappings    = $mappingData
        }

        $fileContent | ConvertTo-Json -Depth 5 | Out-File $Script:METADATA_MAP_FILE -Encoding utf8 -ErrorAction Stop
        Write-Log -Level INFO "Metadata map updated successfully. Total types: $($mappingData.Count). Found $newTypesFound new type(s)."
        Write-Host "✅ Metadata map has been updated." -ForegroundColor Green
    } catch {
        Write-Log -Level ERROR "Failed to update metadata mappings. Error: $($_.Exception.Message | Out-String)"
    }
    End-Operation -startTime $startTime
}


function Edit-ProjectSettings {
    Write-Log -Level DEBUG "Entering function 'Edit-ProjectSettings'."
    try {
        Write-Host "`n[1] Set Project Default API Version" -ForegroundColor Cyan
        Write-Host "[2] Set Project Log Level" -ForegroundColor Cyan
        $choice = Read-Host "> Enter your choice"
        Write-Log -Level DEBUG "User chose option '$choice' in Edit-ProjectSettings."

        if ($choice -eq '1') {
            Write-Host "`nCurrent Project Default API Version: $($Script:Settings.ApiVersion)" -ForegroundColor Cyan
            $newApi = Read-Host "Enter new API Version (or press Enter to keep)"
            if (-not [string]::IsNullOrWhiteSpace($newApi)) {
                $Script:Settings.ApiVersion = $newApi; Save-Settings
                Write-Log -Level INFO "Project Default API Version manually updated to $($newApi)."
            }
        }
        elseif ($choice -eq '2') {
            Write-Host "`nCurrent log level: $($Script:Settings.logLevel)" -ForegroundColor Cyan
            Write-Host "[1] INFO  (Default, standard logging)"
            Write-Host "[2] DEBUG (Verbose, for troubleshooting)"
            $logChoice = Read-Host "Select new log level"
            if ($logChoice -eq '1') { $Script:Settings.logLevel = "INFO" }
            elseif ($logChoice -eq '2') { $Script:Settings.logLevel = "DEBUG" }
            else { Write-Log -Level WARN "Invalid selection."; return }
            Save-Settings
            Write-Log -Level INFO "Log level set to '$($Script:Settings.logLevel)'."
        }
    } catch {
        Write-Log -Level ERROR "Failed to edit settings. Error: $($_.Exception.Message | Out-String)"
    }
}

function Analyze-Permissions-Local {
    Write-Log -Level DEBUG "Entering function 'Analyze-Permissions-Local'."
    try {
        Write-Host "`nReminder: For best results, use Permission Sets over Profiles." -ForegroundColor DarkGray
        $sourcePath = Read-Host "Enter path to folder containing profiles/permissionsets"
        if (-not (Test-Path $sourcePath)) { Write-Log -Level ERROR "Invalid path: $sourcePath"; Read-Host; return }
        Get-ChildItem -Path $sourcePath -Filter "*.profile-meta.xml", "*.permissionset-meta.xml" -Recurse | ForEach-Object {
            Write-Host "`nAnalyzing: $($_.Name)" -ForegroundColor Yellow
            try {
                $xml = [xml](Get-Content $_.FullName); Write-Host " - FieldPerms:$($xml.SelectNodes('//fieldPermissions').Count) | ObjectPerms:$($xml.SelectNodes('//objectPermissions').Count) | ClassAccess:$($xml.SelectNodes('//classAccesses').Count)"
            } catch { Write-Log -Level WARN "Could not parse XML file: $($_.FullName)." }
        }
    } catch {
        Write-Log -Level ERROR "Failed to analyze permissions. Error: $($_.Exception.Message | Out-String)"
    }
}

function View-LogFile {
    try {
        if (Test-Path $Script:ProjectLogFile) { Invoke-Item $Script:ProjectLogFile } else { Write-Log -Level WARN "Project log file does not exist yet." }
    } catch {
        Write-Log -Level ERROR "Could not open log file. Error: $($_.Exception.Message | Out-String)"
    }
    Read-Host "`nPress Enter..."
}

function Clear-ProjectCache {
    param([string]$property)
    Write-Log -Level INFO "Clearing project cache for property: $($property | Out-String)"
    try {
        if($property) { if ($Script:Settings.PSObject.Properties[$property]) { $Script:Settings.PSObject.Properties.Remove($property) } }
        else {
            if ($Script:Settings.PSObject.Properties['Orgs']) { $Script:Settings.PSObject.Properties.Remove("Orgs") }
            if ($Script:Settings.PSObject.Properties['MetadataTypes']) { $Script:Settings.PSObject.Properties.Remove("MetadataTypes") }
        }
        Save-Settings;
        Write-Log -Level INFO "Project cache cleared."
    } catch {
        Write-Log -Level ERROR "Failed to clear cache. Error: $($_.Exception.Message | Out-String)"
    }
}
#endregion

#region Main Script Body
function Main {
    $originalLocation = Get-Location
    try {
        Initialize-Toolkit
        
        $projectInitialized = Select-Project
        if (-not $projectInitialized) { Write-Log -Level WARN "No project selected or initialized. Exiting."; return }
        
        # Smart Onboarding wizard for new/unconfigured projects
        if (-not $Script:Settings.SourceOrgAlias) {
            Write-Log -Level INFO "New or unconfigured project detected. Starting one-time setup wizard..."
            Check-Prerequisites
            Select-Org
            
            $mapIsStale = $true
            try {
                if ((Test-Path $Script:METADATA_MAP_FILE)) {
                    $mapContent = Get-Content $Script:METADATA_MAP_FILE -Raw
                    if (-not [string]::IsNullOrWhiteSpace($mapContent)) {
                        # CORRECTED: Wrap JSON parsing in try/catch to handle empty/corrupt files.
                        $mapJson = $mapContent | ConvertFrom-Json
                        if ($mapJson.lastUpdated -and ((Get-Date) - [datetime]$mapJson.lastUpdated).TotalDays -le 7) {
                           $mapIsStale = $false
                        }
                    }
                }
            } catch {
                 Write-Log -Level WARN "Could not parse existing metadata map. Will recommend update."
            }

            if ($mapIsStale) {
                Write-Host "`nYour metadata map is missing or older than 7 days." -ForegroundColor Yellow
                if((Read-Host "It is recommended to create/update it now. Update now? (y/n)").ToLower() -eq 'y') {
                    if($Script:Settings.SourceOrgAlias) { Update-Metadata-Mappings }
                    else { Write-Log -Level WARN "Cannot update map without a selected Source Org."}
                }
            }
        } else {
            Check-Prerequisites
        }

        while ($true) {
            Show-MainMenu
            $choice = Read-Host "> Enter your choice"
            Write-Log -Level DEBUG "User entered choice '$choice'."
            switch ($choice.ToLower()) {
                '1'  { Handle-CompareAndDeploy-SubMenu }
                '2'  {
                    $result = Handle-ProjectSetup-SubMenu
                    if ($result -eq "switch") { Main; return }
                }
                '3'  { Handle-Utilities-SubMenu }
                's'  { Main; return } # Kept as a hidden alias for switching projects
                'q'  { Write-Log -Level INFO "User chose to quit. Exiting script."; Save-Settings; return }
                default { Write-Log -Level WARN "Invalid option '$choice'." ; Start-Sleep 1 }
            }
        }
    }
    catch {
        Write-Log -Level ERROR "An unhandled exception occurred in the Main script body. Error: $($_.Exception.Message | Out-String)"
        Read-Host "A fatal error occurred. Check the log for details. Press Enter to exit."
    }
    finally {
        Set-Location -Path $originalLocation
        Write-Log -Level INFO "============================ Toolkit Session Ended ============================"
    }
}

# --- Script Entry Point ---
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host
Main
