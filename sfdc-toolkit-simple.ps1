#Requires -Version 5.1

<#
.SYNOPSIS
    SFDC DevOps Toolkit - Simple Non-UI PowerShell Version
    Command-line interface for Salesforce DevOps operations

.DESCRIPTION
    This PowerShell script provides a simple command-line interface for Salesforce
    DevOps operations without any interactive UI elements. Perfect for automation
    and scripting scenarios.

.PARAMETER Command
    The command to execute (check-prereqs, auth-org, list-orgs, compare-orgs, deploy, generate-manifest, open-org)

.PARAMETER ProjectPath
    Path to the project directory

.PARAMETER SourceOrg
    Source org alias

.PARAMETER DestOrg
    Destination org alias

.PARAMETER ApiVersion
    Salesforce API version (default: 61.0)

.PARAMETER LogLevel
    Log level (INFO, DEBUG, WARN, ERROR)

.EXAMPLE
    .\sfdc-toolkit-simple.ps1 check-prereqs

.EXAMPLE
    .\sfdc-toolkit-simple.ps1 -Command compare-orgs -SourceOrg "DEV" -DestOrg "PROD" -ProjectPath "C:\MyProject"

.EXAMPLE
    .\sfdc-toolkit-simple.ps1 -Command deploy -DestOrg "PROD" -ApiVersion "60.0"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("check-prereqs", "auth-org", "list-orgs", "compare-orgs", "deploy", "generate-manifest", "open-org", "help", "version")]
    [string]$Command,
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$SourceOrg = "",
    
    [Parameter(Mandatory = $false)]
    [string]$DestOrg = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ApiVersion = "61.0",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("INFO", "DEBUG", "WARN", "ERROR")]
    [string]$LogLevel = "INFO"
)

# Global Variables
$Script:VERSION = "14.2.0"
$Script:TOOLKIT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:TOOLKIT_CONFIG_DIR = Join-Path -Path $Script:TOOLKIT_ROOT -ChildPath ".sfdc-toolkit"
$Script:LOG_FILE = Join-Path -Path $Script:TOOLKIT_CONFIG_DIR -ChildPath "toolkit.log"
$Script:ProjectRoot = if ($ProjectPath) { $ProjectPath } else { Get-Location }
$Script:SourceOrgAlias = $SourceOrg
$Script:DestinationOrgAlias = $DestOrg
$Script:ApiVersion = $ApiVersion
$Script:LogLevel = $LogLevel

# Create config directory if it doesn't exist
if (-not (Test-Path $Script:TOOLKIT_CONFIG_DIR)) {
    New-Item -ItemType Directory -Path $Script:TOOLKIT_CONFIG_DIR -Force | Out-Null
}

# Initialize logging
if (-not (Test-Path $Script:LOG_FILE)) {
    Write-Log "Log file initialized" "INFO"
}

#region Logging Functions
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("INFO", "WARN", "ERROR", "DEBUG")][string]$Level = "INFO"
    )

    # Respect the log level setting
    if ($Script:LogLevel -eq "INFO" -and $Level -eq "DEBUG") { return }
    if ($Script:LogLevel -eq "WARN" -and $Level -in @("DEBUG")) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -Path $Script:LOG_FILE -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }

    # Output to console based on level
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "DEBUG" { Write-Host $logEntry -ForegroundColor Cyan }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}
#endregion

#region Core Functions
function Test-Prerequisites {
    Write-Log "Starting prerequisite check" "INFO"
    
    $allGood = $true
    
    # Check Salesforce CLI
    $sfCommand = Get-Command sf -ErrorAction SilentlyContinue
    if ($sfCommand) {
        Write-Host "  [*] Salesforce CLI... [INSTALLED]" -ForegroundColor Green
        Write-Log "Salesforce CLI found" "INFO"
    } else {
        Write-Host "  [*] Salesforce CLI... [MISSING]" -ForegroundColor Red
        Write-Log "Salesforce CLI not found" "ERROR"
        $allGood = $false
    }
    
    # Check Git
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) {
        Write-Host "  [*] Git... [INSTALLED]" -ForegroundColor Green
        Write-Log "Git found" "INFO"
    } else {
        Write-Host "  [*] Git... [MISSING]" -ForegroundColor Yellow
        Write-Log "Git not found" "WARN"
    }
    
    # Check VS Code
    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCommand) {
        Write-Host "  [*] Visual Studio Code... [INSTALLED]" -ForegroundColor Green
        Write-Log "VS Code found" "INFO"
    } else {
        Write-Host "  [*] Visual Studio Code... [MISSING]" -ForegroundColor Yellow
        Write-Log "VS Code not found" "WARN"
    }
    
    if (-not $allGood) {
        Write-Log "Prerequisites check failed" "ERROR"
        Write-Host "ERROR: Required tools are missing." -ForegroundColor Red
        exit 1
    } else {
        Write-Log "Prerequisites check passed" "INFO"
        Write-Host "Prerequisites check completed successfully." -ForegroundColor Green
    }
}

function Invoke-OrgAuthorization {
    Write-Log "Starting org authorization" "INFO"
    
    if (-not $Script:SourceOrgAlias) {
        $alias = Read-Host "Enter org alias"
        if ([string]::IsNullOrWhiteSpace($alias)) {
            Write-Log "Auth cancelled - no alias provided" "WARN"
            return
        }
    } else {
        $alias = $Script:SourceOrgAlias
    }
    
    $isProd = Read-Host "Is this a Production org? (y/n)"
    $instanceUrl = if ($isProd.ToLower() -eq 'y') { "https://login.salesforce.com" } else { "https://test.salesforce.com" }
    
    Write-Log "Authorizing org: $alias" "INFO"
    Write-Host "Authorizing org: $alias"
    
    try {
        sf org login web --alias $alias --instance-url $instanceUrl --set-default
        if ($LASTEXITCODE -ne 0) {
            throw "Salesforce CLI reported an error during login"
        }
        Write-Log "Successfully authorized org: $alias" "INFO"
        Write-Host "Org authorized successfully: $alias" -ForegroundColor Green
    } catch {
        Write-Log "Failed to authorize org: $($_.Exception.Message)" "ERROR"
        Write-Host "Failed to authorize org." -ForegroundColor Red
        exit 1
    }
}

function Get-OrgList {
    Write-Log "Listing authorized orgs" "INFO"
    
    Write-Host "Fetching authorized orgs..."
    
    try {
        $orgsJson = sf org list --json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "Salesforce CLI failed to list orgs"
        }
        
        Write-Host ""
        Write-Host "Authorized Orgs:" -ForegroundColor Cyan
        Write-Host "===============" -ForegroundColor Cyan
        
        $allOrgs = @($orgsJson.result.nonScratchOrgs) + @($orgsJson.result.scratchOrgs)
        foreach ($org in $allOrgs) {
            Write-Host "  Alias: $($org.alias) | User: $($org.username) | Status: $($org.status)" -ForegroundColor White
        }
        
        Write-Log "Org list displayed" "INFO"
    } catch {
        Write-Log "Failed to list orgs: $($_.Exception.Message)" "ERROR"
        Write-Host "Failed to list orgs." -ForegroundColor Red
        exit 1
    }
}

function Compare-Orgs {
    Write-Log "Starting org comparison" "INFO"
    
    if (-not $Script:SourceOrgAlias) {
        Write-Log "No source org specified" "ERROR"
        Write-Host "ERROR: Source org not specified. Use -SourceOrg parameter." -ForegroundColor Red
        exit 1
    }
    
    if (-not $Script:DestinationOrgAlias) {
        Write-Log "No destination org specified" "ERROR"
        Write-Host "ERROR: Destination org not specified. Use -DestOrg parameter." -ForegroundColor Red
        exit 1
    }
    
    Write-Log "Comparing orgs: $($Script:SourceOrgAlias) vs $($Script:DestinationOrgAlias)" "INFO"
    Write-Host "Comparing orgs: $($Script:SourceOrgAlias) vs $($Script:DestinationOrgAlias)"
    
    # Create project directories
    $sourceDir = Join-Path $Script:ProjectRoot "_source_metadata"
    $destDir = Join-Path $Script:ProjectRoot "_target_metadata"
    $deltaDir = Join-Path $Script:ProjectRoot "delta-deployment"
    
    if (-not (Test-Path $sourceDir)) { New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null }
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    if (Test-Path $deltaDir) { Remove-Item -Path $deltaDir -Recurse -Force }
    New-Item -ItemType Directory -Path $deltaDir -Force | Out-Null
    
    try {
        Write-Host ""
        Write-Host "Step 1: Generating manifests..."
        
        # Generate source manifest
        sf project generate manifest --from-org $Script:SourceOrgAlias --output-dir $Script:ProjectRoot --name "source_manifest" --api-version $Script:ApiVersion
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate source manifest"
        }
        
        # Generate target manifest
        sf project generate manifest --from-org $Script:DestinationOrgAlias --output-dir $Script:ProjectRoot --name "target_manifest" --api-version $Script:ApiVersion
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate target manifest"
        }
        
        Write-Host "Step 2: Retrieving metadata from source org..."
        sf project retrieve start --manifest (Join-Path $Script:ProjectRoot "source_manifest.xml") --target-org $Script:SourceOrgAlias --output-dir $sourceDir --api-version $Script:ApiVersion
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve from source org"
        }
        
        Write-Host "Step 3: Retrieving metadata from destination org..."
        sf project retrieve start --manifest (Join-Path $Script:ProjectRoot "target_manifest.xml") --target-org $Script:DestinationOrgAlias --output-dir $destDir --api-version $Script:ApiVersion
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve from destination org"
        }
        
        Write-Host "Step 4: Generating delta package..."
        
        # Create basic package.xml for delta
        $packageXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <version>$($Script:ApiVersion)</version>
</Package>
"@
        $packageXml | Out-File -FilePath (Join-Path $deltaDir "package.xml") -Encoding UTF8
        
        # Clean up temporary manifests
        Remove-Item (Join-Path $Script:ProjectRoot "source_manifest.xml") -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $Script:ProjectRoot "target_manifest.xml") -ErrorAction SilentlyContinue
        
        Write-Log "Org comparison completed successfully" "INFO"
        Write-Host ""
        Write-Host "Comparison completed successfully!" -ForegroundColor Green
        Write-Host "Source metadata: $sourceDir"
        Write-Host "Target metadata: $destDir"
        Write-Host "Delta package: $deltaDir"
        
    } catch {
        Write-Log "Org comparison failed: $($_.Exception.Message)" "ERROR"
        Write-Host "Comparison failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Deploy-Metadata {
    Write-Log "Starting metadata deployment" "INFO"
    
    if (-not $Script:DestinationOrgAlias) {
        Write-Log "No destination org specified" "ERROR"
        Write-Host "ERROR: Destination org not specified. Use -DestOrg parameter." -ForegroundColor Red
        exit 1
    }
    
    $deltaDir = Join-Path $Script:ProjectRoot "delta-deployment"
    if (-not (Test-Path $deltaDir)) {
        Write-Log "No delta package found" "ERROR"
        Write-Host "ERROR: No delta package found. Run compare-orgs first." -ForegroundColor Red
        exit 1
    }
    
    Write-Log "Deploying to org: $($Script:DestinationOrgAlias)" "INFO"
    Write-Host "Deploying metadata to: $($Script:DestinationOrgAlias)"
    
    try {
        sf project deploy start --metadata-dir $deltaDir --target-org $Script:DestinationOrgAlias --api-version $Script:ApiVersion --test-level RunLocalTests
        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed"
        }
        Write-Log "Deployment completed successfully" "INFO"
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
    } catch {
        Write-Log "Deployment failed: $($_.Exception.Message)" "ERROR"
        Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Generate-Manifest {
    Write-Log "Generating manifest" "INFO"
    
    if (-not $Script:SourceOrgAlias) {
        Write-Log "No source org specified" "ERROR"
        Write-Host "ERROR: Source org not specified. Use -SourceOrg parameter." -ForegroundColor Red
        exit 1
    }
    
    Write-Log "Generating manifest from org: $($Script:SourceOrgAlias)" "INFO"
    Write-Host "Generating manifest from org: $($Script:SourceOrgAlias)"
    
    try {
        sf project generate manifest --from-org $Script:SourceOrgAlias --output-dir $Script:ProjectRoot --name "package" --api-version $Script:ApiVersion
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate manifest"
        }
        Write-Log "Manifest generated successfully" "INFO"
        Write-Host "Manifest generated successfully: $(Join-Path $Script:ProjectRoot 'package.xml')" -ForegroundColor Green
    } catch {
        Write-Log "Failed to generate manifest: $($_.Exception.Message)" "ERROR"
        Write-Host "Failed to generate manifest: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Open-Org {
    Write-Log "Opening org in browser" "INFO"
    
    if (-not $Script:SourceOrgAlias) {
        Write-Log "No source org specified" "ERROR"
        Write-Host "ERROR: Source org not specified. Use -SourceOrg parameter." -ForegroundColor Red
        exit 1
    }
    
    Write-Log "Opening org: $($Script:SourceOrgAlias)" "INFO"
    Write-Host "Opening org in browser: $($Script:SourceOrgAlias)"
    
    try {
        sf org open --target-org $Script:SourceOrgAlias
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to open org"
        }
        Write-Log "Org opened successfully" "INFO"
        Write-Host "Org opened successfully." -ForegroundColor Green
    } catch {
        Write-Log "Failed to open org: $($_.Exception.Message)" "ERROR"
        Write-Host "Failed to open org: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "SFDC DevOps Toolkit - Simple CLI" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\sfdc-toolkit-simple.ps1 [OPTIONS] COMMAND"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  check-prereqs     Check system prerequisites"
    Write-Host "  auth-org          Authorize a new Salesforce org"
    Write-Host "  list-orgs         List all authorized orgs"
    Write-Host "  compare-orgs      Compare two orgs and generate delta"
    Write-Host "  deploy            Deploy metadata to target org"
    Write-Host "  generate-manifest Generate package.xml manifest"
    Write-Host "  open-org          Open org in browser"
    Write-Host "  help              Show this help message"
    Write-Host "  version           Show version information"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -ProjectPath PATH        Set project path"
    Write-Host "  -SourceOrg ALIAS         Set source org alias"
    Write-Host "  -DestOrg ALIAS           Set destination org alias"
    Write-Host "  -ApiVersion VERSION      Set API version (default: 61.0)"
    Write-Host "  -LogLevel LEVEL          Set log level (INFO, DEBUG, WARN, ERROR)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\sfdc-toolkit-simple.ps1 check-prereqs"
    Write-Host "  .\sfdc-toolkit-simple.ps1 -Command compare-orgs -SourceOrg 'DEV' -DestOrg 'PROD' -ProjectPath 'C:\MyProject'"
    Write-Host "  .\sfdc-toolkit-simple.ps1 -Command deploy -DestOrg 'PROD' -ApiVersion '60.0'"
    Write-Host ""
}

function Show-Version {
    Write-Host ""
    Write-Host "SFDC DevOps Toolkit - Simple CLI" -ForegroundColor Cyan
    Write-Host "Version: $($Script:VERSION)" -ForegroundColor Green
    Write-Host "Author: Amit Bhardwaj" -ForegroundColor Gray
    Write-Host ""
}
#endregion

#region Main Execution
try {
    Write-Log "SFDC DevOps Toolkit Simple CLI started" "INFO"
    Write-Log "Command: $Command" "INFO"
    Write-Log "Project Path: $($Script:ProjectRoot)" "INFO"
    Write-Log "Source Org: $($Script:SourceOrgAlias)" "INFO"
    Write-Log "Destination Org: $($Script:DestinationOrgAlias)" "INFO"
    Write-Log "API Version: $($Script:ApiVersion)" "INFO"
    
    switch ($Command.ToLower()) {
        "check-prereqs" { Test-Prerequisites }
        "auth-org" { Invoke-OrgAuthorization }
        "list-orgs" { Get-OrgList }
        "compare-orgs" { Compare-Orgs }
        "deploy" { Deploy-Metadata }
        "generate-manifest" { Generate-Manifest }
        "open-org" { Open-Org }
        "help" { Show-Help }
        "version" { Show-Version }
        default {
            Write-Host "Unknown command: $Command" -ForegroundColor Red
            Write-Host "Use 'help' to see available commands." -ForegroundColor Yellow
            exit 1
        }
    }
    
    Write-Log "Command completed successfully" "INFO"
} catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
#endregion
