#Requires -Version 5.1

<#
.SYNOPSIS
    SFDC DevOps Toolkit - Modular Version (Clean)

.DESCRIPTION
    This is the main orchestrator script for the modular SFDC DevOps Toolkit.
    It imports all necessary modules and provides the main entry point for the application.

.NOTES
    Author:      Amit Bhardwaj
    Version:     14.2.0
    Created:     2025-01-18
    License:     MIT
    Requires:    PowerShell 5.1+, Windows Terminal (Recommended), Salesforce CLI.
#>

[CmdletBinding()]
param(
    [switch]$NonInteractive = $false
)

#region Script Configuration and State
$Script:VERSION = "14.2.0"

# Navigation Breadcrumb System
$Script:NavigationStack = @()
$Script:CurrentLocation = "Main Menu"

# Initialize author information with defaults
$Script:AuthorName = "Amit Bhardwaj"
$Script:AuthorLinkedIn = "linkedin.com/in/salesforce-technical-architect"
$Script:REMOTE_CONTROL_URL = "https://raw.githubusercontent.com/sfdcai/sfdc-toolkit/refs/heads/main/control.json"
$Script:DEPENDENCY_CONFIG_URL = "https://raw.githubusercontent.com/sfdcai/sfdc-toolkit/refs/heads/main/salesforce-deployment-config/dependency-config.json"
$Script:MAX_LOG_SIZE_MB = 10

# Module paths
$Script:ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "modules"

# Initialize module variables
$Script:Config = $null
$Script:Settings = $null
$Script:IsInitialized = $false
$Script:TOOLKIT_ROOT_CONFIG_DIR = $null
$Script:ROOT_PROJECT_LIST_FILE = $null
$Script:METADATA_MAP_FILE = $null
$Script:GLOBAL_LOG_FILE = $null
$Script:ProjectRoot = $null
$Script:ProjectLogFile = $null
$Script:MetadataMap = @{}
#endregion

#region Module Loading
function Import-ToolkitModules {
    <#
    .SYNOPSIS
        Imports all required toolkit modules
        
    .DESCRIPTION
        Dynamically loads all PowerShell modules required by the toolkit
        with proper error handling and fallback mechanisms.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "Loading toolkit modules..." -ForegroundColor Cyan
        
        # List of modules to import
        $modules = @(
            "SFDC-Toolkit-Configuration-Clean",
            "SFDC-Toolkit-Logging-Clean"
        )
        
        $loadedModules = @()
        $failedModules = @()
        
        foreach ($moduleName in $modules) {
            try {
                $modulePath = Join-Path -Path $Script:ModulePath -ChildPath "$moduleName.psm1"
                
                if (-not (Test-Path $modulePath)) {
                    Write-Host "Module not found: $moduleName" -ForegroundColor Yellow
                    $failedModules += $moduleName
                    continue
                }
                
                # Import the module
                Import-Module $modulePath -Force -ErrorAction Stop
                $loadedModules += $moduleName
                Write-Host "Loaded: $moduleName" -ForegroundColor Green
                
            } catch {
                Write-Host "Failed to load module: $moduleName - $($_.Exception.Message)" -ForegroundColor Red
                $failedModules += $moduleName
            }
        }
        
        # Report results
        Write-Host "Module Loading Summary:" -ForegroundColor Cyan
        Write-Host "Successfully loaded: $($loadedModules.Count) modules" -ForegroundColor Green
        if ($failedModules.Count -gt 0) {
            Write-Host "Failed to load: $($failedModules.Count) modules" -ForegroundColor Red
            Write-Host "Failed modules: $($failedModules -join ', ')" -ForegroundColor Red
        }
        
        # Check if critical modules loaded
        if ($loadedModules -notcontains "SFDC-Toolkit-Configuration-Clean") {
            throw "Critical module 'SFDC-Toolkit-Configuration-Clean' failed to load"
        }
        
        if ($loadedModules -notcontains "SFDC-Toolkit-Logging-Clean") {
            throw "Critical module 'SFDC-Toolkit-Logging-Clean' failed to load"
        }
        
        Write-Host "All critical modules loaded successfully!" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Module loading failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ModuleDependencies {
    <#
    .SYNOPSIS
        Tests if all required modules are available
        
    .DESCRIPTION
        Verifies that all required modules are loaded and functional.
    #>
    [CmdletBinding()]
    param()
    
    $requiredModules = @(
        "SFDC-Toolkit-Configuration-Clean",
        "SFDC-Toolkit-Logging-Clean"
    )
    
    $missingModules = @()
    
    foreach ($moduleName in $requiredModules) {
        if (-not (Get-Module -Name $moduleName -ErrorAction SilentlyContinue)) {
            $missingModules += $moduleName
        }
    }
    
    if ($missingModules.Count -gt 0) {
        Write-Host "Missing required modules: $($missingModules -join ', ')" -ForegroundColor Red
        return $false
    }
    
    return $true
}
#endregion

#region Main Functions
function Show-Banner {
    <#
    .SYNOPSIS
        Shows the application banner
        
    .DESCRIPTION
        Displays a formatted banner with version information and author details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title
    )
    
    Clear-Host
    Write-Host "=================================================================================" -ForegroundColor Blue
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=================================================================================" -ForegroundColor Blue
    Write-Host "Created by $Script:AuthorName ($Script:AuthorLinkedIn)" -ForegroundColor DarkGray
    Write-Host "=================================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Initialize-Toolkit {
    <#
    .SYNOPSIS
        Initializes the modular toolkit system
        
    .DESCRIPTION
        Sets up the toolkit with proper module loading, configuration initialization,
        and system compatibility checks.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "Initializing SFDC DevOps Toolkit v$($Script:VERSION)..." -ForegroundColor Cyan
        
        # Load modules first
        if (-not (Import-ToolkitModules)) {
            throw "Failed to load required modules"
        }
        
        # Test module dependencies
        if (-not (Test-ModuleDependencies)) {
            throw "Module dependency check failed"
        }
        
        # Initialize configuration using the module
        Write-Host "Initializing configuration..." -ForegroundColor Cyan
        if (-not (Initialize-ToolkitConfiguration)) {
            throw "Configuration initialization failed"
        }
        
        # Set author variables from configuration
        $Script:AuthorName = $Script:Config.AuthorName
        $Script:AuthorLinkedIn = $Script:Config.AuthorLinkedIn
        
        # Show welcome banner
        $welcomeTitle = "SFDC DevOps Toolkit v$($Script:VERSION) (Modular)"
        if ($Script:Config.WelcomeText) {
            $welcomeTitle = $Script:Config.WelcomeText
        }
        
        Show-Banner -Title $welcomeTitle
        
        # Check for version updates
        $remoteVersion = if ($Script:Config.PSObject.Properties.Name -contains 'LatestVersion') { $Script:Config.LatestVersion } else { 'Not Available' }
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level INFO "Version check: Current=$($Script:VERSION), Remote=$remoteVersion"
        }
        if ($Script:Config.PSObject.Properties.Name -contains "LatestVersion") {
            if ($Script:VERSION -ne $Script:Config.LatestVersion) {
                Write-Host "UPDATE AVAILABLE: A newer version ($($Script:Config.LatestVersion)) of the toolkit is available." -ForegroundColor Green
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log -Level INFO "UPDATE AVAILABLE: Current version $($Script:VERSION) -> New version $($Script:Config.LatestVersion)"
                }
            } else {
                if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                    Write-Log -Level INFO "Toolkit is up to date (version $($Script:VERSION))"
                }
            }
        }
        
        # Display remote message if available
        if ($Script:Config.PSObject.Properties.Name -contains "RemoteMessage" -and -not [string]::IsNullOrWhiteSpace($Script:Config.RemoteMessage)) {
            Write-Host "REMOTE MESSAGE: $($Script:Config.RemoteMessage)" -ForegroundColor Yellow
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                Write-Log -Level INFO "Remote message displayed: $($Script:Config.RemoteMessage)"
            }
        }
        
        Write-Host "Toolkit initialized successfully!" -ForegroundColor Green
        Write-Host "Modules loaded: $(Get-Module | Where-Object { $_.Name -like 'SFDC-Toolkit-*' } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor Cyan
        
        $Script:IsInitialized = $true
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Started ==================="
            Write-Log -Level INFO "Session Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }
        
        if (-not $NonInteractive) {
            Read-Host "Press Enter to begin..."
        }
        
    } catch {
        Write-Host "Toolkit initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Falling back to basic mode..." -ForegroundColor Yellow
        
        # Emergency fallback - try to continue with basic functionality
        $Script:IsInitialized = $false
        Show-Banner -Title "SFDC DevOps Toolkit (Basic Mode)"
        if (-not $NonInteractive) {
            Read-Host "Press Enter to continue in basic mode..."
        }
    }
}

function Main {
    <#
    .SYNOPSIS
        Main entry point for the modular toolkit
        
    .DESCRIPTION
        Orchestrates the main application flow with proper error handling
        and module management.
    #>
    $originalLocation = Get-Location
    try {
        # Initialize the toolkit
        Initialize-Toolkit
        
        if (-not $Script:IsInitialized) {
            Write-Host "Toolkit initialization failed. Exiting." -ForegroundColor Red
            return
        }
        
        # For now, show a simple menu until we implement the full functionality
        Write-Host "Modular Toolkit is ready!" -ForegroundColor Green
        Write-Host "Available modules:" -ForegroundColor Cyan
        
        Get-Module | Where-Object { $_.Name -like 'SFDC-Toolkit-*' } | ForEach-Object {
            Write-Host "  $($_.Name) v$($_.Version)" -ForegroundColor Green
        }
        
        Write-Host "Configuration loaded:" -ForegroundColor Cyan
        Write-Host "  Toolkit Root: $Script:TOOLKIT_ROOT_CONFIG_DIR" -ForegroundColor White
        Write-Host "  Global Log: $Script:GLOBAL_LOG_FILE" -ForegroundColor White
        Write-Host "  Remote Control: $(if ($Script:Config.RemoteControl.Enabled) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
        
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Implement remaining modules (Salesforce Operations, UI, etc.)" -ForegroundColor White
        Write-Host "  2. Add project management functionality" -ForegroundColor White
        Write-Host "  3. Implement delta generation and deployment features" -ForegroundColor White
        Write-Host "  4. Add comprehensive error handling and retry mechanisms" -ForegroundColor White
        Write-Host "  5. Create Pester unit tests" -ForegroundColor White
        
        Write-Host "Modular architecture successfully implemented!" -ForegroundColor Green
        
    } catch {
        Write-Host "An unhandled exception occurred: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Check the log file for more details." -ForegroundColor Yellow
    } finally {
        Set-Location -Path $originalLocation
        Write-Host "Thank you for using SFDC DevOps Toolkit!" -ForegroundColor Cyan
    }
}
#endregion

#region Script Entry Point
# Handle console settings safely
try {
    if ($Host.UI.RawUI) {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        $Host.UI.RawUI.ForegroundColor = 'White'
    }
    try { Clear-Host } catch { }
} catch {
    # Ignore console setting errors
}

# Start the main application
Main
#endregion
