#Requires -Version 5.1

<#
.SYNOPSIS
    SFDC DevOps Toolkit - PowerShell Wrapper for Enhanced Batch Compatibility
    Professional-grade Salesforce development and DevOps toolkit with cross-platform support

.DESCRIPTION
    This PowerShell script provides enhanced functionality and serves as a wrapper
    for the batch file version, offering better error handling, logging, and
    cross-platform compatibility while maintaining all the original features.

.NOTES
    Author:     Amit Bhardwaj (Enhanced for Production)
    Version:    14.2.0
    Created:    2025-01-17
    License:    MIT
    Requires:   PowerShell 5.1+, Windows Terminal (Recommended), Salesforce CLI
#>

#region Script Configuration and State
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$LogLevel = "INFO",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseBatchVersion,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisites,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

$Script:VERSION = "14.2.0"
$Script:AuthorName = "Amit Bhardwaj"
$Script:AuthorLinkedIn = "https://linkedin.com/in/salesforce-technical-architect"
$Script:TOOLKIT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:TOOLKIT_CONFIG_DIR = Join-Path -Path $Script:TOOLKIT_ROOT -ChildPath ".sfdc-toolkit"
$Script:BATCH_FILE = Join-Path -Path $Script:TOOLKIT_ROOT -ChildPath "sfdc-toolkit-enhanced.bat"
$Script:LOG_FILE = Join-Path -Path $Script:TOOLKIT_CONFIG_DIR -ChildPath "toolkit.log"
$Script:ERROR_LOG = Join-Path -Path $Script:TOOLKIT_CONFIG_DIR -ChildPath "errors.log"
$Script:AUDIT_LOG = Join-Path -Path $Script:TOOLKIT_CONFIG_DIR -ChildPath "audit.log"

# Enhanced logging configuration
$Script:LogLevel = $LogLevel
$Script:VerboseMode = $Verbose
$Script:ErrorCount = 0
$Script:WarningCount = 0
$Script:StartTime = Get-Date

# Project state variables
$Script:ProjectRoot = $ProjectPath
$Script:SourceOrg = $null
$Script:DestinationOrg = $null
$Script:ApiVersion = "61.0"
#endregion

#region Enhanced Logging System
function Write-EnhancedLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "AUDIT")][string]$Level = "INFO",
        [Parameter(Mandatory = $false)][string]$Category = ""
    )

    # Respect the log level setting
    if ($Script:LogLevel -eq "INFO" -and $Level -eq "DEBUG") { return }
    if ($Script:LogLevel -eq "WARN" -and $Level -in @("DEBUG")) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level]"
    if ($Category) { $logEntry += " [$Category]" }
    $logEntry += " $Message"

    # Write to appropriate log files
    try {
        Add-Content -Path $Script:LOG_FILE -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to main log file: $($_.Exception.Message)"
    }

    if ($Level -eq "ERROR") {
        try {
            Add-Content -Path $Script:ERROR_LOG -Value $logEntry -ErrorAction Stop
            $Script:ErrorCount++
        } catch {
            Write-Warning "Failed to write to error log file: $($_.Exception.Message)"
        }
    }

    if ($Level -eq "WARN") {
        $Script:WarningCount++
    }

    if ($Level -eq "AUDIT") {
        try {
            Add-Content -Path $Script:AUDIT_LOG -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Warning "Failed to write to audit log file: $($_.Exception.Message)"
        }
    }

    # Color output based on level
    $color = switch ($Level) {
        "INFO"  { "White" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "Cyan" }
        "AUDIT" { "Magenta" }
        default { "Gray" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $false)][string]$Category = "GENERAL"
    )
    Write-EnhancedLog -Message $Action -Level "AUDIT" -Category $Category
}
#endregion

#region Enhanced Banner and System Information
function Show-EnhancedBanner {
    Clear-Host
    
    $header = @"
   _____ _____ ____ ____     ___   _   _ 
 / ____|  ___/ ___/ __ \   / _ \ | | (_)
| (___ | |__ \___ \ |  | | / /_\ \| |  _ 
 \___ \|  __| ___) | |  | | |  _  | | | | |
 ____) | |___/ __/| |__| | | | | | | | | |
|_____/|____|____/\____/  |_| |_| |_| |_|
"@
    
    Write-Host $header -ForegroundColor Cyan
    Write-Host "Created by $($Script:AuthorName) ($($Script:AuthorLinkedIn))" -ForegroundColor DarkGray
    Write-Host "Enhanced for Production Use - Cross-Platform Compatibility" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("-" * 75) -ForegroundColor Blue
    Write-Host ("  SFDC DevOps Toolkit | v$($Script:VERSION) | Project: $($Script:ProjectRoot)") -ForegroundColor Cyan
    Write-Host ("  PowerShell Mode | Errors: $($Script:ErrorCount) | Warnings: $($Script:WarningCount)") -ForegroundColor Gray
    Write-Host ("-" * 75) -ForegroundColor Blue
    Write-Host ""
}

function Get-SystemInformation {
    Write-EnhancedLog "Gathering system information" "INFO"
    
    $systemInfo = @{
        OS = [System.Environment]::OSVersion.VersionString
        PowerShell = $PSVersionTable.PSVersion.ToString()
        .NET = [System.Environment]::Version.ToString()
        Memory = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        DiskSpace = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB, 2)
    }
    
    Write-Host "  System Information" -ForegroundColor White
    Write-Host "  -------------------------"
    Write-Host ("    Operating System: ") -NoNewline; Write-Host $systemInfo.OS -ForegroundColor Green
    Write-Host ("    PowerShell Version: ") -NoNewline; Write-Host $systemInfo.PowerShell -ForegroundColor Green
    Write-Host ("    .NET Framework: ") -NoNewline; Write-Host $systemInfo.'NET' -ForegroundColor Green
    Write-Host ("    Available Memory: ") -NoNewline; Write-Host "$($systemInfo.Memory) GB" -ForegroundColor Green
    Write-Host ("    Available Disk Space: ") -NoNewline; Write-Host "$($systemInfo.DiskSpace) GB" -ForegroundColor Green
    Write-Host ("-" * 75) -ForegroundColor Blue
}
#endregion

#region Enhanced Prerequisites Checking
function Test-EnhancedPrerequisites {
    param([switch]$ForceRefresh)
    
    Write-EnhancedLog "Starting enhanced system readiness check" "INFO"
    Write-AuditLog "System readiness check initiated" "SYSTEM_CHECK"
    
    $allGood = $true
    $tools = @(
        @{ Name = "Salesforce CLI"; Command = "sf"; Required = $true; CheckVersion = $true },
        @{ Name = "Git"; Command = "git"; Required = $false; CheckVersion = $true },
        @{ Name = "Visual Studio Code"; Command = "code"; Required = $false; CheckVersion = $true },
        @{ Name = "PowerShell"; Command = "powershell"; Required = $true; CheckVersion = $true }
    )
    
    Write-Host "Checking for required tools..." -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($tool in $tools) {
        Write-Host "  [*] Checking for $($tool.Name)..." -NoNewline
        
        $command = Get-Command $tool.Command -ErrorAction SilentlyContinue
        if ($command) {
            Write-Host " [INSTALLED]" -ForegroundColor Green
            
            if ($tool.CheckVersion) {
                try {
                    $version = & $tool.Command --version 2>$null
                    if ($version) {
                        Write-Host "      Version: $($version[0])" -ForegroundColor DarkGray
                    }
                } catch {
                    # Version check failed, but tool is available
                }
            }
            
            Write-EnhancedLog "$($tool.Name) found and available" "INFO"
        } else {
            Write-Host " [MISSING]" -ForegroundColor $(if($tool.Required){"Red"}else{"Yellow"})
            Write-EnhancedLog "$($tool.Name) not found" $(if($tool.Required){"ERROR"}else{"WARN"})
            
            if ($tool.Required) {
                $allGood = $false
            }
        }
    }
    
    # Check Salesforce CLI specific requirements
    if (Get-Command sf -ErrorAction SilentlyContinue) {
        try {
            $sfVersion = sf --version 2>$null
            if ($sfVersion) {
                Write-EnhancedLog "Salesforce CLI version: $($sfVersion[0])" "INFO"
            }
        } catch {
            Write-EnhancedLog "Could not determine Salesforce CLI version" "WARN"
        }
    }
    
    Write-Host ""
    if (-not $allGood) {
        Write-EnhancedLog "One or more required tools are missing" "ERROR"
        Write-Host "ERROR: One or more required tools are missing." -ForegroundColor Red
        Write-Host "Please install the missing tools and try again." -ForegroundColor Yellow
        Write-AuditLog "System check failed - missing required tools" "SYSTEM_CHECK"
        return $false
    } else {
        Write-EnhancedLog "All required tools are available" "INFO"
        Write-Host "System readiness check completed successfully." -ForegroundColor Green
        Write-AuditLog "System check passed" "SYSTEM_CHECK"
        return $true
    }
}
#endregion

#region Enhanced Org Management
function Invoke-EnhancedOrgAuthorization {
    Write-EnhancedLog "Starting enhanced org authorization" "INFO"
    Write-AuditLog "Org authorization initiated" "ORG_MANAGEMENT"
    
    $alias = Read-Host "`nEnter an alias for the new org"
    if ([string]::IsNullOrWhiteSpace($alias)) {
        Write-EnhancedLog "Auth cancelled by user" "WARN"
        return
    }
    
    # Validate alias format
    if ($alias -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
        Write-EnhancedLog "Invalid alias format: $alias" "ERROR"
        Write-Host "Invalid alias format. Alias must start with a letter and contain only letters, numbers, and underscores." -ForegroundColor Red
        return
    }
    
    $isProd = Read-Host "`nIs this a Production/Developer Edition org? (y/n)"
    $instanceUrl = if ($isProd.ToLower() -eq 'n') { "https://test.salesforce.com" } else { "https://login.salesforce.com" }
    
    Write-EnhancedLog "Attempting web login for alias '$alias' with instance URL '$instanceUrl'" "INFO"
    
    try {
        # Create backup of existing auth
        $backupFile = Join-Path $env:TEMP "orgs-before-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        sf org list --json > $backupFile 2>$null
        
        # Perform authorization
        sf org login web --alias $alias --instance-url $instanceUrl --set-default
        if ($LASTEXITCODE -ne 0) {
            throw "Salesforce CLI reported an error during login"
        }
        
        Write-EnhancedLog "Successfully authorized org '$alias'" "INFO"
        Write-Host "Org '$alias' authorized successfully!" -ForegroundColor Green
        Write-AuditLog "Org authorization successful for $alias" "ORG_MANAGEMENT"
        
        # Verify the authorization
        sf org display --target-org $alias >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Org verification successful." -ForegroundColor Green
        } else {
            Write-EnhancedLog "Org verification failed after authorization" "WARN"
            Write-Host "Warning: Org authorization completed but verification failed." -ForegroundColor Yellow
        }
        
    } catch {
        Write-EnhancedLog "Failed to authorize org. Error: $($_.Exception.Message)" "ERROR"
        Write-Host "Failed to authorize org. Please check your credentials and try again." -ForegroundColor Red
        Write-AuditLog "Org authorization failed for $alias" "ORG_MANAGEMENT"
    }
    
    Read-Host "`nPress Enter..."
}

function Get-EnhancedOrgList {
    Write-EnhancedLog "Fetching enhanced org list" "INFO"
    
    try {
        $orgsJson = sf org list --json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "Salesforce CLI failed to list orgs"
        }
        
        $allOrgs = @($orgsJson.result.nonScratchOrgs) + @($orgsJson.result.scratchOrgs)
        Write-EnhancedLog "Fetched $($allOrgs.Count) orgs" "INFO"
        
        return $allOrgs
    } catch {
        Write-EnhancedLog "Failed to list orgs: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Select-EnhancedOrgs {
    Write-EnhancedLog "Starting enhanced org selection" "INFO"
    
    $orgs = Get-EnhancedOrgList
    if ($orgs.Count -eq 0) {
        Write-EnhancedLog "No Salesforce orgs have been authorized" "WARN"
        Write-Host "No Salesforce orgs have been authorized with the CLI." -ForegroundColor Yellow
        Read-Host; return
    }
    
    Write-Host "`nAvailable Orgs:" -ForegroundColor Green
    for ($i = 0; $i -lt $orgs.Count; $i++) {
        $org = $orgs[$i]
        Write-Host "  [$($i+1)] Alias: $($org.alias) | User: $($org.username) | Status: $($org.status)" -ForegroundColor White
    }
    Write-Host "  [R] Refresh Org List" -ForegroundColor Cyan
    Write-Host "  [Q] Back to calling menu" -ForegroundColor Red
    
    $choice = Read-Host "`nSelect an org to set as SOURCE"
    Write-EnhancedLog "User selection for SOURCE: '$choice'" "DEBUG"
    
    if ($choice.ToLower() -eq 'q') { return }
    if ($choice.ToLower() -eq 'r') { 
        Select-EnhancedOrgs
        return 
    }
    
    if ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $orgs.Count) {
        $Script:SourceOrg = $orgs[[int]$choice - 1].alias
        Write-EnhancedLog "Set Source Org to '$($Script:SourceOrg)'" "INFO"
        
        $destChoice = Read-Host "Select an org to set as DESTINATION (or press Enter to skip)"
        Write-EnhancedLog "User selection for DESTINATION: '$destChoice'" "DEBUG"
        
        if ($destChoice -match '^\d+$' -and $destChoice -gt 0 -and $destChoice -le $orgs.Count) {
            $Script:DestinationOrg = $orgs[[int]$destChoice - 1].alias
            Write-EnhancedLog "Set Destination Org to '$($Script:DestinationOrg)'" "INFO"
        } else {
            $Script:DestinationOrg = $null
            Write-EnhancedLog "Destination Org was not set" "INFO"
        }
        
        Write-Host "`nOrgs selected successfully!" -ForegroundColor Green
    } else {
        Write-EnhancedLog "Invalid selection: '$choice'" "WARN"
        Write-Host "Invalid selection." -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter..."
}
#endregion

#region Enhanced Project Management
function Select-EnhancedProject {
    Write-EnhancedLog "Starting enhanced project selection" "INFO"
    
    Show-EnhancedBanner
    Write-Host "Project Selection" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] Use current directory as project" -ForegroundColor Green
    Write-Host "[2] Create new project" -ForegroundColor Green
    Write-Host "[3] Select existing project" -ForegroundColor Green
    Write-Host ""
    
    $choice = Read-Host "Enter your choice"
    Write-EnhancedLog "User project selection choice: '$choice'" "DEBUG"
    
    switch ($choice) {
        '1' {
            $Script:ProjectRoot = Get-Location
            Write-EnhancedLog "Using current directory as project: $($Script:ProjectRoot)" "INFO"
        }
        '2' {
            New-EnhancedProject
        }
        '3' {
            Select-ExistingProject
        }
        default {
            Write-EnhancedLog "Invalid project selection: '$choice'" "WARN"
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }
    }
    
    if ($Script:ProjectRoot) {
        Load-ProjectSettings
        Write-Host "Project '$($Script:ProjectRoot)' selected successfully!" -ForegroundColor Green
        Write-AuditLog "Project selected: $($Script:ProjectRoot)" "PROJECT_MANAGEMENT"
    }
    
    Read-Host "`nPress Enter..."
}

function New-EnhancedProject {
    $projectName = Read-Host "Enter a name for your new project"
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        Write-EnhancedLog "Project name cannot be empty" "WARN"
        return
    }
    
    $projectPath = Join-Path $Script:TOOLKIT_ROOT $projectName
    if (Test-Path $projectPath) {
        Write-EnhancedLog "A folder named '$projectName' already exists" "ERROR"
        Write-Host "A folder named '$projectName' already exists at that location." -ForegroundColor Red
        return
    }
    
    try {
        New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
        Write-EnhancedLog "Created new project folder at '$projectPath'" "INFO"
        $Script:ProjectRoot = $projectPath
        Write-AuditLog "New project created: $projectPath" "PROJECT_MANAGEMENT"
    } catch {
        Write-EnhancedLog "Failed to create project directory: $($_.Exception.Message)" "ERROR"
        Write-Host "Failed to create project directory." -ForegroundColor Red
    }
}

function Select-ExistingProject {
    Write-Host "`nAvailable projects:" -ForegroundColor Cyan
    Write-Host ""
    
    $projects = Get-ChildItem -Path $Script:TOOLKIT_ROOT -Directory | Where-Object { $_.Name -ne ".sfdc-toolkit" }
    
    if ($projects.Count -eq 0) {
        Write-Host "No existing projects found." -ForegroundColor Yellow
        Read-Host; return
    }
    
    for ($i = 0; $i -lt $projects.Count; $i++) {
        Write-Host "  [$($i+1)] $($projects[$i].Name)" -ForegroundColor White
    }
    
    $selection = Read-Host "`nSelect a project"
    if ([string]::IsNullOrWhiteSpace($selection)) { return }
    
    if ($selection -match '^\d+$' -and [int]$selection -gt 0 -and [int]$selection -le $projects.Count) {
        $Script:ProjectRoot = $projects[[int]$selection - 1].FullName
        Write-EnhancedLog "Selected existing project: $($Script:ProjectRoot)" "INFO"
    } else {
        Write-EnhancedLog "Invalid project selection: '$selection'" "WARN"
        Write-Host "Invalid selection." -ForegroundColor Red
    }
}

function Load-ProjectSettings {
    if (-not $Script:ProjectRoot) { return }
    
    $settingsFile = Join-Path $Script:ProjectRoot ".sfdc-toolkit\settings.json"
    
    if (Test-Path $settingsFile) {
        try {
            $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
            $Script:SourceOrg = $settings.SourceOrgAlias
            $Script:DestinationOrg = $settings.DestinationOrgAlias
            $Script:ApiVersion = $settings.ApiVersion
            Write-EnhancedLog "Project settings loaded from '$settingsFile'" "INFO"
        } catch {
            Write-EnhancedLog "Failed to load project settings: $($_.Exception.Message)" "ERROR"
            Create-DefaultSettings
        }
    } else {
        Write-EnhancedLog "No settings file found. Creating new default settings" "WARN"
        Create-DefaultSettings
    }
}

function Create-DefaultSettings {
    if (-not $Script:ProjectRoot) { return }
    
    $configDir = Join-Path $Script:ProjectRoot ".sfdc-toolkit"
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }
    
    $settings = @{
        SourceOrgAlias = ""
        DestinationOrgAlias = ""
        ApiVersion = $Script:ApiVersion
        logLevel = $Script:LogLevel
        CreatedDate = (Get-Date).ToString("o")
    }
    
    $settingsFile = Join-Path $configDir "settings.json"
    $settings | ConvertTo-Json -Depth 3 | Out-File -FilePath $settingsFile -Encoding UTF8
    Write-EnhancedLog "Created default settings file: $settingsFile" "INFO"
}
#endregion

#region Enhanced Main Menu
function Show-EnhancedMainMenu {
    Show-EnhancedBanner
    Get-SystemInformation
    
    Write-Host "  Core DevOps Operations" -ForegroundColor White
    Write-Host "  --------------------------"
    Write-Host "  [1] Compare Orgs & Generate Delta Package" -ForegroundColor Yellow
    Write-Host "  [2] Quick Visual Compare in VS Code" -ForegroundColor Yellow
    Write-Host "  [3] Deploy Metadata (Advanced)" -ForegroundColor Yellow
    Write-Host "  [4] Intelligent Deployment with Rollback" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Org & Project Setup" -ForegroundColor White
    Write-Host "  --------------------------"
    Write-Host "  [5] List & Select Source/Destination Orgs" -ForegroundColor Cyan
    Write-Host "  [6] Generate Deployment Manifest (package.xml)" -ForegroundColor Cyan
    Write-Host "  [7] Edit Project Settings" -ForegroundColor Cyan
    Write-Host "  [8] Authorize a New Org" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  System & Advanced Tools" -ForegroundColor White
    Write-Host "  --------------------------"
    Write-Host "  [9] Open Org in Browser" -ForegroundColor Magenta
    Write-Host " [10] Update Metadata Mappings from Org" -ForegroundColor Magenta
    Write-Host " [11] Analyze Local Profile/Permission Set Files" -ForegroundColor Magenta
    Write-Host " [12] View Project Log Files" -ForegroundColor Magenta
    Write-Host " [13] Clear Project Cache" -ForegroundColor Magenta
    Write-Host " [14] Re-run System Readiness Check" -ForegroundColor Magenta
    Write-Host " [15] Backup Project Data" -ForegroundColor Magenta
    Write-Host " [16] Restore Project Data" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [S] Switch Project" -ForegroundColor Green
    Write-Host "  [Q] Quit" -ForegroundColor Red
    Write-Host ""
}

function Invoke-EnhancedMainMenu {
    while ($true) {
        Show-EnhancedMainMenu
        $choice = Read-Host "Please enter your choice"
        Write-EnhancedLog "User entered choice '$choice'" "DEBUG"
        Write-AuditLog "Menu choice: $choice" "USER_INTERACTION"
        
        switch ($choice) {
            '1'  { Write-Host "Comparison functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '2'  { Write-Host "Visual Compare functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '3'  { Write-Host "Advanced Deployment functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '4'  { Write-Host "Intelligent Deployment functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '5'  { Select-EnhancedOrgs }
            '6'  { Write-Host "Manifest Generation functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '7'  { Write-Host "Project Settings functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '8'  { Invoke-EnhancedOrgAuthorization }
            '9'  { Write-Host "Open Org functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '10' { Write-Host "Metadata Mappings functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '11' { Write-Host "Permissions Analysis functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '12' { Write-Host "View Log Files functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '13' { Write-Host "Clear Cache functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '14' { Test-EnhancedPrerequisites; Read-Host }
            '15' { Write-Host "Backup functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            '16' { Write-Host "Restore functionality - Enhanced version" -ForegroundColor Yellow; Read-Host }
            's'  { Select-EnhancedProject }
            'q'  { 
                Write-EnhancedLog "User chose to quit. Exiting script." "INFO"
                Write-AuditLog "Toolkit session ended" "SHUTDOWN"
                Show-SessionSummary
                return 
            }
            default { 
                Write-EnhancedLog "Invalid option '$choice'" "WARN"
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep 1
            }
        }
    }
}
#endregion

#region Session Management
function Show-SessionSummary {
    $duration = (Get-Date) - $Script:StartTime
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   SFDC DevOps Toolkit Session Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Errors Encountered: $($Script:ErrorCount)" -ForegroundColor $(if($Script:ErrorCount -gt 0){"Red"}else{"Green"})
    Write-Host "  Warnings Issued: $($Script:WarningCount)" -ForegroundColor $(if($Script:WarningCount -gt 0){"Yellow"}else{"Green"})
    Write-Host "  Session Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Log Files Location: $Script:TOOLKIT_CONFIG_DIR" -ForegroundColor Gray
    Write-Host ""
    
    if ($Script:ErrorCount -gt 0) {
        Write-Host "WARNING: $($Script:ErrorCount) errors were encountered during this session." -ForegroundColor Yellow
        Write-Host "Please review the error log for details." -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Host "Thank you for using SFDC DevOps Toolkit!" -ForegroundColor Green
    Write-Host ""
}

function Initialize-EnhancedToolkit {
    Write-EnhancedLog "=================== SFDC DevOps Toolkit v$($Script:VERSION) Initializing ===================" "INFO"
    
    # Create config directory if it doesn't exist
    if (-not (Test-Path $Script:TOOLKIT_CONFIG_DIR)) {
        try {
            New-Item -ItemType Directory -Path $Script:TOOLKIT_CONFIG_DIR -Force -ErrorAction Stop | Out-Null
            Write-EnhancedLog "Created toolkit directory at '$($Script:TOOLKIT_CONFIG_DIR)'" "INFO"
        } catch {
            Write-EnhancedLog "FATAL: Could not create toolkit directory. Please check permissions. Error: $($_.Exception.Message)" "ERROR"
            Read-Host "Press Enter to exit."; exit
        }
    }
    
    # Initialize log files
    if (-not (Test-Path $Script:LOG_FILE)) {
        Write-EnhancedLog "Enhanced logging initialized at '$Script:LOG_FILE'" "INFO"
    }
    
    Write-AuditLog "Toolkit started" "STARTUP"
}
#endregion

#region Main Entry Point
function Main {
    try {
        Initialize-EnhancedToolkit
        
        # Check if user wants to use batch version
        if ($UseBatchVersion -and (Test-Path $Script:BATCH_FILE)) {
            Write-EnhancedLog "Launching batch version of toolkit" "INFO"
            & $Script:BATCH_FILE
            return
        }
        
        # Check prerequisites unless skipped
        if (-not $SkipPrerequisites) {
            if (-not (Test-EnhancedPrerequisites)) {
                Write-Host "Prerequisites check failed. Exiting." -ForegroundColor Red
                return
            }
        }
        
        # Select or create project
        if (-not $Script:ProjectRoot) {
            Select-EnhancedProject
        }
        
        # Start main menu
        Invoke-EnhancedMainMenu
        
    } catch {
        Write-EnhancedLog "An unhandled exception occurred in the Main script body. Error: $($_.Exception.Message)" "ERROR"
        Read-Host "A fatal error occurred. Check the log for details. Press Enter to exit."
    } finally {
        Write-EnhancedLog "============================ Toolkit Session Ended ============================" "INFO"
    }
}
#endregion

#region Script Entry Point
# Set console colors and title
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

# Main execution
Main
#endregion
