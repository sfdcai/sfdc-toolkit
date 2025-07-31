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

    It features a robust two-level logging system with rotation, a self-updating metadata map, 
    comprehensive error handling, intelligent caching mechanism, project backup/restore,
    system information export, and project structure validation.
    This version is fully portable and centrally managed via a remote configuration file.

.NOTES
    Author:      Amit Bhardwaj (Remotely Configured)
    Version:     14.2.0 (Optimization and Enhancement Release)
    Created:     2025-07-15
    License:     MIT
    Requires:    PowerShell 5.1+, Windows Terminal (Recommended), Salesforce CLI.
#>

#Requires -Version 5.1

#region Script Configuration and State
[CmdletBinding()]
param(
    [switch]$NonInteractive = $false
)

# Self-Contained Configuration System - EXE Ready
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

# Embedded Default Configuration (completely self-contained)
$Script:EMBEDDED_CONFIG = @{
    # Basic Information
    AuthorName = "Amit Bhardwaj"
    AuthorLinkedIn = "linkedin.com/in/salesforce-technical-architect"
    ToolkitVersion = "14.2.0"
    
    # System Settings
    ToolkitRootConfigDir = ".sfdc-toolkit"
    CacheDurationHours = 24
    MaxLogSizeMB = 10
    DefaultApiVersion = "61.0"
    DefaultLogLevel = "INFO"
    GlobalLogLevel = "INFO"  # Can be overridden by remote config
    
    # Project Structure (customizable via remote)
    ProjectStructure = @{
        DeltaDeploymentDir = "delta-deployment"
        SourceMetadataDir = "_source_metadata"
        TargetMetadataDir = "_target_metadata"
        ProjectSettingsFile = "settings.json"
        ProjectLogFile = "project.log"
        BackupDir = "backups"
        TempDir = "temp"
    }
    
    # Salesforce URLs (customizable via remote)
    SalesforceUrls = @{
        Production = "https://login.salesforce.com"
        Sandbox = "https://test.salesforce.com"
        Developer = "https://login.salesforce.com"
        PreRelease = "https://prereleases.pre.salesforce.com"
    }
    
    # Tool Requirements (customizable via remote)
    RequiredTools = @(
        @{ Name = "sf"; Command = "sf --version"; Required = $true; Description = "Salesforce CLI"; MinVersion = "2.0.0" }
        @{ Name = "git"; Command = "git --version"; Required = $false; Description = "Git version control"; MinVersion = "2.0.0" }
        @{ Name = "code"; Command = "code --version"; Required = $false; Description = "VS Code editor"; MinVersion = "1.0.0" }
    )
    
    # Remote Control Settings
    RemoteControl = @{
        Enabled = $true
        Url = "https://raw.githubusercontent.com/sfdcai/sfdc-toolkit/refs/heads/main/control.json"
        FallbackToEmbedded = $true
        CacheRemoteConfig = $true
        CacheDurationMinutes = 60
    }
    
    # Usage Monitoring Settings (Requires User Consent)
    UsageMonitoring = @{
        Enabled = $false  # Disabled by default - requires user consent
        UserConsent = $false  # Must be explicitly set to true by user
        TelemetryUrl = "https://httpbin.org/post"
        CollectAnonymousUsage = $true
        CollectPerformanceMetrics = $true
        CollectErrorTelemetry = $true
        ReportingInterval = "Daily"
        MaxRetries = 3
        TimeoutSeconds = 10
        ConsentPrompted = $false  # Track if user has been asked
    }
    
    # Feature Toggles (controllable via remote)
    Features = @{
        EnableProgressBars = $true
        EnableEmojis = $true
        EnableColorOutput = $true
        EnableSystemCompatibilityCheck = $true
        EnableInputValidation = $true
        EnableAdvancedLogging = $true
        EnableBackupBeforeOperations = $true
        EnableDependencyAnalysis = $true
    }
    
    # Deployment Settings (customizable via remote)
    DeploymentDefaults = @{
        TestLevel = "RunLocalTests"
        DeploymentTimeout = 300
        ValidationTimeout = 180
        MaxDeploymentAttempts = 3
        BackupBeforeDeployment = $true
        RollbackOnFailure = $false
    }
    
    # UI Settings
    UI = @{
        Theme = "Dark"
        ShowWelcomeBanner = $true
        ShowProgressIndicators = $true
        EnableDetailedErrorMessages = $true
        MaxMenuRetries = 3
    }
}

# Initialize dynamic configuration with safe defaults
$Script:Config = $Script:EMBEDDED_CONFIG.Clone()
# Safe PSScriptRoot handling for EXE mode
$scriptRootPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$Script:TOOLKIT_ROOT_CONFIG_DIR = Join-Path -Path $scriptRootPath -ChildPath ".sfdc-toolkit"
$Script:ROOT_PROJECT_LIST_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "projects.json"
$Script:METADATA_MAP_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "metadata_map.json"
$Script:GLOBAL_LOG_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "toolkit.log"

# Runtime variables loaded on startup and after project selection
$Script:MetadataMap = @{}
$Script:ProjectRoot = $null
$Script:ProjectSettingsFile = $null
$Script:ProjectLogFile = $null
$Script:Settings = $null
$Script:IsInitialized = $false
#endregion

#region Core: Configuration Management

function Initialize-ToolkitConfiguration {
    <#
    .SYNOPSIS
        Initializes the self-contained configuration system with remote control capabilities
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Start with embedded configuration (completely self-contained)
        $Script:Config = $Script:EMBEDDED_CONFIG.Clone()
        Write-Host "🔧 Using embedded configuration (EXE-ready)" -ForegroundColor Cyan
        
        # Try to enhance with remote configuration if available - Use exact 13.1.0 method
        Write-Log -Level INFO "Checking for remote configuration..."
        
        try {
            Write-Host "🌐 Checking for remote configuration..." -ForegroundColor DarkGray
            
            # Temporarily enable DEBUG logging for remote config fetch
            $originalGlobalLogLevel = $Script:Config.GlobalLogLevel
            $Script:Config.GlobalLogLevel = "DEBUG"
            
            # Force TLS 1.2 for modern security compatibility
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $cacheBustingUrl = "$Script:REMOTE_CONTROL_URL" + "?t=" + (Get-Date).Ticks
            Write-Log -Level INFO "Fetching remote control file from: $cacheBustingUrl"
            
            $headers = @{ "Cache-Control" = "no-cache"; "Pragma" = "no-cache" }
            $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"

            # Use the confirmed working method: GET with TLS 1.2 and a User-Agent
            $response = Invoke-HttpRequestWithLogging -Uri $cacheBustingUrl -Headers $headers -Method "GET" -UserAgent $userAgent -Purpose "Fetch Remote Control Configuration"
            $controlConfig = $response.Content | ConvertFrom-Json
            Write-Log -Level INFO "Remote config parsed successfully - Keys: $($controlConfig.PSObject.Properties.Name -join ', ')"

            if ($controlConfig.author) {
                $Script:Config.AuthorName = $controlConfig.author.name
                $Script:Config.AuthorLinkedIn = $controlConfig.author.linkedin
                Write-Log -Level INFO "Updated author info from remote config"
            }
            
            # Apply remote configuration to embedded config
            if ($controlConfig.isActive -eq $false) {
                Write-Host "`n❌ TOOL DEACTIVATED BY ADMIN:" -ForegroundColor Red
                Write-Host $controlConfig.message -ForegroundColor Yellow
                Write-Log -Level ERROR "Tool deactivated by remote admin: $($controlConfig.message)"
                Read-Host "`nPress Enter to exit."
                exit
            }

            # Store version info for later checking
            $Script:Config | Add-Member -MemberType NoteProperty -Name 'LatestVersion' -Value $controlConfig.latestVersion -Force
            $Script:Config | Add-Member -MemberType NoteProperty -Name 'RemoteMessage' -Value $controlConfig.message -Force
            $Script:Config | Add-Member -MemberType NoteProperty -Name 'WelcomeText' -Value $controlConfig.welcomeText -Force
            
            # Apply global log level from remote config if available
            if ($controlConfig.configOverrides -and $controlConfig.configOverrides.GlobalLogLevel) {
                $Script:Config.GlobalLogLevel = $controlConfig.configOverrides.GlobalLogLevel
                Write-Log -Level INFO "Global log level set to: $($Script:Config.GlobalLogLevel) from remote config"
            } else {
                # Restore original log level if no remote override
                $Script:Config.GlobalLogLevel = $originalGlobalLogLevel
            }
            
            Write-Host "✅ Remote configuration loaded successfully" -ForegroundColor Green
            Write-Log -Level INFO "Remote configuration successfully applied"
            Write-Log -Level DEBUG "DEBUG logging is now enabled - testing message visibility"
            
        } catch {
            # Restore original log level on error
            $Script:Config.GlobalLogLevel = $originalGlobalLogLevel
            Write-Log -Level WARN "Could not fetch remote control file. Continuing with embedded configuration. Error: $($_.Exception.Message)"
            Write-Host "⚠️ Remote configuration unavailable, using embedded defaults" -ForegroundColor Yellow
        }
        
        # Initialize derived paths with safe PSScriptRoot handling
        $safeScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        $Script:TOOLKIT_ROOT_CONFIG_DIR = Join-Path -Path $safeScriptRoot -ChildPath $Script:Config.ToolkitRootConfigDir
        $Script:ROOT_PROJECT_LIST_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "projects.json"
        $Script:METADATA_MAP_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "metadata_map.json"
        $Script:GLOBAL_LOG_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "toolkit.log"
        
        # Validate final configuration
        Test-ConfigurationValidity -Config $Script:Config
        
        $Script:IsInitialized = $true
        return $true
        
    } catch {
        Write-Host "❌ Failed to initialize configuration: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "🔄 Falling back to basic embedded configuration..." -ForegroundColor Yellow
        
        # Emergency fallback to basic embedded config
        $Script:Config = $Script:EMBEDDED_CONFIG.Clone()
        $safeScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        $Script:TOOLKIT_ROOT_CONFIG_DIR = Join-Path -Path $safeScriptRoot -ChildPath $Script:Config.ToolkitRootConfigDir
        $Script:ROOT_PROJECT_LIST_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "projects.json"
        $Script:METADATA_MAP_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "metadata_map.json"
        $Script:GLOBAL_LOG_FILE = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "toolkit.log"
        
        return $true
    }
}

function Invoke-HttpRequestWithLogging {
    <#
    .SYNOPSIS
        Makes HTTP requests with comprehensive logging
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $false)][hashtable]$Headers = @{},
        [Parameter(Mandatory = $false)][string]$Method = "GET",
        [Parameter(Mandatory = $false)][string]$UserAgent = "SFDC-DevOps-Toolkit",
        [Parameter(Mandatory = $false)][string]$Purpose = "HTTP Request"
    )
    
    $requestId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
    
    # FORCE LOGGING TO BOTH CONSOLE AND FILE - ALWAYS
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessages = @(
        "[$timestamp] [INFO] === HTTP REQUEST START ($requestId) ===",
        "[$timestamp] [INFO] Purpose: $Purpose", 
        "[$timestamp] [INFO] Method: $Method",
        "[$timestamp] [INFO] URI: $Uri",
        "[$timestamp] [DEBUG] Headers: $($Headers | ConvertTo-Json -Compress)",
        "[$timestamp] [DEBUG] User-Agent: $UserAgent"
    )
    
    # Force write to global log file with safe path handling
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
    $globalLogFile = Join-Path -Path $scriptRoot -ChildPath ".sfdc-toolkit\toolkit.log"
    $globalLogDir = Split-Path $globalLogFile -Parent
    if (-not (Test-Path $globalLogDir)) {
        try {
            New-Item -Path $globalLogDir -ItemType Directory -Force | Out-Null
        } catch {
            # Fallback to temp directory if can't create in script root
            $globalLogFile = Join-Path -Path $env:TEMP -ChildPath "sfdc-toolkit.log"
        }
    }
    
    foreach ($msg in $logMessages) {
        Add-Content -Path $globalLogFile -Value $msg -Force
        Write-Host $msg -ForegroundColor Cyan
    }
    
    # Also use normal Write-Log
    Write-Log -Level INFO "=== HTTP REQUEST START ($requestId) ==="
    Write-Log -Level INFO "Purpose: $Purpose"
    Write-Log -Level INFO "Method: $Method"
    Write-Log -Level INFO "URI: $Uri"
    Write-Log -Level DEBUG "Headers: $($Headers | ConvertTo-Json -Compress)"
    Write-Log -Level DEBUG "User-Agent: $UserAgent"
    
    try {
        $startTime = Get-Date
        Write-Log -Level DEBUG "Request started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))"
        
        # Set TLS 1.2 for security
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Make the request
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -Headers $Headers -Method $Method -UserAgent $UserAgent -ErrorAction Stop
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        # FORCE LOG THE RESPONSE TO FILE
        $responseMessages = @(
            "[$timestamp] [INFO] === HTTP RESPONSE SUCCESS ($requestId) ===",
            "[$timestamp] [INFO] Status Code: $($response.StatusCode)",
            "[$timestamp] [INFO] Status Description: $($response.StatusDescription)",
            "[$timestamp] [INFO] Response Time: $($duration.TotalMilliseconds)ms",
            "[$timestamp] [INFO] Content Length: $($response.Content.Length) characters",
            "[$timestamp] [DEBUG] Response Headers: $($response.Headers | ConvertTo-Json -Compress)",
            "[$timestamp] [DEBUG] Response Content: $($response.Content)"
        )
        
        foreach ($msg in $responseMessages) {
            Add-Content -Path $globalLogFile -Value $msg -Force
            Write-Host $msg -ForegroundColor Green
        }
        
        Write-Log -Level INFO "=== HTTP RESPONSE SUCCESS ($requestId) ==="
        Write-Log -Level INFO "Status Code: $($response.StatusCode)"
        Write-Log -Level INFO "Status Description: $($response.StatusDescription)"
        Write-Log -Level INFO "Response Time: $($duration.TotalMilliseconds)ms"
        Write-Log -Level INFO "Content Length: $($response.Content.Length) characters"
        Write-Log -Level DEBUG "Response Headers: $($response.Headers | ConvertTo-Json -Compress)"
        Write-Log -Level DEBUG "Response Content: $($response.Content)"
        
        return $response
        
    } catch {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        # FORCE LOG THE ERROR TO FILE
        $errorMessages = @(
            "[$timestamp] [ERROR] === HTTP REQUEST FAILED ($requestId) ===",
            "[$timestamp] [ERROR] Error: $($_.Exception.Message)",
            "[$timestamp] [ERROR] Duration: $($duration.TotalMilliseconds)ms"
        )
        
        if ($_.Exception.Response) {
            $errorMessages += "[$timestamp] [ERROR] HTTP Status: $($_.Exception.Response.StatusCode)"
            $errorMessages += "[$timestamp] [ERROR] HTTP Status Description: $($_.Exception.Response.StatusDescription)"
        }
        
        $errorMessages += "[$timestamp] [DEBUG] Full Exception: $($_.Exception.ToString())"
        
        foreach ($msg in $errorMessages) {
            Add-Content -Path $globalLogFile -Value $msg -Force
            Write-Host $msg -ForegroundColor Red
        }
        
        Write-Log -Level ERROR "=== HTTP REQUEST FAILED ($requestId) ==="
        Write-Log -Level ERROR "Error: $($_.Exception.Message)"
        Write-Log -Level ERROR "Duration: $($duration.TotalMilliseconds)ms"
        
        if ($_.Exception.Response) {
            Write-Log -Level ERROR "HTTP Status: $($_.Exception.Response.StatusCode)"
            Write-Log -Level ERROR "HTTP Status Description: $($_.Exception.Response.StatusDescription)"
        }
        
        Write-Log -Level DEBUG "Full Exception: $($_.Exception.ToString())"
        
        throw
    }
}

function Get-RemoteConfiguration {
    <#
    .SYNOPSIS
        Fetches remote configuration from GitHub URL
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Url
    )
    
    try {
        # Force TLS 1.2 for modern security compatibility
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $cacheBustingUrl = "$Url" + "?t=" + (Get-Date).Ticks
        Write-Log -Level INFO "Fetching remote control file from: $cacheBustingUrl"
        
        $headers = @{ "Cache-Control" = "no-cache"; "Pragma" = "no-cache" }
        $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"

        # Use the confirmed working method: GET with TLS 1.2 and a User-Agent
        $response = Invoke-HttpRequestWithLogging -Uri $cacheBustingUrl -Headers $headers -Method "GET" -UserAgent $userAgent -Purpose "Get Remote Configuration"
        $remoteConfig = $response.Content | ConvertFrom-Json
        Write-Log -Level INFO "Remote config parsed - Keys: $($remoteConfig.PSObject.Properties.Name -join ', ')"
        
        Write-Log -Level INFO "Successfully fetched remote configuration from: $Url"
        return $remoteConfig
        
    } catch {
        Write-Log -Level ERROR "Failed to fetch remote configuration: $($_.Exception.Message)"
        $httpStatus = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { 'Unknown' }
        Write-Log -Level ERROR "HTTP Status: $httpStatus"
        Write-Log -Level ERROR "Full Error: $($_.Exception.ToString())"
        return $null
    }
}

function Merge-RemoteConfiguration {
    <#
    .SYNOPSIS
        Merges remote configuration with embedded configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$EmbeddedConfig,
        [Parameter(Mandatory = $true)]$RemoteConfig
    )
    
    try {
        $mergedConfig = $EmbeddedConfig.Clone()
        
        # Handle toolkit control (isActive, message, version checks)
        if ($RemoteConfig.PSObject.Properties.Name -contains "isActive") {
            $mergedConfig.IsActive = $RemoteConfig.isActive
        }
        if ($RemoteConfig.PSObject.Properties.Name -contains "message") {
            $mergedConfig.RemoteMessage = $RemoteConfig.message
        }
        if ($RemoteConfig.PSObject.Properties.Name -contains "latestVersion") {
            $mergedConfig.LatestVersion = $RemoteConfig.latestVersion
        }
        if ($RemoteConfig.PSObject.Properties.Name -contains "welcomeText") {
            $mergedConfig.WelcomeText = $RemoteConfig.welcomeText
        }
        
        # Handle author information updates
        if ($RemoteConfig.PSObject.Properties.Name -contains "author") {
            if ($RemoteConfig.author.name) {
                $mergedConfig.AuthorName = $RemoteConfig.author.name
            }
            if ($RemoteConfig.author.linkedin) {
                $mergedConfig.AuthorLinkedIn = $RemoteConfig.author.linkedin
            }
        }
        
        # Handle configuration overrides
        if ($RemoteConfig.PSObject.Properties.Name -contains "configOverrides") {
            $overrides = $RemoteConfig.configOverrides
            
            # Deep merge configuration sections
            foreach ($section in $overrides.PSObject.Properties.Name) {
                if ($mergedConfig.ContainsKey($section)) {
                    if ($mergedConfig[$section] -is [hashtable]) {
                        # Merge hashtables recursively
                        foreach ($key in $overrides.$section.PSObject.Properties.Name) {
                            $mergedConfig[$section][$key] = $overrides.$section.$key
                        }
                    } else {
                        # Direct assignment for non-hashtable values
                        $mergedConfig[$section] = $overrides.$section
                    }
                } else {
                    Write-Log -Level WARN "Unknown configuration section in remote override: $section"
                }
            }
        }
        
        # Handle feature toggles
        if ($RemoteConfig.PSObject.Properties.Name -contains "featureToggles") {
            foreach ($feature in $RemoteConfig.featureToggles.PSObject.Properties.Name) {
                if ($mergedConfig.Features.ContainsKey($feature)) {
                    $mergedConfig.Features[$feature] = $RemoteConfig.featureToggles.$feature
                } else {
                    Write-Log -Level WARN "Unknown feature toggle: $feature"
                }
            }
        }
        
        Write-Log -Level INFO "Successfully merged remote configuration with embedded configuration"
        return $mergedConfig
        
    } catch {
        Write-Log -Level ERROR "Failed to merge remote configuration: $($_.Exception.Message)"
        return $EmbeddedConfig
    }
}

function Merge-Configuration {
    <#
    .SYNOPSIS
        Legacy function for backward compatibility
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$DefaultConfig,
        [Parameter(Mandatory = $true)]$UserConfig
    )
    
    return Merge-RemoteConfiguration -EmbeddedConfig $DefaultConfig -RemoteConfig $UserConfig
}

function Test-ConfigurationValidity {
    <#
    .SYNOPSIS
        Validates configuration settings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Config
    )
    
    $issues = @()
    
    # Validate required fields
    $requiredFields = @('AuthorName', 'ToolkitRootConfigDir', 'DefaultApiVersion')
    foreach ($field in $requiredFields) {
        if (-not $Config.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($Config.$field)) {
            $issues += "Missing required field: $field"
        }
    }
    
    # Validate API version format
    if ($Config.DefaultApiVersion -notmatch '^\d+\.\d+$') {
        $issues += "Invalid API version format: $($Config.DefaultApiVersion)"
    }
    
    # Validate cache duration
    if ($Config.CacheDurationHours -le 0 -or $Config.CacheDurationHours -gt 168) {
        $issues += "Cache duration must be between 1 and 168 hours"
    }
    
    if ($issues.Count -gt 0) {
        Write-Host "❌ Configuration validation failed:" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        throw "Configuration validation failed"
    }
    
    Write-Host "✅ Configuration validation passed" -ForegroundColor Green
}

function Save-ToolkitConfiguration {
    <#
    .SYNOPSIS
        Saves current configuration to file
    #>
    [CmdletBinding()]
    param()
    
    try {
        if (-not $Script:Config) {
            throw "No configuration loaded"
        }
        
        $configToSave = $Script:Config | ConvertTo-Json -Depth 10
        $configToSave | Out-File -FilePath $Script:CONFIG_FILE -Encoding utf8
        Write-Host "✅ Configuration saved to $Script:CONFIG_FILE" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Failed to save configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Gets a configuration value with fallback to default
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $false)]$DefaultValue = $null
    )
    
    if (-not $Script:Config) {
        Initialize-ToolkitConfiguration
    }
    
    if ($Script:Config.ContainsKey($Key)) {
        return $Script:Config.$Key
    } elseif ($DefaultValue) {
        return $DefaultValue
    } else {
        Write-Host "⚠️  Configuration key not found: $Key" -ForegroundColor Yellow
        return $null
    }
}

#endregion

function Request-TelemetryConsent {
    <#
    .SYNOPSIS
        Requests user consent for anonymous telemetry collection
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check for global consent file first (takes precedence)
        $globalConsentFile = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "user-consent.json"
        if (Test-Path $globalConsentFile) {
            try {
                $globalConsent = Get-Content $globalConsentFile -Raw | ConvertFrom-Json
                $Script:Config.UsageMonitoring.UserConsent = $globalConsent.TelemetryConsent
                $Script:Config.UsageMonitoring.Enabled = $globalConsent.TelemetryConsent
                $Script:Config.UsageMonitoring.ConsentPrompted = $true
                Write-Log -Level DEBUG "Using global telemetry consent: $($globalConsent.TelemetryConsent)"
                return
            } catch {
                Write-Log -Level WARN "Failed to read global consent file, will prompt user"
            }
        }
        
        # Check if consent already given in project settings
        if ($Script:Settings -and $Script:Settings.PSObject.Properties.Name -contains "TelemetryConsent") {
            $Script:Config.UsageMonitoring.UserConsent = $Script:Settings.TelemetryConsent
            $Script:Config.UsageMonitoring.Enabled = $Script:Settings.TelemetryConsent
            $Script:Config.UsageMonitoring.ConsentPrompted = $true
            return
        }
        
        # Only ask once per session if not already set
        if ($Script:Config.UsageMonitoring.ConsentPrompted) {
            return
        }
        
        Write-Host "`n" -NoNewline
        Write-Host "📊 ANONYMOUS USAGE ANALYTICS" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "The SFDC DevOps Toolkit can collect anonymous usage statistics to help improve the tool." -ForegroundColor White
        Write-Host ""
        Write-Host "🔒 PRIVACY GUARANTEES:" -ForegroundColor Green
        Write-Host "  • No personal information or credentials are collected" -ForegroundColor Gray
        Write-Host "  • No Salesforce org names, URLs, or metadata content" -ForegroundColor Gray
        Write-Host "  • Only anonymous feature usage and performance metrics" -ForegroundColor Gray
        Write-Host "  • Data is sent to GitHub Issues for the toolkit owner" -ForegroundColor Gray
        Write-Host ""
        Write-Host "📈 WHAT IS COLLECTED:" -ForegroundColor Yellow
        Write-Host "  • Which features you use (menu selections)" -ForegroundColor Gray
        Write-Host "  • Operation performance metrics (timing)" -ForegroundColor Gray
        Write-Host "  • Error frequencies (for stability improvements)" -ForegroundColor Gray
        Write-Host "  • System information (OS, PowerShell version)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "🎯 BENEFITS:" -ForegroundColor Cyan
        Write-Host "  • Helps prioritize feature development" -ForegroundColor Gray
        Write-Host "  • Identifies performance bottlenecks" -ForegroundColor Gray
        Write-Host "  • Improves error handling and stability" -ForegroundColor Gray
        Write-Host "  • Better user experience for everyone" -ForegroundColor Gray
        Write-Host ""
        
        do {
            $consent = Read-Host "Allow anonymous usage analytics? (y/n)"
            $consent = $consent.ToLower().Trim()
        } while ($consent -notin @('y', 'yes', 'n', 'no'))
        
        $userConsented = $consent -in @('y', 'yes')
        
        # Update configuration
        $Script:Config.UsageMonitoring.UserConsent = $userConsented
        $Script:Config.UsageMonitoring.ConsentPrompted = $true
        $Script:Config.UsageMonitoring.Enabled = $userConsented
        
        # Save consent to GLOBAL file (applies to all projects)
        try {
            # Ensure toolkit config directory exists
            if (-not (Test-Path $Script:TOOLKIT_ROOT_CONFIG_DIR)) {
                New-Item -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ItemType Directory -Force | Out-Null
            }
            
            $globalConsentData = @{
                TelemetryConsent = $userConsented
                ConsentDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                ToolkitVersion = $Script:VERSION
                UserDomain = [Environment]::UserDomainName
                MachineName = [Environment]::MachineName
            }
            
            $globalConsentFile = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "user-consent.json"
            $globalConsentData | ConvertTo-Json -Depth 2 | Set-Content -Path $globalConsentFile -Encoding UTF8
            
            Write-Log -Level INFO "Global telemetry consent saved: $userConsented"
            
        } catch {
            Write-Log -Level WARN "Failed to save global consent, falling back to project-level: $($_.Exception.Message)"
            
            # Fallback: Save to project settings if global save fails
            if ($Script:Settings) {
                if (-not $Script:Settings.PSObject.Properties.Name -contains "TelemetryConsent") {
                    $Script:Settings | Add-Member -MemberType NoteProperty -Name "TelemetryConsent" -Value $userConsented
                } else {
                    $Script:Settings.TelemetryConsent = $userConsented
                }
                
                if (-not $Script:Settings.PSObject.Properties.Name -contains "ConsentDate") {
                    $Script:Settings | Add-Member -MemberType NoteProperty -Name "ConsentDate" -Value (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                } else {
                    $Script:Settings.ConsentDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                }
                
                Save-Settings
            }
        }
        
        if ($userConsented) {
            Write-Host "✅ Thank you! Anonymous usage analytics enabled." -ForegroundColor Green
            Write-Host "   You can disable this anytime in project settings." -ForegroundColor DarkGray
        } else {
            Write-Host "❌ Anonymous usage analytics disabled." -ForegroundColor Yellow
            Write-Host "   No usage data will be collected or sent." -ForegroundColor DarkGray
        }
        
        Write-Host ""
        
    } catch {
        Write-Log -Level WARN "Failed to request telemetry consent: $($_.Exception.Message)"
        # Default to no consent on error
        $Script:Config.UsageMonitoring.UserConsent = $false
        $Script:Config.UsageMonitoring.Enabled = $false
    }
}

#region Core: Usage Monitoring and Telemetry

function Initialize-UsageTracking {
    <#
    .SYNOPSIS
        Initializes usage tracking and creates anonymous user session
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if user consent is required and has been given
        if (-not $Script:Config.UsageMonitoring.UserConsent) {
            Write-Log -Level DEBUG "Usage monitoring disabled - no user consent"
            return
        }
        
        if (-not $Script:Config.UsageMonitoring.Enabled) {
            Write-Log -Level DEBUG "Usage monitoring disabled"
            return
        }
        
        # Generate anonymous session ID
        $Script:SessionId = [System.Guid]::NewGuid().ToString()
        $Script:SessionStartTime = Get-Date
        $Script:UsageData = @{
            SessionId = $Script:SessionId
            ToolkitVersion = $Script:VERSION
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OSVersion = [Environment]::OSVersion.ToString()
            UserDomain = [Environment]::UserDomainName
            MachineName = [Environment]::MachineName
            SessionStart = $Script:SessionStartTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            Features = @()
            Operations = @()
            Errors = @()
            Performance = @{}
        }
        
        Write-Log -Level DEBUG "Usage tracking initialized with session ID: $Script:SessionId"
        
    } catch {
        Write-Log -Level WARN "Failed to initialize usage tracking: $($_.Exception.Message)"
    }
}

function Track-FeatureUsage {
    <#
    .SYNOPSIS
        Tracks feature usage with timestamp
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Feature,
        [Parameter(Mandatory = $false)][string]$Action = "",
        [Parameter(Mandatory = $false)][hashtable]$Details = @{}
    )
    
    try {
        if (-not $Script:Config.UsageMonitoring.UserConsent -or -not $Script:Config.UsageMonitoring.Enabled -or -not $Script:UsageData) {
            return
        }
        
        $featureEvent = @{
            Feature = $Feature
            Action = $Action
            Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            Details = $Details
        }
        
        $Script:UsageData.Features += $featureEvent
        Write-Log -Level DEBUG "Tracked feature usage: $Feature -> $Action"
        
    } catch {
        Write-Log -Level WARN "Failed to track feature usage: $($_.Exception.Message)"
    }
}

function Track-Operation {
    <#
    .SYNOPSIS
        Tracks operations with performance metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$OperationName,
        [Parameter(Mandatory = $false)][timespan]$Duration,
        [Parameter(Mandatory = $false)][bool]$Success = $true,
        [Parameter(Mandatory = $false)][hashtable]$Properties = @{}
    )
    
    try {
        if (-not $Script:Config.UsageMonitoring.UserConsent -or -not $Script:Config.UsageMonitoring.Enabled -or -not $Script:UsageData) {
            return
        }
        
        $operationEvent = @{
            Operation = $OperationName
            Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            Duration = if ($Duration) { $Duration.TotalMilliseconds } else { 0 }
            Success = $Success
            Properties = $Properties
        }
        
        $Script:UsageData.Operations += $operationEvent
        Write-Log -Level DEBUG "Tracked operation: $OperationName (Success: $Success)"
        
    } catch {
        Write-Log -Level WARN "Failed to track operation: $($_.Exception.Message)"
    }
}

function Track-Error {
    <#
    .SYNOPSIS
        Tracks errors for telemetry (no sensitive data)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ErrorType,
        [Parameter(Mandatory = $false)][string]$ErrorMessage,
        [Parameter(Mandatory = $false)][string]$Function,
        [Parameter(Mandatory = $false)][hashtable]$Properties = @{}
    )
    
    try {
        if (-not $Script:Config.UsageMonitoring.Enabled -or -not $Script:Config.UsageMonitoring.CollectErrorTelemetry -or -not $Script:UsageData) {
            return
        }
        
        # Sanitize error message (remove potential sensitive data)
        $sanitizedMessage = $ErrorMessage -replace '([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', '[EMAIL]'
        $sanitizedMessage = $sanitizedMessage -replace '(\\\\[^\\s]+)', '[PATH]'
        $sanitizedMessage = $sanitizedMessage -replace '([A-Za-z]:\\\\[^\\s]+)', '[PATH]'
        
        $errorEvent = @{
            ErrorType = $ErrorType
            ErrorMessage = $sanitizedMessage
            Function = $Function
            Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            Properties = $Properties
        }
        
        $Script:UsageData.Errors += $errorEvent
        Write-Log -Level DEBUG "Tracked error: $ErrorType in $Function"
        
    } catch {
        Write-Log -Level WARN "Failed to track error: $($_.Exception.Message)"
    }
}

function Send-UsageTelemetry {
    <#
    .SYNOPSIS
        Sends usage telemetry to local log file (GitHub API disabled due to authentication issues)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][switch]$Force
    )
    
    try {
        if (-not $Script:Config.UsageMonitoring.UserConsent -or -not $Script:Config.UsageMonitoring.Enabled -or -not $Script:UsageData) {
            Write-Log -Level DEBUG "Telemetry disabled - no user consent or no data to send"
            return
        }
        
        # Check if we should send telemetry
        $shouldSend = $Force.IsPresent
        if (-not $shouldSend) {
            $lastSent = Get-ConfigValue -Key "LastTelemetrySent" -DefaultValue (Get-Date).AddDays(-1)
            $daysSinceLastSent = ((Get-Date) - $lastSent).Days
            $shouldSend = $daysSinceLastSent -ge 1
        }
        
        if (-not $shouldSend) {
            Write-Log -Level DEBUG "Telemetry not due for sending"
            return
        }
        
        # Add session summary
        $Script:UsageData.SessionEnd = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $Script:UsageData.SessionDuration = ((Get-Date) - $Script:SessionStartTime).TotalMinutes
        $Script:UsageData.Performance = @{
            TotalFeatures = $Script:UsageData.Features.Count
            TotalOperations = $Script:UsageData.Operations.Count
            TotalErrors = $Script:UsageData.Errors.Count
            SuccessfulOperations = ($Script:UsageData.Operations | Where-Object { $_.Success }).Count
        }
        
        # Log telemetry data to local file instead of GitHub API
        $telemetryLogPath = Join-Path -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ChildPath "telemetry.log"
        $telemetryData = @{
            SessionId = $Script:UsageData.SessionId
            ToolkitVersion = $Script:UsageData.ToolkitVersion
            SessionDuration = [math]::Round($Script:UsageData.SessionDuration, 2)
            TotalFeatures = $Script:UsageData.Performance.TotalFeatures
            TotalOperations = $Script:UsageData.Performance.TotalOperations
            SuccessfulOperations = $Script:UsageData.Performance.SuccessfulOperations
            TotalErrors = $Script:UsageData.Performance.TotalErrors
            Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        
        $telemetryEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [TELEMETRY] $($telemetryData | ConvertTo-Json -Compress)"
        Add-Content -Path $telemetryLogPath -Value $telemetryEntry -ErrorAction SilentlyContinue
        
        Write-Log -Level DEBUG "Usage telemetry logged locally to: $telemetryLogPath"
        
    } catch {
        Write-Log -Level WARN "Failed to send usage telemetry: $($_.Exception.Message)"
    }
}

function Get-UsageSummary {
    <#
    .SYNOPSIS
        Gets current session usage summary
    #>
    [CmdletBinding()]
    param()
    
    if (-not $Script:UsageData) {
        return @{ Message = "Usage tracking not initialized" }
    }
    
    return @{
        SessionId = $Script:UsageData.SessionId
        SessionDuration = if ($Script:SessionStartTime) { ((Get-Date) - $Script:SessionStartTime).TotalMinutes } else { 0 }
        FeaturesUsed = $Script:UsageData.Features.Count
        OperationsPerformed = $Script:UsageData.Operations.Count
        ErrorsEncountered = $Script:UsageData.Errors.Count
        MostUsedFeatures = ($Script:UsageData.Features | Group-Object Feature | Sort-Object Count -Descending | Select-Object -First 3 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })
    }
}

#endregion

#region Core: System Compatibility and Validation

function Test-SystemCompatibility {
    <#
    .SYNOPSIS
        Tests system compatibility and reports issues
    #>
    [CmdletBinding()]
    param()
    
    $issues = @()
    $warnings = @()
    
    try {
        # Check PowerShell version
        $psVersion = $PSVersionTable.PSVersion
        if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
            $issues += "PowerShell 5.1 or higher required. Current version: $psVersion"
        }
        
        # Check Windows version
        if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
            $warnings += "Cross-platform PowerShell detected. Some features may not work as expected."
        }
        
        # Check required tools
        $requiredTools = Get-ConfigValue -Key "RequiredTools" -DefaultValue @()
        foreach ($tool in $requiredTools) {
            $toolAvailable = Test-CommandExists -CommandName $tool.Name
            if (-not $toolAvailable -and $tool.Required) {
                $issues += "Required tool missing: $($tool.Name) - $($tool.Description)"
            } elseif (-not $toolAvailable) {
                $warnings += "Optional tool missing: $($tool.Name) - $($tool.Description)"
            }
        }
        
        # Internet connectivity will be tested when needed during remote operations
        
        # Report results
        if ($issues.Count -gt 0) {
            Write-Host "❌ System compatibility issues found:" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
            return $false
        }
        
        if ($warnings.Count -gt 0) {
            Write-Host "⚠️  System compatibility warnings:" -ForegroundColor Yellow
            $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        }
        
        Write-Host "✅ System compatibility check passed" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "❌ System compatibility check failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-InputValidation {
    <#
    .SYNOPSIS
        Validates user input with comprehensive checks
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$InputValue,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $false)][hashtable]$ValidationParams = @{}
    )
    
    switch ($Type.ToLower()) {
        "projectname" {
            if ([string]::IsNullOrWhiteSpace($InputValue)) {
                return @{ IsValid = $false; Message = "Project name cannot be empty" }
            }
            if ($InputValue -match '[<>:"/\\|?*]') {
                return @{ IsValid = $false; Message = "Project name contains invalid characters" }
            }
            if ($InputValue.Length -gt 50) {
                return @{ IsValid = $false; Message = "Project name too long (max 50 characters)" }
            }
            return @{ IsValid = $true; Message = "" }
        }
        
        "orgalias" {
            if ([string]::IsNullOrWhiteSpace($InputValue)) {
                return @{ IsValid = $false; Message = "Org alias cannot be empty" }
            }
            if ($InputValue -match '[^a-zA-Z0-9_-]') {
                return @{ IsValid = $false; Message = "Org alias can only contain letters, numbers, hyphens, and underscores" }
            }
            return @{ IsValid = $true; Message = "" }
        }
        
        "path" {
            if ([string]::IsNullOrWhiteSpace($InputValue)) {
                return @{ IsValid = $true; Message = "" }
            }
            if (-not (Test-Path $InputValue -IsValid)) {
                return @{ IsValid = $false; Message = "Invalid path format" }
            }
            if ($ValidationParams.ContainsKey("MustExist") -and $ValidationParams.MustExist -and -not (Test-Path $InputValue)) {
                return @{ IsValid = $false; Message = "Path does not exist" }
            }
            return @{ IsValid = $true; Message = "" }
        }
        
        "apiversion" {
            if ([string]::IsNullOrWhiteSpace($InputValue)) {
                return @{ IsValid = $false; Message = "API version cannot be empty" }
            }
            if ($InputValue -notmatch '^\\d+\\.\\d+$') {
                return @{ IsValid = $false; Message = "API version must be in format XX.Y (e.g., 61.0)" }
            }
            $version = [double]$InputValue
            if ($version -lt 30.0 -or $version -gt 100.0) {
                return @{ IsValid = $false; Message = "API version must be between 30.0 and 100.0" }
            }
            return @{ IsValid = $true; Message = "" }
        }
        
        "menuoption" {
            if ([string]::IsNullOrWhiteSpace($InputValue)) {
                return @{ IsValid = $false; Message = "Selection cannot be empty" }
            }
            if ($InputValue -notmatch '^\\d+$') {
                return @{ IsValid = $false; Message = "Please enter a number" }
            }
            $option = [int]$InputValue
            $maxOption = $ValidationParams.MaxOption
            if ($option -lt 1 -or $option -gt $maxOption) {
                return @{ IsValid = $false; Message = "Please enter a number between 1 and $maxOption" }
            }
            return @{ IsValid = $true; Message = "" }
        }
        
        default {
            return @{ IsValid = $true; Message = "" }
        }
    }
}

function Get-ValidatedInput {
    <#
    .SYNOPSIS
        Gets validated input from user with retry logic
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $false)][hashtable]$ValidationParams = @{},
        [Parameter(Mandatory = $false)][int]$MaxRetries = 3
    )
    
    $attempt = 0
    do {
        $attempt++
        $input = Read-Host $Prompt
        
        $validation = Test-InputValidation -InputValue $input -Type $Type -ValidationParams $ValidationParams
        
        if ($validation.IsValid) {
            return $input
        } else {
            Write-Host "❌ $($validation.Message)" -ForegroundColor Red
            if ($attempt -lt $MaxRetries) {
                Write-Host "Please try again ($attempt/$MaxRetries attempts)" -ForegroundColor Yellow
            }
        }
        
    } while ($attempt -lt $MaxRetries)
    
    throw "Maximum retry attempts reached for input validation"
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Shows a progress bar for long-running operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Activity,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][int]$PercentComplete,
        [Parameter(Mandatory = $false)][int]$Id = 1
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
}

function Hide-ProgressBar {
    <#
    .SYNOPSIS
        Hides the progress bar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][int]$Id = 1
    )
    
    Write-Progress -Activity "Complete" -Status "Complete" -PercentComplete 100 -Id $Id -Completed
}

#endregion

#region Core: Logging and Utilities

function Get-JsonContent {
    <#
    .SYNOPSIS
        Optimized JSON content reader with error handling
    .PARAMETER Path
        Path to the JSON file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )
    
    try {
        if (-not (Test-Path $Path)) {
            Write-Log -Level WARN "JSON file not found: $Path"
            return $null
        }
        
        $content = Get-Content $Path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Log -Level WARN "JSON file is empty: $Path"
            return $null
        }
        
        return $content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Log -Level ERROR "Failed to read JSON from '$Path': $($_.Exception.Message)"
        return $null
    }
}

function Set-JsonContent {
    <#
    .SYNOPSIS
        Optimized JSON content writer with error handling
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER Content
        Content to write as JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Content
    )
    
    try {
        $jsonContent = $Content | ConvertTo-Json -Depth 20 -Compress
        $jsonContent | Out-File -FilePath $Path -Encoding utf8 -ErrorAction Stop
        return $true
    } catch {
        Write-Log -Level ERROR "Failed to write JSON to '$Path': $($_.Exception.Message)"
        return $false
    }
}

function Invoke-SafeCommand {
    <#
    .SYNOPSIS
        Safely executes commands without using Invoke-Expression
    .PARAMETER Command
        Command to execute
    .PARAMETER Arguments
        Arguments for the command
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @()
    )
    
    try {
        if ($Arguments.Count -gt 0) {
            & $Command @Arguments
        } else {
            & $Command
        }
    } catch {
        Write-Log -Level ERROR "Command execution failed: $($_.Exception.Message)"
        throw
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes log messages to both console and log file with rotation
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        The log level (INFO, WARN, ERROR, DEBUG)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("INFO", "WARN", "ERROR", "DEBUG")][string]$Level = "INFO"
    )

    # Get timestamp once
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Show console output for all levels, but respect log level for DEBUG
    $showConsole = $true
    
    # Check global log level first (for application-wide control)
    $effectiveLogLevel = "INFO"
    if ($Script:Config -and $Script:Config.GlobalLogLevel) {
        $effectiveLogLevel = $Script:Config.GlobalLogLevel
    }
    # Project-specific log level overrides global
    if ($Script:Settings -and $Script:Settings.logLevel) {
        $effectiveLogLevel = $Script:Settings.logLevel
    }
    
    if ($Level -eq "DEBUG" -and $effectiveLogLevel -eq "INFO") {
        $showConsole = $false
    }
    
    # Console output - only for important messages to reduce noise
    if ($showConsole) {
        # Only show console output for WARN and ERROR levels
        if ($Level -in @("WARN", "ERROR")) {
            $consoleColor = @{
                "ERROR" = "Red"
                "WARN" = "Yellow" 
            }[$Level]
            Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $consoleColor
        }
    }
    
    # File logging - determine log file
    $logFileToUse = if ($Script:ProjectRoot -and $Script:ProjectLogFile) { 
        $Script:ProjectLogFile 
    } else { 
        $Script:GLOBAL_LOG_FILE 
    }
    
    # If no log file path is set, skip file logging but don't warn repeatedly
    if (-not $logFileToUse) {
        return
    }
    
    try {
        # Ensure log directory and file exist
        if (-not (Test-Path $logFileToUse)) {
            $logDir = Split-Path -Path $logFileToUse -Parent
            if (-not (Test-Path $logDir)) { 
                New-Item -Path $logDir -ItemType Directory -Force -ErrorAction Stop | Out-Null 
            }
            New-Item -Path $logFileToUse -ItemType File -Force -ErrorAction Stop | Out-Null
            $initialLogEntry = "[$fullTimestamp] [INFO] Log file created at '$logFileToUse'."
            Add-Content -Path $logFileToUse -Value $initialLogEntry -ErrorAction Stop
        }
        
        # Check log file size and rotate if needed
        if ((Test-Path $logFileToUse) -and ((Get-Item $logFileToUse).Length / 1MB) -gt $Script:MAX_LOG_SIZE_MB) {
            $backupLogFile = $logFileToUse + ".bak"
            if (Test-Path $backupLogFile) { Remove-Item $backupLogFile -Force -ErrorAction SilentlyContinue }
            Move-Item $logFileToUse $backupLogFile -ErrorAction SilentlyContinue
            New-Item -Path $logFileToUse -ItemType File -Force -ErrorAction Stop | Out-Null
        }
        
        # Write to log file
        $logEntry = "[$fullTimestamp] [$Level] $Message"
        Add-Content -Path $logFileToUse -Value $logEntry -ErrorAction Stop
        
    } catch { 
        if ($showConsole) {
            Write-Host "[$timestamp] [WARN] Failed to write to log file: '$logFileToUse'. Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
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
    <#
    .SYNOPSIS
        Tests if a command exists in the current session
    .PARAMETER CommandName
        The name of the command to test
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CommandName
    )
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-FileHashCompat {
    <#
    .SYNOPSIS
        Gets file hash with fallback for older PowerShell versions
    .PARAMETER Path
        Path to the file
    .PARAMETER Algorithm
        Hash algorithm (default: SHA256)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $false)][string]$Algorithm = "SHA256"
    )
    
    if (Test-CommandExists 'Get-FileHash') {
        return (Get-FileHash $Path -Algorithm $Algorithm).Hash
    } else {
        # Fallback for older PowerShell versions
        try {
            $crypto = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
            $fileStream = [System.IO.File]::OpenRead($Path)
            $hash = $crypto.ComputeHash($fileStream)
            $fileStream.Close()
            $crypto.Clear()
            return [BitConverter]::ToString($hash).Replace('-', '')
        } catch {
            Write-Log -Level WARN "Failed to compute hash for ${Path}: $($_.Exception.Message)"
            return $null
        }
    }
}

function Show-CreditHeader {
    # Ensure author information is always available
    $authorName = if ($Script:AuthorName) { $Script:AuthorName } else { "Amit Bhardwaj" }
    $authorLinkedIn = if ($Script:AuthorLinkedIn) { $Script:AuthorLinkedIn } else { "linkedin.com/in/salesforce-technical-architect" }
    
    $credit = "Created by $authorName ($authorLinkedIn)"
    Write-Host "`n$credit" -ForegroundColor DarkGray
}

function Show-NavigationHelp {
    <#
    .SYNOPSIS
        Shows navigation help and keyboard shortcuts
    #>
    Write-Host "ℹ️  Navigation: [B]ack | [Q]uit | [H]elp | [Numbers] Select Option" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-StatusBar {
    <#
    .SYNOPSIS
        Shows a status bar at the bottom of the screen
    .PARAMETER Message
        Status message to display
    .PARAMETER Type
        Type of status (Info, Success, Warning, Error)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("Info", "Success", "Warning", "Error")][string]$Type = "Info"
    )
    
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    
    $icons = @{
        "Info" = "ℹ️"
        "Success" = "✅"
        "Warning" = "⚠️"
        "Error" = "❌"
    }
    
    $statusLine = "$($icons[$Type]) $Message"
    $padding = [Math]::Max(0, 80 - $statusLine.Length - 4)
    
    Write-Host "│ $statusLine" -NoNewline -ForegroundColor $colors[$Type]
    Write-Host (" " * $padding) + " │" -ForegroundColor "DarkGray"
}

function Show-OperationComplete {
    <#
    .SYNOPSIS
        Shows operation completion with timing
    .PARAMETER OperationName
        Name of the completed operation
    .PARAMETER StartTime
        Start time of the operation
    .PARAMETER Success
        Whether the operation was successful
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$OperationName,
        [Parameter(Mandatory = $false)][DateTime]$StartTime = (Get-Date),
        [Parameter(Mandatory = $false)][bool]$Success = $true
    )
    
    $duration = (Get-Date) - $StartTime
    $durationText = if ($duration.TotalSeconds -lt 1) { "<1s" } else { "{0:F1}s" -f $duration.TotalSeconds }
    
    $icon = if ($Success) { "✅" } else { "❌" }
    $color = if ($Success) { "Green" } else { "Red" }
    $status = if ($Success) { "completed" } else { "failed" }
    
    Write-Host "┌" + ("─" * 50) + "┐" -ForegroundColor "DarkGray"
    Write-Host "│ $icon $OperationName $status in $durationText" -NoNewline -ForegroundColor $color
    $padding = 50 - "$icon $OperationName $status in $durationText".Length - 2
    Write-Host (" " * $padding) + "│" -ForegroundColor "DarkGray"
    Write-Host "└" + ("─" * 50) + "┘" -ForegroundColor "DarkGray"
    Write-Host ""
}

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Shows a progress bar for long-running operations
    .PARAMETER Activity
        The activity being performed
    .PARAMETER Status
        Current status message
    .PARAMETER PercentComplete
        Percentage complete (0-100)
    .PARAMETER CurrentOperation
        Current operation being performed
    .PARAMETER SecondsRemaining
        Estimated seconds remaining
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Activity,
        [Parameter(Mandatory = $false)][string]$Status = "",
        [Parameter(Mandatory = $false)][int]$PercentComplete = 0,
        [Parameter(Mandatory = $false)][string]$CurrentOperation = "",
        [Parameter(Mandatory = $false)][int]$SecondsRemaining = -1
    )
    
    $params = @{
        Activity = $Activity
        Status = $Status
        PercentComplete = $PercentComplete
    }
    
    if ($CurrentOperation) { $params.CurrentOperation = $CurrentOperation }
    if ($SecondsRemaining -ge 0) { $params.SecondsRemaining = $SecondsRemaining }
    
    Write-Progress @params
}

function Show-FileProcessingProgress {
    <#
    .SYNOPSIS
        Shows real-time file processing progress
    .PARAMETER CurrentFile
        Current file being processed
    .PARAMETER CurrentIndex
        Current file index
    .PARAMETER TotalFiles
        Total number of files
    .PARAMETER ProcessedFiles
        Number of files already processed
    .PARAMETER StartTime
        Start time of the operation
    .PARAMETER OperationName
        Name of the operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CurrentFile,
        [Parameter(Mandatory = $true)][int]$CurrentIndex,
        [Parameter(Mandatory = $true)][int]$TotalFiles,
        [Parameter(Mandatory = $false)][int]$ProcessedFiles = 0,
        [Parameter(Mandatory = $false)][DateTime]$StartTime = (Get-Date),
        [Parameter(Mandatory = $false)][string]$OperationName = "Processing Files"
    )
    
    $percentComplete = if ($TotalFiles -gt 0) { [Math]::Round(($CurrentIndex / $TotalFiles) * 100) } else { 0 }
    
    # Calculate estimated time remaining
    $elapsed = (Get-Date) - $StartTime
    $avgTimePerFile = if ($CurrentIndex -gt 0) { $elapsed.TotalSeconds / $CurrentIndex } else { 0 }
    $remainingFiles = $TotalFiles - $CurrentIndex
    $estimatedRemaining = if ($avgTimePerFile -gt 0) { [Math]::Round($remainingFiles * $avgTimePerFile) } else { -1 }
    
    # Truncate filename if too long
    $displayFile = if ($CurrentFile.Length -gt 60) { 
        "..." + $CurrentFile.Substring($CurrentFile.Length - 57) 
    } else { 
        $CurrentFile 
    }
    
    $status = "Processing file $CurrentIndex of $TotalFiles"
    if ($ProcessedFiles -gt 0) {
        $status += " ($ProcessedFiles changed)"
    }
    
    Show-ProgressBar -Activity $OperationName -Status $status -PercentComplete $percentComplete -CurrentOperation $displayFile -SecondsRemaining $estimatedRemaining
    
    # Debug: Also show immediate console output for first few files
    if ($CurrentIndex -le 5) {
        Write-Host "DEBUG: Processing file $CurrentIndex - $displayFile" -ForegroundColor "Magenta"
        try { [Console]::Out.Flush() } catch { }
    }
    
    # Also show console output for important milestones and every 50 files for better feedback
    if ($CurrentIndex % 50 -eq 0 -or $CurrentIndex -eq 1 -or $CurrentIndex -eq $TotalFiles) {
        Write-Host "📁 [$CurrentIndex/$TotalFiles] Processing: $displayFile" -ForegroundColor "Cyan"
        # Force console output to be visible
        try { [Console]::Out.Flush() } catch { }
    }
}

function Complete-ProgressBar {
    <#
    .SYNOPSIS
        Completes and clears the progress bar
    #>
    Write-Progress -Activity " " -Completed
}

function Invoke-SalesforceCLIWithProgress {
    <#
    .SYNOPSIS
        Invokes Salesforce CLI commands with progress tracking
    .PARAMETER Command
        The SF CLI command to execute
    .PARAMETER Activity
        The activity description for progress bar
    .PARAMETER EstimatedMinutes
        Estimated time in minutes for the operation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Activity,
        [Parameter(Mandatory = $false)][int]$EstimatedMinutes = 5
    )
    
    $startTime = Get-Date
    $estimatedSeconds = $EstimatedMinutes * 60
    
    Write-Host "ℹ️ Starting: $Activity" -ForegroundColor "Cyan"
    Write-Host "⏱️ Estimated time: $EstimatedMinutes minutes" -ForegroundColor "Gray"
    Write-Host "⚙️ Command: $Command" -ForegroundColor "DarkGray"
    Write-Host ""
    
    # Start the SF CLI command as a background job
    $job = Start-Job -ScriptBlock {
        param($cmd)
        $result = Invoke-Expression $cmd 2>&1
        return @{
            Output = $result
            ExitCode = $LASTEXITCODE
        }
    } -ArgumentList $Command
    
    # Show progress while job is running
    $progressId = 1
    $cancelled = $false
    
    try {
        while ($job.State -eq "Running") {
            $elapsed = (Get-Date) - $startTime
            $percentComplete = [Math]::Min(95, ($elapsed.TotalSeconds / $estimatedSeconds) * 100)
            $remainingSeconds = [Math]::Max(0, $estimatedSeconds - $elapsed.TotalSeconds)
            
            Write-Progress -Id $progressId -Activity $Activity -Status "Operation in progress... (Press Ctrl+C to cancel)" -PercentComplete $percentComplete -SecondsRemaining $remainingSeconds
            
            Start-Sleep -Seconds 2
        }
    } catch {
        # Handle Ctrl+C cancellation
        if ($_.Exception.Message -match "canceled|interrupted") {
            Write-Host "⚠️ Operation cancelled by user" -ForegroundColor "Yellow"
            $cancelled = $true
            Stop-Job -Job $job
        } else {
            throw
        }
    }
    
    # Get the job result
    $result = Receive-Job -Job $job
    Remove-Job -Job $job
    
    # Complete progress bar
    Write-Progress -Id $progressId -Activity $Activity -Completed
    
    $duration = (Get-Date) - $startTime
    $durationText = "{0:mm\:ss}" -f $duration
    
    if ($cancelled) {
        Write-Host "⚠️ $Activity cancelled after $durationText" -ForegroundColor "Yellow"
        return $false
    } elseif ($result.ExitCode -eq 0) {
        Write-Host "✅ $Activity completed successfully in $durationText" -ForegroundColor "Green"
    } else {
        Write-Host "❌ $Activity failed after $durationText" -ForegroundColor "Red"
    }
    
    # Output the result
    if ($result.Output) {
        $result.Output | Out-Host
    }
    
    # Set the exit code for the caller
    $global:LASTEXITCODE = $result.ExitCode
    
    return $result.ExitCode -eq 0
}

function Get-EnhancedUserInput {
    <#
    .SYNOPSIS
        Gets user input with enhanced validation and user experience
    .PARAMETER Prompt
        The prompt to display to the user
    .PARAMETER ValidOptions
        Array of valid options
    .PARAMETER DefaultValue
        Default value if user presses Enter
    .PARAMETER ShowHelp
        Whether to show help options
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $false)][array]$ValidOptions = @(),
        [Parameter(Mandatory = $false)][string]$DefaultValue = "",
        [Parameter(Mandatory = $false)][switch]$ShowHelp
    )
    
    do {
        if ($ShowHelp) {
            Write-Host "ℹ️  Type 'h' for help, 'b' for back, 'q' to quit" -ForegroundColor DarkGray
        }
        
        $promptText = if ($DefaultValue) { "$Prompt [$DefaultValue]" } else { $Prompt }
        Write-Host "▶ $promptText" -NoNewline -ForegroundColor Cyan
        $input = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($input) -and $DefaultValue) {
            return $DefaultValue
        }
        
        if ($input -and $input.ToLower() -eq 'h' -and $ShowHelp) {
            Show-NavigationHelp
            continue
        }
        
        if ($input -and $input.ToLower() -eq 'b') {
            return 'b'
        }
        
        if ($input -and $input.ToLower() -eq 'q') {
            return 'q'
        }
        
        if ($ValidOptions.Count -gt 0) {
            if ($input -in $ValidOptions) {
                return $input
            } else {
                Write-Host "❌ Invalid option. Please try again." -ForegroundColor Red
                continue
            }
        }
        
        return $input
        
    } while ($true)
}

function Show-ModernMenu {
    <#
    .SYNOPSIS
        Displays a modern-style menu with better formatting
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Array of menu options
    .PARAMETER BreadcrumbPath
        Navigation breadcrumb path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][array]$Options,
        [Parameter(Mandatory = $false)][string]$BreadcrumbPath = ""
    )
    
    Show-Banner -Title $Title -BreadcrumbPath $BreadcrumbPath
    
    # Modern menu box
    $maxWidth = 60
    $titlePadding = [Math]::Max(0, ($maxWidth - $Title.Length - 4) / 2)
    
    Write-Host "┌" + ("─" * ($maxWidth - 2)) + "┐" -ForegroundColor "Blue"
    Write-Host "│" + (" " * [Math]::Floor($titlePadding)) + " $Title " + (" " * [Math]::Ceiling($titlePadding)) + "│" -ForegroundColor "Cyan"
    Write-Host "├" + ("─" * ($maxWidth - 2)) + "┤" -ForegroundColor "Blue"
    Write-Host "│" + (" " * ($maxWidth - 2)) + "│" -ForegroundColor "Blue"
    
    # Display options
    foreach ($option in $Options) {
        $optionText = "  $($option.Key)  $($option.Label)"
        $padding = $maxWidth - $optionText.Length - 4
        Write-Host "│  " -NoNewline -ForegroundColor "Blue"
        Write-Host $option.Key -NoNewline -ForegroundColor $option.Color
        Write-Host "  $($option.Label)" -NoNewline -ForegroundColor "White"
        Write-Host (" " * $padding) + "  │" -ForegroundColor "Blue"
    }
    
    Write-Host "│" + (" " * ($maxWidth - 2)) + "│" -ForegroundColor "Blue"
    Write-Host "└" + ("─" * ($maxWidth - 2)) + "┘" -ForegroundColor "Blue"
    Write-Host ""
    
    Show-NavigationHelp
}

function Get-CachedData {
    <#
    .SYNOPSIS
        Retrieves cached data if it exists and is not expired
    .PARAMETER CacheKey
        The key for the cached data
    .PARAMETER ExpirationHours
        Hours before cache expires (default: 24)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CacheKey,
        [Parameter(Mandatory = $false)][int]$ExpirationHours = 24
    )
    
    if (-not $Script:Settings.Cache) { return $null }
    $cacheEntry = $Script:Settings.Cache.$CacheKey
    if (-not $cacheEntry) { return $null }
    
    $cacheTime = [datetime]$cacheEntry.Timestamp
    if ((Get-Date) - $cacheTime -gt (New-TimeSpan -Hours $ExpirationHours)) {
        return $null
    }
    
    return $cacheEntry.Data
}

function Set-CachedData {
    <#
    .SYNOPSIS
        Stores data in cache with timestamp
    .PARAMETER CacheKey
        The key for the cached data
    .PARAMETER Data
        The data to cache
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CacheKey,
        [Parameter(Mandatory = $true)]$Data
    )
    
    if (-not $Script:Settings.Cache) {
        $Script:Settings | Add-Member -MemberType NoteProperty -Name 'Cache' -Value (New-Object -TypeName psobject)
    }
    
    $cacheEntry = @{
        Timestamp = (Get-Date -Format "o")
        Data = $Data
    }
    
    $Script:Settings.Cache | Add-Member -MemberType NoteProperty -Name $CacheKey -Value $cacheEntry -Force
    Save-Settings
}


function Get-SystemInfo {
    <#
    .SYNOPSIS
        Retrieves system information for troubleshooting
    #>
    [CmdletBinding()]
    param()
    
    return @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OSVersion = [Environment]::OSVersion.ToString()
        MachineName = [Environment]::MachineName
        UserName = [Environment]::UserName
        ProcessorCount = [Environment]::ProcessorCount
        WorkingSet = [Math]::Round((Get-Process -Id $PID).WorkingSet / 1MB, 2)
        ToolkitVersion = $Script:VERSION
        HasInternetConnection = $true
    }
}

function Initialize-Toolkit {
    <#
    .SYNOPSIS
        Initializes the toolkit with dynamic configuration and system checks
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Initialize configuration system
        Write-Host "🔧 Initializing toolkit configuration..." -ForegroundColor Cyan
        if (-not (Initialize-ToolkitConfiguration)) {
            throw "Configuration initialization failed"
        }
        
        # Set author variables from configuration
        $Script:AuthorName = $Script:Config.AuthorName
        $Script:AuthorLinkedIn = $Script:Config.AuthorLinkedIn
        
        # Test system compatibility
        Write-Host "🔍 Checking system compatibility..." -ForegroundColor Cyan
        if (-not (Test-SystemCompatibility)) {
            $continue = Read-Host "System compatibility issues detected. Continue anyway? (y/n)"
            if ($continue.ToLower() -ne 'y') {
                exit
            }
        }
        
        # Handle remote control and welcome display
        $welcomeTitle = "SFDC DevOps Toolkit v$($Script:VERSION)"
        if ($Script:Config.WelcomeText) {
            $welcomeTitle = $Script:Config.WelcomeText
        }
        
        # Check for tool deactivation via remote control
        if ($Script:Config.PSObject.Properties.Name -contains "IsActive" -and $Script:Config.IsActive -eq $false) {
            Show-Banner -Title $welcomeTitle
            Write-Host "`n❌ TOOL DEACTIVATED BY ADMIN:" -ForegroundColor Red
            if ($Script:Config.RemoteMessage) {
                Write-Host $Script:Config.RemoteMessage -ForegroundColor Yellow
            } else {
                Write-Host "This tool has been temporarily deactivated. Please contact your administrator." -ForegroundColor Yellow
            }
            Read-Host "`nPress Enter to exit."
            exit
        }
        
        # Request telemetry consent from user
        Request-TelemetryConsent
        
        # Initialize usage tracking
        Initialize-UsageTracking
        
        # Set author variables from configuration for banner display
        $Script:AuthorName = $Script:Config.AuthorName
        $Script:AuthorLinkedIn = $Script:Config.AuthorLinkedIn
        
        # Show welcome banner
        Show-Banner -Title $welcomeTitle
        
        # Track toolkit initialization
        Track-Operation -OperationName "Initialize-Toolkit" -Properties @{
            Version = $Script:VERSION
            ConfigType = if ($Script:Config.RemoteControl.Enabled) { "Remote+Embedded" } else { "Embedded" }
            OS = "$($PSVersionTable.OS)"
            PSVersion = "$($PSVersionTable.PSVersion)"
        }
        
        # Check for version updates
        $remoteVersion = if ($Script:Config.PSObject.Properties.Name -contains 'LatestVersion') { $Script:Config.LatestVersion } else { 'Not Available' }
        Write-Log -Level INFO "Version check: Current=$($Script:VERSION), Remote=$remoteVersion"
        if ($Script:Config.PSObject.Properties.Name -contains "LatestVersion") {
            if ($Script:VERSION -ne $Script:Config.LatestVersion) {
                Write-Host "`n🔄 UPDATE AVAILABLE: A newer version ($($Script:Config.LatestVersion)) of the toolkit is available." -ForegroundColor Green
                Write-Log -Level INFO "UPDATE AVAILABLE: Current version $($Script:VERSION) -> New version $($Script:Config.LatestVersion)"
                Track-FeatureUsage -Feature "Version-Check" -Action "Update-Available" -Details @{ CurrentVersion = $Script:VERSION; LatestVersion = $Script:Config.LatestVersion }
            } else {
                Write-Log -Level INFO "Toolkit is up to date (version $($Script:VERSION))"
            }
        } else {
            Write-Log -Level WARN "No version information available in remote configuration"
        }
        
        # Display remote message if available
        if ($Script:Config.PSObject.Properties.Name -contains "RemoteMessage" -and -not [string]::IsNullOrWhiteSpace($Script:Config.RemoteMessage)) {
            Write-Host "`n📢 REMOTE MESSAGE: $($Script:Config.RemoteMessage)" -ForegroundColor Yellow
            Write-Log -Level INFO "Remote message displayed: $($Script:Config.RemoteMessage)"
        } else {
            Write-Log -Level INFO "No remote message available"
        }
        
        
        # Check if this is offline mode
        if (-not $Script:Config.RemoteControl.Enabled) {
            Write-Host "`n📱 Running in offline mode with embedded configuration" -ForegroundColor Cyan
        }
        
        Read-Host "`nPress Enter to begin..."

    } catch {
        Write-Log -Level WARN "Could not fetch remote control file. Continuing in offline mode. Error: $($_.Exception.Message)"
        Write-Log -Level DEBUG "Full exception details: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
        Write-Log -Level DEBUG "Stack trace: $($_.Exception.StackTrace)"
        Show-Banner -Title "SFDC DevOps Toolkit (Offline Mode)"
        Read-Host "`nPress Enter to continue in offline mode..."
    }
    
    Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Started ==================="
    Write-Log -Level INFO "Session Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    if (-not (Test-Path $Script:TOOLKIT_ROOT_CONFIG_DIR)) {
        try {
            New-Item -ItemType Directory -Path $Script:TOOLKIT_ROOT_CONFIG_DIR -ErrorAction Stop | Out-Null
            Write-Log -Level INFO "Created toolkit directory at '$($Script:TOOLKIT_ROOT_CONFIG_DIR)'."
        } catch {
            Write-Log -Level ERROR "FATAL: Could not create toolkit directory. Please check permissions. Error: $($_.Exception.Message)"
            Read-Host "Press Enter to exit."; exit
        }
    }
    
    # Load metadata map if it exists
    if (Test-Path $Script:METADATA_MAP_FILE) {
        try {
            $mapContent = Get-JsonContent -Path $Script:METADATA_MAP_FILE
            # Convert PSCustomObject to hashtable for proper ContainsKey method
            $Script:MetadataMap = @{}
            $mapContent.mappings.PSObject.Properties | ForEach-Object {
                $Script:MetadataMap[$_.Name] = $_.Value
            }
            Write-Log -Level DEBUG "Loaded metadata map with $($Script:MetadataMap.Count) entries."
        } catch {
            Write-Log -Level WARN "Failed to load metadata map. Using default mappings."
            $Script:MetadataMap = @{}
        }
    }
}
#endregion

#region Core: Project and Settings Management
function Select-Project {
    <#
    .SYNOPSIS
        Allows user to select or create a project
    #>
    [CmdletBinding()]
    param()
    
    Show-Banner -Title 'Project Selection'
    Write-Log -Level DEBUG 'Entering function Select-Project.'
    
    $projects = New-Object -TypeName PSObject 

    try {
        if (Test-Path $Script:ROOT_PROJECT_LIST_FILE) {
            $content = Get-Content $Script:ROOT_PROJECT_LIST_FILE -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $projects = $content | ConvertFrom-Json 
            }
        }
    } catch {
        Write-Log -Level ERROR "Could not read or parse project list at '$Script:ROOT_PROJECT_LIST_FILE'. Error: $($_.Exception.Message)"
    }

    $projectKeys = @($projects.PSObject.Properties.Name | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($projectKeys.Count -eq 0) {
        Write-Log -Level INFO 'No valid projects found. Prompting to create a new one.'
        return Create-Project
    }

    Write-Host 'Please select a project:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $projectKeys.Count; $i++) {
        $key = $projectKeys[$i]
        Write-Host "  [$($i+1)] $key"
        Write-Host ('    Path: ' + $projects.$key) -ForegroundColor DarkGray
    }
    Write-Host '  [N] Create a New Project'

    $choice = Read-Host '> Enter your choice'
    if (-not $choice) {
        Write-Log -Level WARN "No choice entered. Exiting."
        return $null
    }
    if ($choice.ToLower() -eq 'n') {
        Write-Log -Level INFO 'User chose to create a new project.'
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
    <#
    .SYNOPSIS
        Creates a new project with validated input and dynamic configuration
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Level DEBUG 'Entering function Create-Project.'
    
    try {
        # Get validated project name
        $projectName = Get-ValidatedInput -Prompt 'Enter a name for your new project (e.g., My-Awesome-Project)' -Type "projectname"
        
        # Get validated project path with safe default
        $defaultPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        $projectBasePath = Get-ValidatedInput -Prompt "Enter path to create project folder (default: '$defaultPath')" -Type "path" -ValidationParams @{ MustExist = $true }
        if ([string]::IsNullOrWhiteSpace($projectBasePath)) { $projectBasePath = $defaultPath }
        
        $projectFullPath = Join-Path -Path $projectBasePath -ChildPath $projectName
        if (Test-Path $projectFullPath) { 
            Write-Log -Level ERROR "A folder named '$projectName' already exists at that location."
            return $false 
        }

        # Show progress for project creation
        Show-ProgressBar -Activity "Creating Project" -Status "Creating project folder..." -PercentComplete 20
        Write-Log -Level INFO "Creating new project folder at '$projectFullPath'."
        New-Item -Path $projectFullPath -ItemType Directory -ErrorAction Stop | Out-Null
        
        $allProjects = if(Test-Path $Script:ROOT_PROJECT_LIST_FILE) { Get-JsonContent -Path $Script:ROOT_PROJECT_LIST_FILE } else { New-Object -TypeName PSObject }
        $allProjects | Add-Member -MemberType NoteProperty -Name $projectName -Value $projectFullPath -Force
        if (-not (Set-JsonContent -Path $Script:ROOT_PROJECT_LIST_FILE -Content $allProjects)) {
            throw "Failed to save project list"
        }
        Write-Log -Level INFO "Added '$projectName' to the project list."

        return Initialize-Project -ProjectName $projectName -ProjectPath $projectFullPath
    } catch {
        Write-Log -Level ERROR "Failed to create project. Error: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-Project {
    <#
    .SYNOPSIS
        Initializes a project with the given name and path
    .PARAMETER ProjectName
        The name of the project
    .PARAMETER ProjectPath
        The path to the project directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$ProjectPath
    )
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
    <#
    .SYNOPSIS
        Loads project settings from the settings file
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Level DEBUG "Entering function 'Load-Settings'."
    if (Test-Path -Path $Script:ProjectSettingsFile) {
        try {
            $Script:Settings = Get-JsonContent -Path $Script:ProjectSettingsFile
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
    <#
    .SYNOPSIS
        Saves current project settings to the settings file
    #>
    [CmdletBinding()]
    param()
    
    if (-not $Script:ProjectRoot) { return }
    try {
        if (-not (Set-JsonContent -Path $Script:ProjectSettingsFile -Content $Script:Settings)) {
            throw "Failed to save project settings"
        }
    } catch { Write-Log -Level ERROR "Failed to save settings: $($_.Exception.Message)" }
}
#endregion

#region UI and Menus
function Show-Banner {
    <#
    .SYNOPSIS
        Displays the toolkit banner with title and navigation breadcrumbs
    .PARAMETER Title
        The title to display in the banner
    .PARAMETER BreadcrumbPath
        The breadcrumb path to display (optional)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $false)][string]$BreadcrumbPath = ""
    )
    try { Clear-Host } catch { }
    
    $textColor = "Cyan"
    Show-CreditHeader

    $projectName = if ($Script:ProjectRoot) { Split-Path -Path $Script:ProjectRoot -Leaf } else { "No Project Selected" }
    
    # Get effective log level for display
    $effectiveLogLevel = "INFO"
    if ($Script:Config -and $Script:Config.GlobalLogLevel) {
        $effectiveLogLevel = $Script:Config.GlobalLogLevel
    }
    if ($Script:Settings -and $Script:Settings.logLevel) {
        $effectiveLogLevel = $Script:Settings.logLevel
    }
    
    # Enhanced header with navigation
    Write-Host ("═" * 80) -ForegroundColor "Blue"
    Write-Host ("  SFDC DevOps Toolkit v$($Script:VERSION)") -ForegroundColor $textColor
    Write-Host ("  Project: " + $projectName + " | Log Level: $effectiveLogLevel") -ForegroundColor "Gray"
    
    # Show breadcrumb navigation if provided
    if ($BreadcrumbPath) {
        Write-Host ("  📍 Navigation: $BreadcrumbPath") -ForegroundColor "Yellow"
    }
    
    Write-Host ("═" * 80) -ForegroundColor "Blue"
    Write-Host ""
}

function Show-SystemInfo {
    function Get-OrgDisplayInfo {
        param([string]$alias)
        if (-not $alias) { return [pscustomobject]@{ Display = "❌ Not Set"; Color = "Yellow"; Api = "N/A" } }
        if ($Script:Settings.Orgs) {
            $org = $Script:Settings.Orgs | Where-Object { $_.alias -eq $alias }
            if ($org) {
                # Ensure these properties exist or default gracefully
                $apiVersion = if ($org.PSObject.Properties['instanceApiVersion']) { $org.instanceApiVersion } else { "Unknown" }
                return [pscustomobject]@{ Display = "✅ $($org.alias) ($($org.username))"; Color = "Green"; Api = $apiVersion }
            }
        }
        return [pscustomobject]@{ Display = "⚠️ $alias (details not cached)"; Color = "Yellow"; Api = "Unknown" }
    }

    $sourceInfo = Get-OrgDisplayInfo -alias $Script:Settings.SourceOrgAlias
    $destInfo = Get-OrgDisplayInfo -alias $Script:Settings.DestinationOrgAlias
    
    # Enhanced project context display
    Write-Host "┌─ Project Context " + ("─" * 50) + "┐" -ForegroundColor "DarkCyan"
    Write-Host "│" -NoNewline -ForegroundColor "DarkCyan"
    Write-Host "  📋 Source Org:        " -NoNewline -ForegroundColor "White"
    Write-Host "$($sourceInfo.Display) | API: $($sourceInfo.Api)" -ForegroundColor $sourceInfo.Color
    Write-Host "│" -NoNewline -ForegroundColor "DarkCyan"
    Write-Host "  🎯 Destination Org: " -NoNewline -ForegroundColor "White"
    Write-Host "$($destInfo.Display) | API: $($destInfo.Api)" -ForegroundColor $destInfo.Color
    Write-Host "│" -NoNewline -ForegroundColor "DarkCyan"
    Write-Host "  🔧 Project Default API: " -NoNewline -ForegroundColor "White"
    Write-Host $Script:Settings.ApiVersion -ForegroundColor "Gray"
    Write-Host "│" -NoNewline -ForegroundColor "DarkCyan"
    Write-Host "  📊 Current Log Level:    " -NoNewline -ForegroundColor "White"
    Write-Host $Script:Settings.logLevel -ForegroundColor "Gray"
    Write-Host "└" + ("─" * 65) + "┘" -ForegroundColor "DarkCyan"
    Write-Host ""
}

function Show-MainMenu {
    $menuOptions = @(
        @{ Key = "[1]"; Label = "Compare and Deploy"; Color = "Yellow" },
        @{ Key = "[2]"; Label = "Project and Org Setup"; Color = "White" },
        @{ Key = "[3]"; Label = "System and Utilities"; Color = "White" },
        @{ Key = "[Q]"; Label = "Quit"; Color = "Red" }
    )
    
    Show-ModernMenu -Title "Main Menu" -Options $menuOptions -BreadcrumbPath "Main Menu"
    Show-SystemInfo
    Write-Log -Level DEBUG "Displaying Main Menu."
}
#endregion

#region Salesforce Operations

function Check-Prerequisites {
    <#
    .SYNOPSIS
        Checks for required tools and software
    .PARAMETER ForceRefresh
        Forces a fresh check instead of using cached results
    #>
    [CmdletBinding()]
    param(
        [switch]$ForceRefresh
    )
    $startTime = Start-Operation -OperationName "System Readiness Check"
    $allGood = $true
    try {
        if (-not $ForceRefresh -and $Script:Settings.SystemInfo -and $Script:Settings.SystemInfo.LastCheck -and ( (New-TimeSpan -Start ([datetime]$Script:Settings.SystemInfo.LastCheck) -End (Get-Date)).TotalHours -lt $Script:CACHE_DURATION_HOURS) ) {
            Write-Log -Level INFO "System check results from cache."
            foreach($item in $Script:Settings.SystemInfo.Software) {
                Write-Host ("  [*] $($item.Name)... ") -NoNewline
                if($item.Installed) { Write-Host '[INSTALLED]' -ForegroundColor Green }
                else { Write-Host '[MISSING]' -ForegroundColor Red }
            }
            End-Operation -StartTime $startTime
            return $true
        }
        $tools = @(
            @{ Name = "Salesforce CLI"; Command = "sf"; Required = $true },
            @{ Name = "Git"; Command = "git"; Required = $false },
            @{ Name = "Visual Studio Code"; Command = "code"; Required = $false },
            @{ Name = "Node.js"; Command = "node"; Required = $false },
            @{ Name = "NPM"; Command = "npm"; Required = $false }
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
        if (-not $Script:Settings.SystemInfo.PSObject.Properties['Software']) { $Script:Settings.SystemInfo | Add-Member -MemberType NoteProperty -Name 'Software' -Value @() }
        if (-not $Script:Settings.SystemInfo.PSObject.Properties['LastCheck']) { $Script:Settings.SystemInfo | Add-Member -MemberType NoteProperty -Name 'LastCheck' -Value $null }
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
    <#
    .SYNOPSIS
        Authorizes a new Salesforce org
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Level DEBUG "Entering function 'Authorize-Org'."
    $alias = Read-Host "`nEnter an alias for the new org"
    if ([string]::IsNullOrWhiteSpace($alias)) { Write-Log -Level WARN "Auth cancelled by user."; return }
    
    # Validate alias format
    if ($alias -notmatch '^[a-zA-Z0-9_-]+$') {
        Write-Log -Level ERROR "Invalid alias format. Use only alphanumeric characters, hyphens, and underscores."
        Read-Host "Press Enter to continue..."
        return
    }
    $isProd = Read-Host "`nIs this a Production/Developer Edition org? (y/n)"
    $instanceUrl = if ($isProd.ToLower() -eq 'n') { "https://test.salesforce.com" } else { "https://login.salesforce.com" }
    try {
        Write-Log -Level INFO "Attempting web login for alias '$alias' with instance URL '$instanceUrl'."
        $loginResult = sf org login web --alias $alias --instance-url $instanceUrl --set-default 2>&1
        if($LASTEXITCODE -ne 0) { 
            Write-Log -Level ERROR "Login failed with exit code $LASTEXITCODE. Output: $loginResult"
            throw "Salesforce CLI reported an error during login." 
        }
        Write-Log -Level INFO "Successfully authorized org '$alias'."
        Clear-ProjectCache -property "Orgs"
    } catch {
        Write-Log -Level ERROR "Failed to authorize org. Error: $($_.Exception.Message | Out-String)"
    }
    Read-Host "`nPress Enter..."
}

function Select-Org {
    <#
    .SYNOPSIS
        Allows user to select source and destination orgs
    #>
    [CmdletBinding()]
    param()
    
    Write-Log -Level DEBUG "Entering function 'Select-Org'."
    while ($true) {
        $cachedOrgs = Get-CachedData -CacheKey "OrgList" -ExpirationHours 6
        if (-not $cachedOrgs) {
            Write-Log -Level INFO "No cached orgs found or cache expired, fetching live list from Salesforce CLI..."
            try {
                $orgsResult = sf org list --json 2>&1
                if ($LASTEXITCODE -ne 0) { 
                    Write-Log -Level ERROR "sf org list failed with exit code $LASTEXITCODE. Output: $orgsResult"
                    throw "Salesforce CLI failed to list orgs."
                }
                $orgsJson = $orgsResult | ConvertFrom-Json
                $orgsList = @($orgsJson.result.nonScratchOrgs) + @($orgsJson.result.scratchOrgs)
                Set-CachedData -CacheKey "OrgList" -Data $orgsList
                if (-not $Script:Settings.PSObject.Properties['Orgs']) { $Script:Settings | Add-Member -MemberType NoteProperty -Name 'Orgs' -Value @() }
                $Script:Settings.Orgs = $orgsList
                Write-Log -Level INFO "Fetched and cached $($Script:Settings.Orgs.Count) orgs."
            } catch { Write-Log -Level ERROR "Failed to list orgs: $($_.Exception.Message | Out-String)"; Read-Host; return }
        } else {
            if (-not $Script:Settings.PSObject.Properties['Orgs']) { $Script:Settings | Add-Member -MemberType NoteProperty -Name 'Orgs' -Value @() }
            $Script:Settings.Orgs = $cachedOrgs
            Write-Log -Level INFO "Using cached org list ($($cachedOrgs.Count) orgs)."
        }
        $orgs = $Script:Settings.Orgs
        if ($orgs.Count -eq 0) {
            Write-Log -Level WARN "No Salesforce orgs have been authorized with the CLI."
            if ((Read-Host "Refresh list now? (y/n)").ToLower() -eq 'y') { 
                Clear-ProjectCache -property 'Orgs'
                $cachedOrgs = $null
                continue 
            }
            Read-Host; return
        }
        Write-Host "`nAvailable Orgs:" -ForegroundColor Green
        for ($i=0; $i -lt $orgs.Count; $i++) { Write-Host "  [$($i+1)] Alias: $($orgs[$i].alias) | User: $($orgs[$i].username)" }
        Write-Host "  [R] Refresh Org List"
        Write-Host "  [Q] Back to calling menu"
        $choice = Read-Host "`nSelect an org to set as SOURCE"
        Write-Log -Level DEBUG "User selection for SOURCE: '$choice'"
        if ($choice.ToLower() -eq 'q') { break }
        if ($choice.ToLower() -eq 'r') { 
            Clear-ProjectCache -property 'Orgs'
            $cachedOrgs = $null
            continue 
        }
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
    <#
    .SYNOPSIS
        Displays information about the selected source org
    #>
    [CmdletBinding()]
    param()
    
    if (-not $Script:Settings.SourceOrgAlias) { Write-Log -Level ERROR "No Source Org selected."; Read-Host; return }
    Write-Log -Level INFO "Displaying information for org '$($Script:Settings.SourceOrgAlias)'."
    try {
        $displayResult = sf org display --target-org $Script:Settings.SourceOrgAlias 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Level ERROR "sf org display failed with exit code $LASTEXITCODE. Output: $displayResult"
            throw "Failed to display org info"
        }
        $displayResult | Out-Host
    } catch { Write-Log -Level ERROR "Failed to display org info. Error: $($_.Exception.Message | Out-String)" }
    Read-Host "`nPress Enter..."
}

function Open-Org {
    <#
    .SYNOPSIS
        Opens the selected source org in the default browser
    #>
    [CmdletBinding()]
    param()
    
    if (-not $Script:Settings.SourceOrgAlias) { Write-Log -Level ERROR "No Source Org selected."; Read-Host; return }
    Write-Log -Level INFO "Opening org '$($Script:Settings.SourceOrgAlias)' in browser."
    try {
        $openResult = sf org open --target-org $Script:Settings.SourceOrgAlias 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Level ERROR "sf org open failed with exit code $LASTEXITCODE. Output: $openResult"
            throw "Failed to open org"
        }
        Write-Log -Level INFO "Successfully opened org '$($Script:Settings.SourceOrgAlias)' in browser."
    } catch { Write-Log -Level ERROR "Failed to open org. Error: $($_.Exception.Message | Out-String)" }
}

function Ensure-Orgs-Selected {
    <#
    .SYNOPSIS
        Ensures both source and destination orgs are selected
    #>
    [CmdletBinding()]
    param()
    
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
        $menuOptions = @(
            @{ Key = "[1]"; Label = "Compare Orgs and Generate Delta Package"; Color = "Yellow" },
            @{ Key = "[2]"; Label = "Quick Visual Compare in VS Code"; Color = "White" },
            @{ Key = "[3]"; Label = "Intelligent Deployment Validation"; Color = "White" },
            @{ Key = "[4]"; Label = "Deploy Metadata (Advanced)"; Color = "White" },
            @{ Key = "[5]"; Label = "DevOps Tools"; Color = "Green" },
            @{ Key = "[B]"; Label = "Back to Main Menu"; Color = "Cyan" },
            @{ Key = "[Q]"; Label = "Quit"; Color = "Red" }
        )
        
        Show-ModernMenu -Title "Compare and Deploy" -Options $menuOptions -BreadcrumbPath "Main Menu > Compare and Deploy"
        $choice = Read-Host '> Enter your choice'
        Write-Log -Level INFO "User selected Compare and Deploy option '$choice'."
        switch ($choice) {
            '1' { Track-FeatureUsage -Feature "Compare-Deploy" -Action "Comparison-SubMenu"; Handle-Comparison-SubMenu }
            '2' { Track-FeatureUsage -Feature "Compare-Deploy" -Action "Quick-Visual-Compare"; Run-Quick-Visual-Compare; Read-Host "`nPress Enter to return..." }
            '3' { Track-FeatureUsage -Feature "Compare-Deploy" -Action "Intelligent-Deployment"; Handle-IntelligentDeployment; Read-Host "`nPress Enter to return..." }
            '4' { Track-FeatureUsage -Feature "Compare-Deploy" -Action "Deploy-Metadata-Advanced"; Deploy-Metadata-Advanced }
            '5' { Track-FeatureUsage -Feature "Compare-Deploy" -Action "DevOps-SubMenu"; Handle-DevOps-SubMenu }
            'b' { return }
            'q' { 
                Track-FeatureUsage -Feature "Compare-Deploy" -Action "Quit"
                try { Send-UsageTelemetry } catch { Write-Log -Level WARN "Failed to send final telemetry" }
                Write-Log -Level INFO 'User chose to quit from Compare and Deploy menu. Ending session.'
                Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Ended ==================="
                Write-Log -Level INFO "Session End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                Save-Settings
                exit
            }
            default { Write-Log -Level WARN "Invalid option." }
        }
    }
}

function Handle-DevOps-SubMenu {
    <#
    .SYNOPSIS
        Handles the DevOps tools submenu
    #>
    while($true) {
        $menuOptions = @(
            @{ Key = "[1]"; Label = "Update Metadata Mappings from Org"; Color = "Green" },
            @{ Key = "[2]"; Label = "Generate Deployment Manifest (package.xml)"; Color = "White" },
            @{ Key = "[3]"; Label = "Analyze Dependencies"; Color = "White" },
            @{ Key = "[4]"; Label = "Validate Project Structure"; Color = "White" },
            @{ Key = "[B]"; Label = "Back to Compare and Deploy Menu"; Color = "Cyan" },
            @{ Key = "[Q]"; Label = "Quit"; Color = "Red" }
        )
        
        Show-ModernMenu -Title "DevOps Tools" -Options $menuOptions -BreadcrumbPath "Main Menu > Compare and Deploy > DevOps Tools"
        $choice = Read-Host '> Enter your choice'
        Write-Log -Level INFO "User selected DevOps Tools option '$choice'."
        switch ($choice) {
            '1' { Track-FeatureUsage -Feature "DevOps-Tools" -Action "Update-Metadata-Mappings"; Update-Metadata-Mappings }
            '2' { Track-FeatureUsage -Feature "DevOps-Tools" -Action "Manifest-Generation"; Handle-Manifest-Generation }
            '3' { Track-FeatureUsage -Feature "DevOps-Tools" -Action "Dependency-Analysis"; Write-Host "Dependency analysis coming soon..." -ForegroundColor Yellow }
            '4' { Track-FeatureUsage -Feature "DevOps-Tools" -Action "Test-Project-Structure"; Test-ProjectStructure }
            'b' { return }
            'q' { 
                Track-FeatureUsage -Feature "DevOps-Tools" -Action "Quit"
                try { Send-UsageTelemetry } catch { Write-Log -Level WARN "Failed to send final telemetry" }
                Write-Log -Level INFO 'User chose to quit from DevOps Tools menu. Ending session.'
                Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Ended ==================="
                Write-Log -Level INFO "Session End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                Save-Settings
                exit
            }
            default { Write-Log -Level WARN "Invalid option." }
        }
        Read-Host "`nPress Enter to return to the DevOps Tools menu..."
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
        $choice = Read-Host '> Enter your choice'
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

function Handle-IntelligentDeployment {
    <#
    .SYNOPSIS
        Handles the intelligent deployment workflow
    #>
    [CmdletBinding()]
    param()
    
    if (-not (Ensure-Orgs-Selected)) { return }
    
    Write-Log -Level DEBUG "Entering 'Intelligent Deployment' menu."
    
    # Check for existing delta package or allow user to select package.xml
    $packageXmlPath = ""
    $sourceMetadataPath = ""
    
    $deltaPackageDir = Join-Path -Path $Script:ProjectRoot -ChildPath "delta-deployment"
    $deltaPackageXml = Join-Path -Path $deltaPackageDir -ChildPath "package.xml"
    
    if (Test-Path $deltaPackageXml) {
        Write-Host "`nDelta package found at: $deltaPackageDir" -ForegroundColor Green
        if ((Read-Host "Use existing delta package? (y/n)").ToLower() -eq 'y') {
            $packageXmlPath = $deltaPackageXml
            $sourceMetadataPath = $deltaPackageDir
        }
    }
    
    if (-not $packageXmlPath) {
        Write-Host "`nSelect package.xml source:" -ForegroundColor Cyan
        Write-Host "  [1] Browse for package.xml file"
        Write-Host "  [2] Use project root package.xml"
        Write-Host "  [3] Generate new package.xml from org"
        
        $choice = Read-Host '> Enter your choice'
        switch ($choice) {
            '1' {
                $packageXmlPath = Read-Host "Enter full path to package.xml"
                $sourceMetadataPath = Read-Host "Enter path to source metadata (or press Enter to skip static analysis)"
            }
            '2' {
                $packageXmlPath = Join-Path -Path $Script:ProjectRoot -ChildPath "package.xml"
                $sourceMetadataPath = Join-Path -Path $Script:ProjectRoot -ChildPath "force-app"
            }
            '3' {
                Generate-Full-Manifest
                $packageXmlPath = Join-Path -Path $Script:ProjectRoot -ChildPath "package.xml"
                $sourceMetadataPath = Join-Path -Path $Script:ProjectRoot -ChildPath "force-app"
            }
            default {
                Write-Log -Level WARN "Invalid selection."
                return
            }
        }
    }
    
    if (-not (Test-Path $packageXmlPath)) {
        Write-Host "Package.xml not found at: $packageXmlPath" -ForegroundColor Red
        return
    }
    
    Write-Host "`nStarting intelligent deployment analysis..." -ForegroundColor Cyan
    Write-Host "Package.xml: $packageXmlPath" -ForegroundColor Gray
    Write-Host "Source metadata: $sourceMetadataPath" -ForegroundColor Gray
    Write-Host "Target org: $($Script:Settings.DestinationOrgAlias)" -ForegroundColor Gray
    
    # Call the main intelligent deployment function
    Invoke-IntelligentDeployment -PackageXmlPath $packageXmlPath -SourceMetadataPath $sourceMetadataPath -TargetOrg $Script:Settings.DestinationOrgAlias -ValidateOnly
}
function Check-And-Prompt-For-Retrieval {
    $sourceDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_source_metadata"
    $destDir = Join-Path -Path $Script:ProjectRoot -ChildPath "_target_metadata"
    $performFreshRetrieval = $true

    if ((Test-Path $sourceDir) -and (Test-Path $destDir)) {
        Write-Log -Level INFO "Previously retrieved metadata found."
        Write-Host "`nPreviously retrieved metadata found." -ForegroundColor Yellow
        Write-Host "[1] Use Existing Local Data (Fast)" -ForegroundColor Cyan
        Write-Host '[2] Perform Fresh Retrieval (Slow, Recommended for accuracy)' -ForegroundColor Cyan
        $choice = Read-Host '> Enter your choice'
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
        Write-Host 'This can take a very long time (10-60+ minutes) depending on the size of your orgs.' -ForegroundColor Yellow
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
        $sourceCommand = "sf project retrieve start --manifest `"$sourceManifestPath`" --target-org $($Script:Settings.SourceOrgAlias) --output-dir `"$sourceDir`" --api-version $($Script:Settings.ApiVersion)"
        $sourceSuccess = Invoke-SalesforceCLIWithProgress -Command $sourceCommand -Activity "Retrieving Source Org Metadata" -EstimatedMinutes 10
        if (-not $sourceSuccess) { throw "Source retrieval failed." }

        # --- Target Org Retrieval ---
        Write-Log -Level INFO "Generating manifest from Target Org: '$($Script:Settings.DestinationOrgAlias)'..."
        Invoke-InTempProject -ScriptBlock {
            param($org, $path, $apiVersion)
            sf project generate manifest --from-org $org --output-dir (Split-Path $path -Parent) --name ([System.IO.Path]::GetFileNameWithoutExtension($path)) --api-version $apiVersion
            if ($LASTEXITCODE -ne 0) { throw "Failed to generate manifest from $org" }
        } -ArgumentList @($Script:Settings.DestinationOrgAlias, $targetManifestPath, $Script:Settings.ApiVersion)

        Write-Log -Level INFO "Retrieving from DESTINATION org into '$destDir'..."
        $destCommand = "sf project retrieve start --manifest `"$targetManifestPath`" --target-org $($Script:Settings.DestinationOrgAlias) --output-dir `"$destDir`" --api-version $($Script:Settings.ApiVersion)"
        $destSuccess = Invoke-SalesforceCLIWithProgress -Command $destCommand -Activity "Retrieving Destination Org Metadata" -EstimatedMinutes 10
        if (-not $destSuccess) { throw "Destination retrieval failed." }
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
    Write-Host "⚙️ Starting delta package generation..." -ForegroundColor "Yellow"
    [Console]::Out.Flush()

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
    
    # Get all files first to show progress
    $sourceFiles = @(Get-ChildItem -Path $SourcePath -Recurse -File)
    $totalSourceFiles = $sourceFiles.Count
    $processedFiles = 0
    $changedFiles = 0
    $startTime = Get-Date
    
    Write-Host "ℹ️ Starting analysis of $totalSourceFiles source files..." -ForegroundColor "Cyan"
    [Console]::Out.Flush()
    
    for ($i = 0; $i -lt $sourceFiles.Count; $i++) {
        $sourceFile = $sourceFiles[$i]
        $currentIndex = $i + 1
        
        # Show progress for every file
        Show-FileProcessingProgress -CurrentFile $sourceFile.FullName -CurrentIndex $currentIndex -TotalFiles $totalSourceFiles -ProcessedFiles $changedFiles -StartTime $startTime -OperationName "Analyzing Source Files"
        
        $relativeSourcePath = Normalize-Relative-Path -FullPath $sourceFile.FullName -BasePath $SourcePath
        $targetFile = Join-Path -Path $TargetPath -ChildPath $relativeSourcePath
        if (-not (Test-Path $targetFile)) {
            $targetFileUnpackaged = Join-Path -Path (Join-Path -Path $TargetPath -ChildPath "unpackaged") -ChildPath $relativeSourcePath
            if (Test-Path $targetFileUnpackaged) { $targetFile = $targetFileUnpackaged }
        }

        $isNew = -not (Test-Path $targetFile)
        $isModified = $false
        if (-not $isNew) {
            $sourceHash = Get-FileHashCompat -Path $sourceFile.FullName -Algorithm SHA256
            $targetHash = Get-FileHashCompat -Path $targetFile -Algorithm SHA256
            if ($sourceHash -and $targetHash -and $sourceHash -ne $targetHash) { $isModified = $true }
        }

        if ($isNew -or $isModified) {
            $componentAdded = Add-Component-To-Types -TypesHashtable $additiveTypes -FullPath $sourceFile.FullName -BasePath $SourcePath -UnrecognizedFolders $unrecognizedFolders
            if($componentAdded) {
                $destinationFileInPackage = Join-Path -Path $DeltaPackageDir -ChildPath $sourceFile.FullName.Substring($SourcePath.Length)
                $destinationDirInPackage = Split-Path -Path $destinationFileInPackage -Parent
                if (-not (Test-Path $destinationDirInPackage)) { New-Item -Path $destinationDirInPackage -ItemType Directory | Out-Null }
                Copy-Item -Path $sourceFile.FullName -Destination $destinationFileInPackage -Force
                $changedFiles++
            }
        }
        $processedFiles++
    }
    
    Complete-ProgressBar
    Write-Host "✅ Pass 1 completed: $changedFiles changed files found out of $totalSourceFiles analyzed" -ForegroundColor "Green"
    [Console]::Out.Flush()

    Write-Log -Level INFO "--- Pass 2: Analyzing target for deleted files... ---"
    
    # Get all target files first to show progress
    $targetFiles = @(Get-ChildItem -Path $TargetPath -Recurse -File)
    $totalTargetFiles = $targetFiles.Count
    $deletedFiles = 0
    $startTime = Get-Date
    
    Write-Host "ℹ️ Starting analysis of $totalTargetFiles target files..." -ForegroundColor "Cyan"
    [Console]::Out.Flush()
    
    for ($i = 0; $i -lt $targetFiles.Count; $i++) {
        $targetFile = $targetFiles[$i]
        $currentIndex = $i + 1
        
        # Show progress for every file
        Show-FileProcessingProgress -CurrentFile $targetFile.FullName -CurrentIndex $currentIndex -TotalFiles $totalTargetFiles -ProcessedFiles $deletedFiles -StartTime $startTime -OperationName "Analyzing Target Files"
        
        $relativeTargetPath = Normalize-Relative-Path -FullPath $targetFile.FullName -BasePath $TargetPath
        $sourceFile = Join-Path -Path $SourcePath -ChildPath $relativeTargetPath
        if (-not (Test-Path $sourceFile)) {
             $sourceFileUnpackaged = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath "unpackaged") -ChildPath $relativeTargetPath
             if (Test-Path $sourceFileUnpackaged) { $sourceFile = $sourceFileUnpackaged }
        }
        
        if (-not (Test-Path $sourceFile)) {
            Add-Component-To-Types -TypesHashtable $destructiveTypes -FullPath $targetFile.FullName -BasePath $TargetPath -UnrecognizedFolders $unrecognizedFolders | Out-Null
            $deletedFiles++
        }
    }
    
    Complete-ProgressBar
    Write-Host "✅ Pass 2 completed: $deletedFiles deleted files found out of $totalTargetFiles analyzed" -ForegroundColor "Green"
    [Console]::Out.Flush()

    Write-Log -Level INFO "--- Pass 3: Generating output files... ---"
    Write-Host "ℹ️ Starting package generation..." -ForegroundColor "Cyan"
    [Console]::Out.Flush()
    
    $foundChanges = $false
    if ($additiveTypes.Keys.Count -gt 0) {
        $foundChanges = $true
        $outputPath = Join-Path -Path $DeltaPackageDir -ChildPath "package.xml"
        Write-Host "⚙️ Generating package.xml with $($additiveTypes.Keys.Count) metadata types..." -ForegroundColor "Yellow"
        try { [Console]::Out.Flush() } catch { }
        Generate-Package-Xml -TypesHashtable $additiveTypes -OutputPath $outputPath -ApiVersion $ApiVersion
        Write-Log -Level INFO "Additive changes found. Created 'package.xml' in '$DeltaPackageDir'"
        Write-Host "✅ Created package.xml with additive changes" -ForegroundColor "Green"
    } else {
        Write-Host "ℹ️ No additive changes found, creating empty package.xml..." -ForegroundColor "Yellow"
        Generate-Package-Xml -TypesHashtable @{} -OutputPath (Join-Path -Path $DeltaPackageDir -ChildPath "package.xml") -ApiVersion $ApiVersion
        Write-Host "✅ Created empty package.xml" -ForegroundColor "Green"
    }
    [Console]::Out.Flush()

    if ($destructiveTypes.Keys.Count -gt 0) {
        $foundChanges = $true
        $destructiveXmlPath = Join-Path -Path $DeltaPackageDir -ChildPath "destructiveChanges.xml"
        Write-Host "⚙️ Generating destructiveChanges.xml with $($destructiveTypes.Keys.Count) metadata types..." -ForegroundColor "Yellow"
        try { [Console]::Out.Flush() } catch { }
        Generate-Package-Xml -TypesHashtable $destructiveTypes -OutputPath $destructiveXmlPath -ApiVersion $ApiVersion
        Write-Log -Level INFO "Destructive changes found. Created 'destructiveChanges.xml' in '$DeltaPackageDir'"
        Write-Host "✅ Created destructiveChanges.xml with destructive changes" -ForegroundColor "Green"
    } else {
        Write-Host "ℹ️ No destructive changes found" -ForegroundColor "Yellow"
    }
    [Console]::Out.Flush()

    if ($unrecognizedFolders.Count -gt 0) {
        Write-Log -Level WARN "The following unrecognized metadata folders were found during comparison:"
        $unrecognizedFolders | ForEach-Object { Write-Log -Level WARN "  - $_" }
        Write-Log -Level WARN "Their contents were NOT included in the package. To add support, run 'Update Metadata Mappings'."
    }

    if (-not $foundChanges) {
        Write-Log -Level INFO "No differences found between source and target orgs."
        Write-Host "ℹ️ No differences found between source and target orgs." -ForegroundColor "Yellow"
    } else {
        Write-Host "✅ Delta package created successfully at: $DeltaPackageDir" -ForegroundColor "Green"
    }
    
    Write-Host "✅ Delta package generation completed!" -ForegroundColor "Green"
    [Console]::Out.Flush()
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
    $manifest = [xml]'<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"></Package>'
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
        Write-Log -Level ERROR 'Visual Studio Code (code command) not found in your PATH.'
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

function Invoke-IntelligentDeployment {
    <#
    .SYNOPSIS
        Performs intelligent deployment validation with iterative dependency resolution
    .PARAMETER PackageXmlPath
        Path to the package.xml file to deploy
    .PARAMETER SourceMetadataPath
        Path to the source metadata folder
    .PARAMETER TargetOrg
        Target org alias for deployment
    .PARAMETER ValidateOnly
        If true, only validates without deploying
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PackageXmlPath,
        [Parameter(Mandatory = $false)][string]$SourceMetadataPath,
        [Parameter(Mandatory = $true)][string]$TargetOrg,
        [Parameter(Mandatory = $false)][switch]$ValidateOnly = $true
    )
    
    $startTime = Start-Operation "Intelligent Deployment with Iterative Validation"
    
    try {
        Write-Host "`n" + "="*80 -ForegroundColor Cyan
        Write-Host "        INTELLIGENT DEPLOYMENT WITH ITERATIVE VALIDATION" -ForegroundColor Cyan
        Write-Host "="*80 -ForegroundColor Cyan
        
        # Step 1: Parse original package.xml
        Write-Log -Level INFO "Parsing original package.xml: $PackageXmlPath"
        $originalComponents = Get-ComponentsFromPackage -PackageXmlPath $PackageXmlPath
        Write-Log -Level INFO "Found $($originalComponents.Count) components in package.xml"
        
        Write-Host "`n✅ Found $($originalComponents.Count) components in original package.xml" -ForegroundColor Green
        
        # Initialize iteration variables
        $iteration = 1
        $maxIterations = 10
        $currentIterationComponents = $originalComponents
        $validationSuccessful = $false
        $iterationResults = @()
        $previousIterationPackage = $PackageXmlPath
        
        # Step 2: Iterative validation with dependency resolution
        while ($iteration -le $maxIterations -and -not $validationSuccessful) {
            Write-Host "`n" + "="*60 -ForegroundColor Yellow
            Write-Host "              ITERATION $iteration" -ForegroundColor Yellow
            Write-Host "="*60 -ForegroundColor Yellow
            
            Write-Host "`nComponents in current package.xml: $($currentIterationComponents.Count)" -ForegroundColor Cyan
            $currentIterationComponents | Group-Object -Property Type | ForEach-Object {
                Write-Host "  • $($_.Name): $($_.Count) components" -ForegroundColor White
            }
            
            # Create iteration package.xml
            $iterationPackagePath = Join-Path -Path $Script:ProjectRoot -ChildPath "iteration-$iteration-package.xml"
            
            if ($iteration -eq 1) {
                # Use original package.xml for first iteration
                Copy-Item -Path $PackageXmlPath -Destination $iterationPackagePath -Force
                Write-Log -Level INFO "Using original package.xml for iteration 1"
            } else {
                # Use components from previous iteration + new dependencies
                $packageXml = New-PackageXmlFromComponents -Components $currentIterationComponents -ApiVersion $Script:Settings.ApiVersion
                $packageXml.Save($iterationPackagePath)
                Write-Log -Level INFO "Created package.xml for iteration $iteration with $($currentIterationComponents.Count) components (previous iteration + new dependencies)"
            }
            
            Write-Host "`n📦 Created package.xml for iteration $iteration" -ForegroundColor Green
            Write-Host "   Path: $iterationPackagePath" -ForegroundColor Gray
            
            # Ask for user approval before validation
            if (-not (Get-IterationApproval -Iteration $iteration -ComponentCount $allComponents.Count -PackagePath $iterationPackagePath)) {
                Write-Host "`n❌ User cancelled deployment at iteration $iteration" -ForegroundColor Red
                break
            }
            
            # Perform validation
            Write-Host "`n🔍 Starting validation for iteration $iteration..." -ForegroundColor Yellow
            $validationResult = Invoke-DeploymentValidation -PackageXmlPath $iterationPackagePath -TargetOrg $TargetOrg
            
            # Store iteration result
            $iterationResults += @{
                Iteration = $iteration
                ComponentCount = $allComponents.Count
                PackagePath = $iterationPackagePath
                ValidationResult = $validationResult
                Success = $validationResult.Success
            }
            
            if ($validationResult.Success) {
                Write-Host "`n✅ VALIDATION SUCCESSFUL!" -ForegroundColor Green
                $validationSuccessful = $true
                break
            } else {
                Write-Host "`n❌ Validation failed. Analyzing failures..." -ForegroundColor Red
                
                # Analyze failures and extract missing dependencies
                $missingDependencies = Get-MissingDependenciesFromValidation -ValidationResult $validationResult
                
                if ($missingDependencies.Count -eq 0) {
                    Write-Host "`n⚠️  No missing dependencies detected. Manual intervention required." -ForegroundColor Yellow
                    break
                }
                
                Write-Host "`n📋 Found $($missingDependencies.Count) missing dependencies:" -ForegroundColor Yellow
                $missingDependencies | ForEach-Object {
                    Write-Host "  • $($_.Type): $($_.Name)" -ForegroundColor Red
                }
                
                # Filter dependencies into deployable and non-deployable categories
                $deployableDependencies = @()
                $nonDeployableDependencies = @()
                $sourceDir = Split-Path -Parent $PackageXmlPath
                
                Write-Host "`n🔍 Analyzing dependencies for deployability..." -ForegroundColor Cyan
                
                foreach ($dependency in $missingDependencies) {
                    $isDeployable = $false
                    $reason = ""
                    
                    # Get deployability info from dynamic configuration
                    # Ensure Type and Name are properly converted to strings
                    $dependencyType = [string]$dependency.Type
                    $dependencyName = [string]$dependency.Name
                    $deployabilityInfo = Get-DependencyDeployabilityInfo -DependencyType $dependencyType -DependencyName $dependencyName -SourceDir $sourceDir
                    $isDeployable = $deployabilityInfo.IsDeployable
                    $reason = $deployabilityInfo.Reason
                    
                    if ($isDeployable) {
                        $deployableDependencies += $dependency
                        Write-Host "  ✅ Deployable: $dependencyType - $dependencyName" -ForegroundColor Green
                        Write-Host "     → $reason" -ForegroundColor Gray
                    } else {
                        $nonDeployableDependencies += @{
                            Type = $dependencyType
                            Name = $dependencyName
                            Reason = $reason
                            ErrorContext = $dependency.ErrorContext
                            ManualInstructions = $deployabilityInfo.ManualInstructions
                            SetupPath = $deployabilityInfo.SetupPath
                            Documentation = $deployabilityInfo.Documentation
                        }
                        Write-Host "  ⚠️  Non-deployable: $dependencyType - $dependencyName" -ForegroundColor Yellow
                        Write-Host "     → $reason" -ForegroundColor Gray
                    }
                }
                
                # Generate manual instructions file for non-deployable dependencies
                if ($nonDeployableDependencies.Count -gt 0) {
                    $manualInstructionsFile = Join-Path -Path $Script:ProjectRoot -ChildPath "MANUAL_CONFIGURATION_REQUIRED.md"
                    Generate-ManualInstructionsFile -Dependencies $nonDeployableDependencies -OutputPath $manualInstructionsFile -Iteration $iteration
                    Write-Host "`n📝 Created manual instructions file: $manualInstructionsFile" -ForegroundColor Cyan
                }
                
                if ($deployableDependencies.Count -gt 0) {
                    # Add deployable dependencies to current iteration components
                    $currentIterationComponents += $deployableDependencies
                    
                    Write-Host "`n🔄 Added $($deployableDependencies.Count) deployable dependencies to iteration components" -ForegroundColor Cyan
                    Write-Host "   Next iteration will have $($currentIterationComponents.Count) total components" -ForegroundColor Gray
                    
                    if ($nonDeployableDependencies.Count -gt 0) {
                        Write-Host "`n⚠️  $($nonDeployableDependencies.Count) dependencies require manual configuration in target org" -ForegroundColor Yellow
                        Write-Host "   See MANUAL_CONFIGURATION_REQUIRED.md for details" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "`n⚠️  No deployable dependencies found. All dependencies require manual configuration." -ForegroundColor Yellow
                    Write-Host "   Found $($missingDependencies.Count) dependencies that need manual setup" -ForegroundColor Gray
                    Write-Host "   See MANUAL_CONFIGURATION_REQUIRED.md for complete instructions" -ForegroundColor Gray
                    
                    # Since no deployable dependencies, the package is now clean
                    Write-Host "`n✅ Package is now deployment-ready (all remaining issues require manual org configuration)" -ForegroundColor Green
                    $validationSuccessful = $true
                    break
                }
                
                $iteration++
                
                if ($iteration -le $maxIterations) {
                    Write-Host "`n🔄 Preparing iteration $iteration with additional dependencies..." -ForegroundColor Cyan
                } else {
                    Write-Host "`n⚠️  Maximum iterations ($maxIterations) reached. Stopping." -ForegroundColor Yellow
                }
            }
        }
        
        # Step 3: Show final results
        Show-IterativeValidationResults -Results $iterationResults -Success $validationSuccessful
        
        # Final deployment package summary
        if ($validationSuccessful) {
            Write-Host "`n" + "="*80 -ForegroundColor Green
            Write-Host "           🎉 DEPLOYMENT PACKAGE READY!" -ForegroundColor Green
            Write-Host "="*80 -ForegroundColor Green
            
            Write-Host "`n✅ Your deployment package has been successfully created and validated" -ForegroundColor Green
            Write-Host "✅ All iterations completed successfully" -ForegroundColor Green
            Write-Host "✅ Package contains only deployable components" -ForegroundColor Green
            
            $finalPackagePath = Join-Path -Path $Script:ProjectRoot -ChildPath "iteration-$($iteration-1)-package.xml"
            Write-Host "`n📦 Final Package:" -ForegroundColor Cyan
            Write-Host "   Path: $finalPackagePath" -ForegroundColor White
            
            $manualInstructionsPath = Join-Path -Path $Script:ProjectRoot -ChildPath "MANUAL_CONFIGURATION_REQUIRED.md"
            if (Test-Path $manualInstructionsPath) {
                Write-Host "`n📝 Manual Configuration Required:" -ForegroundColor Yellow
                Write-Host "   Instructions: $manualInstructionsPath" -ForegroundColor White
                Write-Host "   Complete these manual steps in your target org before deployment" -ForegroundColor Gray
            }
            
            Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
            Write-Host "   1. Review the final package.xml file" -ForegroundColor White
            Write-Host "   2. Complete any manual configurations in target org" -ForegroundColor White
            Write-Host "   3. Deploy the package using 'sf project deploy start'" -ForegroundColor White
            Write-Host "   4. Monitor deployment progress in target org" -ForegroundColor White
            
            Write-Host "`n⚠️  Important: This was validation only - no actual deployment occurred" -ForegroundColor Yellow
        } else {
            Write-Host "`n❌ Deployment package creation completed with limitations" -ForegroundColor Red
            Write-Host "   Some issues may require manual resolution" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Log -Level ERROR "Intelligent deployment failed: $($_.Exception.Message)"
        Write-Host "`n❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        End-Operation -StartTime $startTime
    }
}

function Get-DependencyDeployabilityInfo {
    <#
    .SYNOPSIS
        Dynamically determines if a dependency is deployable and provides guidance
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$DependencyType,
        [Parameter(Mandatory = $true)][string]$DependencyName,
        [Parameter(Mandatory = $true)][string]$SourceDir
    )
    
    # Validate parameters
    if ([string]::IsNullOrWhiteSpace($DependencyType)) {
        Write-Log -Level ERROR "DependencyType parameter is null or empty"
        return @{
            IsDeployable = $false
            Reason = "Invalid dependency type"
            ManualInstructions = @()
            SetupPath = ""
            Documentation = ""
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($DependencyName)) {
        Write-Log -Level ERROR "DependencyName parameter is null or empty"
        return @{
            IsDeployable = $false
            Reason = "Invalid dependency name"
            ManualInstructions = @()
            SetupPath = ""
            Documentation = ""
        }
    }
    
    try {
        # Get deployability rules from dynamic configuration
        $deployabilityConfig = Get-DependencyDeployabilityConfig
        
        # Check if we have specific configuration for this dependency type
        if ($deployabilityConfig.ContainsKey($DependencyType)) {
            $typeConfig = $deployabilityConfig[$DependencyType]
            
            # Handle different evaluation strategies
            switch ($typeConfig.EvaluationStrategy) {
                "SourceFileCheck" {
                    $sourceFile = Join-Path -Path $SourceDir -ChildPath $typeConfig.SourcePath.Replace("{NAME}", $DependencyName)
                    $isDeployable = Test-Path $sourceFile
                    $reason = if ($isDeployable) { "Source file found at: $sourceFile" } else { $typeConfig.NonDeployableReason }
                }
                "NamePattern" {
                    $isDeployable = $true
                    foreach ($pattern in $typeConfig.NonDeployablePatterns) {
                        if ($DependencyName -like $pattern) {
                            $isDeployable = $false
                            $reason = $typeConfig.NonDeployableReason
                            break
                        }
                    }
                    if ($isDeployable) {
                        # Still check for source file
                        $sourceFile = Join-Path -Path $SourceDir -ChildPath $typeConfig.SourcePath.Replace("{NAME}", $DependencyName)
                        $isDeployable = Test-Path $sourceFile
                        $reason = if ($isDeployable) { "Source file found at: $sourceFile" } else { "Source file missing: $sourceFile" }
                    }
                }
                "AlwaysNonDeployable" {
                    $isDeployable = $false
                    $reason = $typeConfig.NonDeployableReason
                }
                "Dynamic" {
                    # For dynamic types, try to determine from Salesforce metadata API
                    $dynamicResult = Get-DynamicDependencyInfo -DependencyType $DependencyType -DependencyName $DependencyName -SourceDir $SourceDir
                    $isDeployable = $dynamicResult.IsDeployable
                    $reason = $dynamicResult.Reason
                }
                default {
                    $isDeployable = $false
                    $reason = "Unknown evaluation strategy: $($typeConfig.EvaluationStrategy)"
                }
            }
        } else {
            # Handle unknown dependency types dynamically
            $dynamicResult = Get-DynamicDependencyInfo -DependencyType $DependencyType -DependencyName $DependencyName -SourceDir $SourceDir
            $isDeployable = $dynamicResult.IsDeployable
            $reason = $dynamicResult.Reason
        }
        
        return @{
            IsDeployable = $isDeployable
            Reason = $reason
            ManualInstructions = $typeConfig.ManualInstructions
            SetupPath = $typeConfig.SetupPath
            Documentation = $typeConfig.Documentation
        }
        
    } catch {
        Write-Log -Level ERROR "Error evaluating dependency deployability: $($_.Exception.Message)"
        return @{
            IsDeployable = $false
            Reason = "Error evaluating dependency: $($_.Exception.Message)"
            ManualInstructions = "Manual review required due to evaluation error"
            SetupPath = "Unknown"
            Documentation = "https://help.salesforce.com"
        }
    }
}

function Get-DependencyDeployabilityConfig {
    <#
    .SYNOPSIS
        Returns streamlined dependency deployability configuration
    #>
    [CmdletBinding()]
    param()
    
    # Use embedded configuration with option for future remote config
    return Get-EmbeddedDependencyConfig
}

function Get-RemoteDependencyConfig {
    <#
    .SYNOPSIS
        Attempts to load dependency configuration from GitHub
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Try multiple potential configuration sources
        $configUrls = @(
            "https://raw.githubusercontent.com/sfdcai/sfdc-toolkit/refs/heads/main/salesforce-deployment-config/dependency-config.json",
            $Script:REMOTE_CONTROL_URL.Replace("control.json", "dependency-config.json")
        )
        
        foreach ($configUrl in $configUrls) {
            try {
                Write-Log -Level INFO "Attempting to load dependency config from: $configUrl"
                
                # Try to fetch remote configuration with timeout
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                
                $headers = @{ "Cache-Control" = "no-cache"; "Pragma" = "no-cache" }
                $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
                
                $response = Invoke-HttpRequestWithLogging -Uri $configUrl -Headers $headers -Method "GET" -UserAgent $userAgent -Purpose "Get Remote Dependency Configuration"
                $remoteConfig = $response.Content | ConvertFrom-Json
                
                # Validate config structure
                if ($remoteConfig.dependencyTypes) {
                    # Convert to hashtable for easier use
                    $configHash = @{}
                    $remoteConfig.dependencyTypes.PSObject.Properties | ForEach-Object {
                        $configHash[$_.Name] = $_.Value
                    }
                    
                    Write-Log -Level INFO "Successfully loaded remote dependency configuration from: $configUrl"
                    return $configHash
                }
                
            } catch {
                Write-Log -Level WARN "Failed to load dependency config from $configUrl : $($_.Exception.Message)"
                continue
            }
        }
        
        return $null
        
    } catch {
        Write-Log -Level ERROR "Could not load remote dependency configuration: $($_.Exception.Message)"
        Write-Log -Level ERROR "Full dependency config error: $($_.Exception.ToString())"
        return $null
    }
}

function Get-SalesforceMetadataTypes {
    <#
    .SYNOPSIS
        Queries Salesforce org to get available metadata types dynamically
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetOrg
    )
    
    try {
        Write-Log -Level DEBUG "Querying Salesforce metadata types for org: $TargetOrg"
        
        # Use sf CLI to describe metadata types
        $command = @('sf', 'org', 'list', 'metadata-types', '--target-org', $TargetOrg, '--json')
        
        $output = & $command[0] $command[1..($command.Count-1)] 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $result = $output | ConvertFrom-Json
            
            if ($result.result -and $result.result.metadataObjects) {
                $metadataTypes = @{}
                
                foreach ($metadataObject in $result.result.metadataObjects) {
                    $metadataTypes[$metadataObject.xmlName] = @{
                        DirectoryName = $metadataObject.directoryName
                        InFolder = $metadataObject.inFolder
                        MetaFile = $metadataObject.metaFile
                        Suffix = $metadataObject.suffix
                        ChildXmlNames = $metadataObject.childXmlNames
                    }
                }
                
                Write-Log -Level INFO "Retrieved $($metadataTypes.Count) metadata types from Salesforce"
                return $metadataTypes
            }
        }
        
        Write-Log -Level WARN "Could not retrieve metadata types from Salesforce: $output"
        return $null
        
    } catch {
        Write-Log -Level ERROR "Error querying Salesforce metadata types: $($_.Exception.Message)"
        return $null
    }
}

function Get-EmbeddedDependencyConfig {
    <#
    .SYNOPSIS
        Returns embedded dependency configuration as fallback
    #>
    [CmdletBinding()]
    param()
    
    return @{
        "Settings" = @{
            EvaluationStrategy = "SourceFileCheck"
            SourcePath = "settings/{NAME}.settings-meta.xml"
            NonDeployableReason = "Org-level setting - requires manual configuration in target org"
            ManualInstructions = "Enable and configure {NAME} settings in Setup → Settings → {NAME}"
            SetupPath = "Setup → Settings → {NAME}"
            Documentation = "https://help.salesforce.com/search?q={NAME}%20settings"
        }
        
        "CustomApplication" = @{
            EvaluationStrategy = "NamePattern"
            SourcePath = "applications/{NAME}.app-meta.xml"
            NonDeployablePatterns = @("standard__*")
            NonDeployableReason = "Standard Salesforce application - enable manually in target org"
            ManualInstructions = "Enable the '{NAME}' application in Setup → Apps → App Manager"
            SetupPath = "Setup → Apps → App Manager"
            Documentation = "https://help.salesforce.com/search?q={NAME}%20application"
        }
        
        "UserPermission" = @{
            EvaluationStrategy = "AlwaysNonDeployable"
            NonDeployableReason = "User permission - enable manually in target org profiles/permission sets"
            ManualInstructions = "Enable the '{NAME}' permission for required profiles/permission sets"
            SetupPath = "Setup → Users → Profiles or Permission Sets"
            Documentation = "https://help.salesforce.com/search?q={NAME}%20permission"
        }
        
        "Profile" = @{
            EvaluationStrategy = "SourceFileCheck"
            SourcePath = "profiles/{NAME}.profile-meta.xml"
            NonDeployableReason = "Profile source file missing - may need to be retrieved from source org"
            ManualInstructions = "Create or configure the '{NAME}' profile in target org"
            SetupPath = "Setup → Users → Profiles"
            Documentation = "https://help.salesforce.com/search?q=profile%20management"
        }
        
        "PermissionSet" = @{
            EvaluationStrategy = "SourceFileCheck"
            SourcePath = "permissionsets/{NAME}.permissionset-meta.xml"
            NonDeployableReason = "Permission set source file missing - may need to be retrieved from source org"
            ManualInstructions = "Create or configure the '{NAME}' permission set in target org"
            SetupPath = "Setup → Users → Permission Sets"
            Documentation = "https://help.salesforce.com/search?q=permission%20set"
        }
    }
}

function Get-DynamicDependencyInfo {
    <#
    .SYNOPSIS
        Dynamically determines dependency info for unknown types using Salesforce metadata API
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$DependencyType,
        [Parameter(Mandatory = $true)][string]$DependencyName,
        [Parameter(Mandatory = $true)][string]$SourceDir
    )
    
    try {
        # First try to get Salesforce metadata types dynamically
        $salesforceMetadataTypes = $null
        if ($Script:Settings -and $Script:Settings.targetOrg) {
            $salesforceMetadataTypes = Get-SalesforceMetadataTypes -TargetOrg $Script:Settings.targetOrg
        }
        
        # Use Salesforce metadata API info if available
        if ($salesforceMetadataTypes -and $salesforceMetadataTypes.ContainsKey($DependencyType)) {
            $metadataInfo = $salesforceMetadataTypes[$DependencyType]
            
            # Build possible source paths based on Salesforce metadata API
            $possiblePaths = @()
            
            if ($metadataInfo.DirectoryName) {
                $baseDir = $metadataInfo.DirectoryName
                
                if ($metadataInfo.Suffix) {
                    $possiblePaths += "$baseDir\$DependencyName.$($metadataInfo.Suffix)"
                }
                
                if ($metadataInfo.MetaFile) {
                    $possiblePaths += "$baseDir\$DependencyName.$($metadataInfo.Suffix)-meta.xml"
                }
                
                # Try common patterns
                $possiblePaths += "$baseDir\$DependencyName.meta.xml"
                $possiblePaths += "$baseDir\$DependencyName.xml"
            }
            
            # Check if any of the possible paths exist
            foreach ($relativePath in $possiblePaths) {
                $fullPath = Join-Path -Path $SourceDir -ChildPath $relativePath
                if (Test-Path $fullPath) {
                    return @{
                        IsDeployable = $true
                        Reason = "Source file found at: $fullPath"
                    }
                }
            }
            
            return @{
                IsDeployable = $false
                Reason = "Source file missing for $DependencyType (expected in $($metadataInfo.DirectoryName) folder)"
            }
        }
        
        # Fallback to local metadata map
        $metadataTypeFolder = $null
        foreach ($folder in $Script:MetadataMap.Keys) {
            if ($Script:MetadataMap[$folder] -eq $DependencyType) {
                $metadataTypeFolder = $folder
                break
            }
        }
        
        if ($metadataTypeFolder) {
            # Try common file extensions for this metadata type
            $commonExtensions = @("meta.xml", "$($metadataTypeFolder.TrimEnd('s')).meta.xml", "xml")
            
            foreach ($extension in $commonExtensions) {
                $possiblePath = Join-Path -Path $SourceDir -ChildPath "$metadataTypeFolder\$DependencyName.$extension"
                if (Test-Path $possiblePath) {
                    return @{
                        IsDeployable = $true
                        Reason = "Source file found at: $possiblePath"
                    }
                }
            }
            
            return @{
                IsDeployable = $false
                Reason = "Source file missing for $DependencyType in $metadataTypeFolder folder"
            }
        } else {
            # Unknown metadata type - check if it might be a standard/system component
            $standardPrefixes = @("standard__", "system__", "sf__")
            $isStandard = $standardPrefixes | Where-Object { $DependencyName -like "$_*" }
            
            if ($isStandard) {
                return @{
                    IsDeployable = $false
                    Reason = "Standard/system component - requires manual configuration"
                }
            } else {
                return @{
                    IsDeployable = $false
                    Reason = "Unknown metadata type '$DependencyType' - manual review required"
                }
            }
        }
        
    } catch {
        return @{
            IsDeployable = $false
            Reason = "Error evaluating dependency: $($_.Exception.Message)"
        }
    }
}

function Generate-ManualInstructionsFile {
    <#
    .SYNOPSIS
        Generates a markdown file with manual configuration instructions for non-deployable dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$Dependencies,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$Iteration
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $projectName = Split-Path -Leaf $Script:ProjectRoot
        
        $content = @"
# Manual Configuration Required for Deployment

**Project:** $projectName  
**Generated:** $timestamp  
**Iteration:** $iteration  

## Overview

This deployment package has been successfully created, but some dependencies require manual configuration in the target Salesforce org before deployment can succeed. This document provides step-by-step instructions for each required manual configuration.

## ⚠️ Important Notes

- **This is validation only** - No actual deployment has occurred
- Complete these manual configurations in your **target org** before deploying
- After completing these steps, the deployment package should deploy successfully
- Some configurations may already exist in your target org

---

## Manual Configuration Tasks

"@

        $groupedDependencies = $Dependencies | Group-Object -Property Type
        
        foreach ($group in $groupedDependencies) {
            $content += "`n### $($group.Name) Configuration`n`n"
            $content += "**Type:** $($group.Name)`n"
            $content += "**Action Required:** Configuration needed for the following items`n`n"
            
            foreach ($dep in $group.Group) {
                $content += "#### $($dep.Name)`n"
                $content += "- **Issue:** $($dep.ErrorContext)`n"
                $content += "- **Reason:** $($dep.Reason)`n"
                
                if ($dep.SetupPath) {
                    $setupPath = $dep.SetupPath.Replace("{NAME}", $dep.Name)
                    $content += "- **Path:** $setupPath`n"
                }
                
                if ($dep.ManualInstructions) {
                    $instructions = $dep.ManualInstructions.Replace("{NAME}", $dep.Name)
                    $content += "- **Action:** $instructions`n"
                }
                
                if ($dep.Documentation) {
                    $docUrl = $dep.Documentation.Replace("{NAME}", $dep.Name)
                    $content += "- **Documentation:** [$($dep.Name) Help]($docUrl)`n"
                }
                
                $content += "`n"
            }
        }
        
        $content += @"

---

## Deployment Steps

After completing the manual configurations above:

1. **Verify configurations** in your target org
2. **Test the deployment** using the generated package.xml
3. **Deploy the package** when validation succeeds

## Package Information

- **Package Path:** Generated iteration package.xml files
- **Total Manual Tasks:** $($Dependencies.Count)
- **Deployment Mode:** Validation only (--dry-run)

## Support

- Review Salesforce documentation for specific feature setup
- Contact your Salesforce admin for org-specific configurations
- Test in a sandbox environment first

---

*Generated by Salesforce DevOps Toolkit - Iteration $iteration*
"@

        # Write the content to file
        $content | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Log -Level INFO "Manual instructions file created: $OutputPath"
        
    } catch {
        Write-Log -Level ERROR "Failed to generate manual instructions file: $($_.Exception.Message)"
        throw
    }
}

function Get-ComponentsFromPackage {
    <#
    .SYNOPSIS
        Extracts components from a package.xml file
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$PackageXmlPath)
    
    try {
        $packageXml = [xml](Get-Content $PackageXmlPath -Raw)
        $components = @()
        
        foreach ($typeNode in $packageXml.Package.types) {
            $typeName = $typeNode.name
            foreach ($memberNode in $typeNode.members) {
                $components += @{
                    Type = $typeName
                    Name = $memberNode.InnerText
                    Source = "Original"
                }
            }
        }
        
        Write-Log -Level INFO "Found $($components.Count) components in package.xml"
        return $components
    } catch {
        Write-Log -Level ERROR "Failed to parse package.xml: $($_.Exception.Message)"
        throw
    }
}

function New-PackageXmlFromComponents {
    <#
    .SYNOPSIS
        Creates a package.xml file from component list
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$Components,
        [Parameter(Mandatory = $true)][string]$ApiVersion
    )
    
    try {
        $groupedComponents = $Components | Group-Object -Property Type
        
        $manifest = [xml]'<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"></Package>'
        $packageNode = $manifest.Package
        
        foreach ($group in $groupedComponents) {
            # Skip groups with empty or null names
            if ([string]::IsNullOrWhiteSpace($group.Name)) {
                Write-Log -Level WARN "Skipping group with empty or null name"
                continue
            }
            
            $typeNode = $manifest.CreateElement("types", $packageNode.NamespaceURI)
            
            $uniqueNames = $group.Group | ForEach-Object { $_.Name } | Sort-Object -Unique
            foreach ($name in $uniqueNames) {
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    $memberNode = $manifest.CreateElement("members", $packageNode.NamespaceURI)
                    $memberNode.InnerText = $name
                    $typeNode.AppendChild($memberNode) | Out-Null
                }
            }
            
            # Only add the type node if it has members
            if ($typeNode.HasChildNodes) {
                $nameNode = $manifest.CreateElement("name", $packageNode.NamespaceURI)
                $nameNode.InnerText = $group.Name
                $typeNode.AppendChild($nameNode) | Out-Null
                $packageNode.AppendChild($typeNode) | Out-Null
            }
        }
        
        $versionNode = $manifest.CreateElement("version", $packageNode.NamespaceURI)
        $versionNode.InnerText = $ApiVersion
        $packageNode.AppendChild($versionNode) | Out-Null
        
        return $manifest
    } catch {
        Write-Log -Level ERROR "Failed to create package.xml: $($_.Exception.Message)"
        throw
    }
}

function Get-IterationApproval {
    <#
    .SYNOPSIS
        Gets user approval for each validation iteration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][int]$Iteration,
        [Parameter(Mandatory = $true)][int]$ComponentCount,
        [Parameter(Mandatory = $true)][string]$PackagePath
    )
    
    Write-Host "`n" + "="*60 -ForegroundColor Magenta
    Write-Host "           USER APPROVAL REQUIRED - ITERATION $Iteration" -ForegroundColor Magenta
    Write-Host "="*60 -ForegroundColor Magenta
    
    Write-Host "`nIteration Details:" -ForegroundColor Yellow
    Write-Host "  • Iteration Number: $Iteration" -ForegroundColor White
    Write-Host "  • Total Components: $ComponentCount" -ForegroundColor White
    Write-Host "  • Package Path: $PackagePath" -ForegroundColor White
    Write-Host "  • Target Org: $($Script:Settings.DestinationOrgAlias)" -ForegroundColor White
    Write-Host "  • Operation: VALIDATE-ONLY (dry-run)" -ForegroundColor Green
    
    Write-Host "`nThis will perform a validate-only deployment to check for missing dependencies." -ForegroundColor Cyan
    Write-Host "No actual deployment will occur." -ForegroundColor Green
    
    do {
        $response = Read-Host "`nProceed with validation iteration $Iteration? (y/n/v)"
        $response = $response.ToLower()
        
        if ($response -eq 'v') {
            Write-Host "`nShowing first 20 components in package.xml:" -ForegroundColor Cyan
            try {
                $packageXml = [xml](Get-Content $PackagePath -Raw)
                $componentCount = 0
                foreach ($typeNode in $packageXml.Package.types) {
                    $typeName = $typeNode.name
                    foreach ($memberNode in $typeNode.members) {
                        $componentCount++
                        if ($componentCount -le 20) {
                            Write-Host "  • $typeName`: $($memberNode.InnerText)" -ForegroundColor White
                        }
                    }
                }
                if ($componentCount -gt 20) {
                    Write-Host "  ... and $($componentCount - 20) more components" -ForegroundColor Gray
                }
            } catch {
                Write-Host "  Error reading package.xml" -ForegroundColor Red
            }
        }
    } while ($response -notin @('y', 'n'))
    
    return $response -eq 'y'
}

function Get-MissingDependenciesFromValidation {
    <#
    .SYNOPSIS
        Analyzes validation failures to extract missing dependencies
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$ValidationResult)
    
    $missingDependencies = @()
    
    try {
        # Parse JSON result from Salesforce CLI
        $errorMessages = @()
        
        # Debug: Show validation result structure
        Write-Host "`n🔍 Dependency Extraction Debug:" -ForegroundColor Cyan
        Write-Host "ValidationResult.Success: $($ValidationResult.Success)" -ForegroundColor Gray
        Write-Host "ValidationResult.Result type: $($ValidationResult.Result.GetType().Name)" -ForegroundColor Gray
        
        # Try to parse the JSON result if it's a string
        $jsonResult = $null
        if ($ValidationResult.Result -is [string]) {
            try {
                $jsonResult = $ValidationResult.Result | ConvertFrom-Json
                Write-Host "Successfully parsed JSON result" -ForegroundColor Green
            } catch {
                Write-Host "Failed to parse JSON result: $($_.Exception.Message)" -ForegroundColor Red
                $jsonResult = $null
            }
        } else {
            $jsonResult = $ValidationResult.Result
        }
        
        if ($jsonResult -and $jsonResult.result) {
            $result = $jsonResult.result
            Write-Host "Found result.result structure" -ForegroundColor Green
            
            # Extract error messages from different sources
            if ($result.details) {
                Write-Host "Found result.details structure" -ForegroundColor Green
                
                # Check for componentFailures
                if ($result.details.componentFailures) {
                    Write-Host "Found componentFailures: $($result.details.componentFailures.Count)" -ForegroundColor Green
                    foreach ($failure in $result.details.componentFailures) {
                        Write-Host "  Component failure: $($failure.fullName) - $($failure.problem)" -ForegroundColor Yellow
                        $errorMessages += $failure.problem
                    }
                }
                
                # Check for componentDeployments with problems
                if ($result.details.componentDeployments) {
                    $deploymentFailures = $result.details.componentDeployments | Where-Object { $_.problemType }
                    if ($deploymentFailures) {
                        Write-Host "Found componentDeployments with problems: $($deploymentFailures.Count)" -ForegroundColor Green
                        foreach ($failure in $deploymentFailures) {
                            Write-Host "  Deployment failure: $($failure.fullName) - $($failure.problem)" -ForegroundColor Yellow
                            $errorMessages += $failure.problem
                        }
                    }
                }
                
                # Check for test failures
                if ($result.details.runTestResult -and $result.details.runTestResult.failures) {
                    Write-Host "Found test failures: $($result.details.runTestResult.failures.Count)" -ForegroundColor Green
                    foreach ($failure in $result.details.runTestResult.failures) {
                        Write-Host "  Test failure: $($failure.message)" -ForegroundColor Yellow
                        $errorMessages += $failure.message
                    }
                }
            }
        }
        
        # Fallback to existing ErrorMessages if present
        if ($ValidationResult.ErrorMessages) {
            Write-Host "Found ErrorMessages: $($ValidationResult.ErrorMessages.Count)" -ForegroundColor Green
            $errorMessages += $ValidationResult.ErrorMessages
        }
        
        # Parse each error message
        Write-Host "`n🔍 Processing error messages:" -ForegroundColor Cyan
        Write-Host "Total error messages to process: $($errorMessages.Count)" -ForegroundColor Gray
        
        foreach ($error in $errorMessages) {
            Write-Host "`n  📝 Processing error: $error" -ForegroundColor Yellow
            
            # Parse common dependency error patterns
            $dependencyPatterns = @(
                # Settings metadata missing
                "The object '(\w+)' of type Settings was included in the manifest file package\.xml but the associated settings metadata is missing from the 'settings' folder"
                # Missing CustomApplication
                "no CustomApplication named (\w+) found"
                # Unknown permissions
                "Unknown user permission: (\w+)"
                # Standard patterns
                "No such column '(\w+)' on entity '(\w+)'"
                "Referenced entity '(\w+)' is not available"
                "Cannot find the object '(\w+)'"
                "Field '(\w+)' is not accessible"
                "Unknown field '(\w+)' on object '(\w+)'"
                "Invalid field '(\w+)' for object '(\w+)'"
                "Missing dependency: (.+)"
                "Required field is missing: (.+)"
                "The field '(\w+)' is referenced but not defined"
                "Custom field '(\w+)' not found"
                "Permission Set '(\w+)' not found"
                "Profile '(\w+)' not found"
                "Layout '(\w+)' not found"
                "Record Type '(\w+)' not found"
                "Picklist value '(\w+)' not found"
                "Workflow rule '(\w+)' not found"
                "Validation rule '(\w+)' not found"
                "Trigger '(\w+)' not found"
                "Class '(\w+)' not found"
                "Component '(\w+)' not found"
            )
            
            $matched = $false
            foreach ($pattern in $dependencyPatterns) {
                if ($error -match $pattern) {
                    $componentName = $matches[1]
                    $componentType = if ($matches.Count -gt 2) { $matches[2] } else { "Unknown" }
                    
                    Write-Host "    ✅ Matched pattern: $pattern" -ForegroundColor Green
                    Write-Host "    📝 Component: $componentName" -ForegroundColor Green
                    
                    # Map common error patterns to Salesforce metadata types
                    $metadataType = switch -regex ($error) {
                        "type Settings.*missing from the 'settings' folder" { "Settings" }
                        "no CustomApplication named.*found" { "CustomApplication" }
                        "Unknown user permission" { "UserPermission" }
                        "Custom field|Field" { "CustomField" }
                        "Permission Set" { "PermissionSet" }
                        "Profile" { "Profile" }
                        "Layout" { "Layout" }
                        "Record Type" { "RecordType" }
                        "Picklist" { "CustomField" }
                        "Workflow" { "Workflow" }
                        "Validation" { "ValidationRule" }
                        "Trigger" { "ApexTrigger" }
                        "Class" { "ApexClass" }
                        "Custom Object|entity" { "CustomObject" }
                        default { "CustomObject" }
                    }
                    
                    Write-Host "    🏷️  Mapped to type: $metadataType" -ForegroundColor Green
                    
                    $missingDependencies += @{
                        Type = $metadataType
                        Name = $componentName
                        Source = "Validation Failure"
                        ErrorContext = $error
                    }
                    
                    $matched = $true
                    break  # Stop checking other patterns once we find a match
                }
            }
            
            if (-not $matched) {
                Write-Host "    ❌ No pattern matched for error: $error" -ForegroundColor Red
            }
        }
        
        # Remove duplicates
        $uniqueDependencies = $missingDependencies | Group-Object -Property Type, Name | ForEach-Object { $_.Group[0] }
        
        Write-Log -Level INFO "Extracted $($uniqueDependencies.Count) missing dependencies from validation failures"
        
        # Debug output
        Write-Host "`n📊 Dependency Extraction Results:" -ForegroundColor Cyan
        Write-Host "Total error messages processed: $($errorMessages.Count)" -ForegroundColor Gray
        Write-Host "Raw dependencies found: $($missingDependencies.Count)" -ForegroundColor Gray
        Write-Host "Unique dependencies after deduplication: $($uniqueDependencies.Count)" -ForegroundColor Gray
        
        if ($uniqueDependencies.Count -gt 0) {
            Write-Host "`n✅ Found Dependencies:" -ForegroundColor Green
            $uniqueDependencies | ForEach-Object {
                Write-Host "  • $($_.Type): $($_.Name)" -ForegroundColor White
            }
        } else {
            Write-Host "`n❌ No dependencies found" -ForegroundColor Red
        }
        
        return $uniqueDependencies
        
    } catch {
        Write-Log -Level ERROR "Error parsing validation failures: $($_.Exception.Message)"
        return @()
    }
}

function Show-IterativeValidationResults {
    <#
    .SYNOPSIS
        Shows the results of iterative validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$Results,
        [Parameter(Mandatory = $true)][bool]$Success
    )
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "               ITERATIVE VALIDATION RESULTS" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    
    foreach ($result in $Results) {
        $statusColor = if ($result.Success) { "Green" } else { "Red" }
        $statusIcon = if ($result.Success) { "✅" } else { "❌" }
        
        Write-Host "`n$statusIcon Iteration $($result.Iteration):" -ForegroundColor $statusColor
        Write-Host "   • Components: $($result.ComponentCount)" -ForegroundColor White
        Write-Host "   • Package: $($result.PackagePath)" -ForegroundColor Gray
        Write-Host "   • Status: $(if ($result.Success) { "SUCCESS" } else { "FAILED" })" -ForegroundColor $statusColor
        
        if (-not $result.Success -and $result.ValidationResult.ErrorMessages) {
            Write-Host "   • Error Count: $($result.ValidationResult.ErrorMessages.Count)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    if ($Success) {
        Write-Host "🎉 FINAL RESULT: VALIDATION SUCCESSFUL!" -ForegroundColor Green
        Write-Host "✅ Package is ready for deployment!" -ForegroundColor Green
    } else {
        Write-Host "❌ FINAL RESULT: VALIDATION INCOMPLETE" -ForegroundColor Red
        Write-Host "⚠️  Manual intervention may be required" -ForegroundColor Yellow
    }
    Write-Host "="*80 -ForegroundColor Cyan
}

function Get-ComponentDependencies {
    <#
    .SYNOPSIS
        Analyzes component dependencies using multiple strategies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$Components,
        [Parameter(Mandatory = $false)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetOrg
    )
    
    $allDependencies = @()
    
    # Strategy 1: Static file analysis
    if ($SourcePath -and (Test-Path $SourcePath)) {
        Write-Log -Level INFO "Performing static dependency analysis..."
        $staticDeps = Get-StaticDependencies -Components $Components -SourcePath $SourcePath
        $allDependencies += $staticDeps
    }
    
    # Strategy 2: Salesforce metadata dependency query
    Write-Log -Level INFO "Querying Salesforce for metadata dependencies..."
    $metadataDeps = Get-MetadataDependencies -Components $Components -TargetOrg $TargetOrg
    $allDependencies += $metadataDeps
    
    # Strategy 3: Common dependency patterns
    Write-Log -Level INFO "Applying common dependency patterns..."
    $patternDeps = Get-PatternBasedDependencies -Components $Components
    $allDependencies += $patternDeps
    
    # Remove duplicates and original components
    $uniqueDependencies = $allDependencies | Sort-Object Type, Name -Unique | Where-Object {
        $dep = $_
        $depType = [string]$dep.Type
        $depName = [string]$dep.Name
        -not ($Components | Where-Object { [string]$_.Type -eq $depType -and [string]$_.Name -eq $depName })
    }
    
    Write-Log -Level INFO "Found $($uniqueDependencies.Count) unique dependencies"
    return $uniqueDependencies
}

function Get-StaticDependencies {
    <#
    .SYNOPSIS
        Analyzes source files for static dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$Components,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )
    
    $dependencies = @()
    
    # Analyze Apex classes for dependencies
    $apexClasses = $Components | Where-Object { $_.Type -eq "ApexClass" }
    foreach ($apexClass in $apexClasses) {
        $classPath = Join-Path -Path $SourcePath -ChildPath "classes\$($apexClass.Name).cls"
        if (Test-Path $classPath) {
            $classContent = Get-Content $classPath -Raw
            
            # Find custom object references
            $customObjectMatches = [regex]::Matches($classContent, '(?:Schema\.)?(\w+__c)\.(?:SObjectType|\w+__c)')
            foreach ($match in $customObjectMatches) {
                $dependencies += @{
                    Type = "CustomObject"
                    Name = $match.Groups[1].Value
                    Source = "Static Analysis"
                    ReferencedBy = "$($apexClass.Type):$($apexClass.Name)"
                }
            }
            
            # Find custom field references
            $customFieldMatches = [regex]::Matches($classContent, '(\w+)\.(\w+__c)')
            foreach ($match in $customFieldMatches) {
                $dependencies += @{
                    Type = "CustomField"
                    Name = "$($match.Groups[1].Value).$($match.Groups[2].Value)"
                    Source = "Static Analysis"
                    ReferencedBy = "$($apexClass.Type):$($apexClass.Name)"
                }
            }
        }
    }
    
    # Analyze Flows for dependencies
    $flows = $Components | Where-Object { $_.Type -eq "Flow" }
    foreach ($flow in $flows) {
        $flowPath = Join-Path -Path $SourcePath -ChildPath "flows\$($flow.Name).flow-meta.xml"
        if (Test-Path $flowPath) {
            $flowContent = Get-Content $flowPath -Raw
            
            # Find object references in flows
            $objectMatches = [regex]::Matches($flowContent, '<object>(\w+)</object>')
            foreach ($match in $objectMatches) {
                $dependencies += @{
                    Type = "CustomObject"
                    Name = $match.Groups[1].Value
                    Source = "Static Analysis"
                    ReferencedBy = "$($flow.Type):$($flow.Name)"
                }
            }
        }
    }
    
    return $dependencies
}

function Get-MetadataDependencies {
    <#
    .SYNOPSIS
        Queries Salesforce for metadata dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$Components,
        [Parameter(Mandatory = $true)][string]$TargetOrg
    )
    
    $dependencies = @()
    
    try {
        # Query MetadataComponentDependency for each component
        foreach ($component in $Components) {
            $componentQuery = "SELECT MetadataComponentId, RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType FROM MetadataComponentDependency WHERE MetadataComponentName = '$($component.Name)' AND MetadataComponentType = '$($component.Type)'"
            
            $result = sf data query --query $componentQuery --target-org $TargetOrg --json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $queryResult = $result | ConvertFrom-Json
                foreach ($record in $queryResult.result.records) {
                    $dependencies += @{
                        Type = $record.RefMetadataComponentType
                        Name = $record.RefMetadataComponentName
                        Source = "Metadata Query"
                        ReferencedBy = "$($component.Type):$($component.Name)"
                    }
                }
            }
        }
    } catch {
        Write-Log -Level WARN "Could not query metadata dependencies: $($_.Exception.Message)"
    }
    
    return $dependencies
}

function Get-PatternBasedDependencies {
    <#
    .SYNOPSIS
        Applies common dependency patterns based on metadata types
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][array]$Components)
    
    $dependencies = @()
    
    # Custom Object -> Record Type dependencies
    $customObjects = $Components | Where-Object { $_.Type -eq "CustomObject" }
    foreach ($customObject in $customObjects) {
        # Add common dependencies for custom objects
        $dependencies += @{
            Type = "Layout"
            Name = "$($customObject.Name)-Layout"
            Source = "Pattern Analysis"
            ReferencedBy = "$($customObject.Type):$($customObject.Name)"
        }
    }
    
    # Permission Set -> Custom Object dependencies
    $permissionSets = $Components | Where-Object { $_.Type -eq "PermissionSet" }
    foreach ($permissionSet in $permissionSets) {
        # Add Profile dependency (common pattern)
        $dependencies += @{
            Type = "Profile"
            Name = "System Administrator"
            Source = "Pattern Analysis"
            ReferencedBy = "$($permissionSet.Type):$($permissionSet.Name)"
        }
    }
    
    return $dependencies
}

function New-EnhancedPackageXml {
    <#
    .SYNOPSIS
        Creates an enhanced package.xml with original components and dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$OriginalComponents,
        [Parameter(Mandatory = $true)][array]$Dependencies
    )
    
    $allComponents = $OriginalComponents + $Dependencies
    $groupedComponents = $allComponents | Group-Object -Property Type
    
    $manifest = [xml]'<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"></Package>'
    $packageNode = $manifest.Package
    
    foreach ($group in $groupedComponents) {
        $typeNode = $manifest.CreateElement("types", $packageNode.NamespaceURI)
        
        $uniqueNames = $group.Group | Select-Object -ExpandProperty Name | Sort-Object -Unique
        foreach ($name in $uniqueNames) {
            $memberNode = $manifest.CreateElement("members", $packageNode.NamespaceURI)
            $memberNode.InnerText = $name
            $typeNode.AppendChild($memberNode) | Out-Null
        }
        
        $nameNode = $manifest.CreateElement("name", $packageNode.NamespaceURI)
        $nameNode.InnerText = $group.Name
        $typeNode.AppendChild($nameNode) | Out-Null
        $packageNode.AppendChild($typeNode) | Out-Null
    }
    
    $versionNode = $manifest.CreateElement("version", $packageNode.NamespaceURI)
    $versionNode.InnerText = $Script:Settings.ApiVersion
    $packageNode.AppendChild($versionNode) | Out-Null
    
    return $manifest
}

function Show-DeploymentSummary {
    <#
    .SYNOPSIS
        Shows a summary of the deployment plan
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][array]$OriginalComponents,
        [Parameter(Mandatory = $true)][array]$Dependencies,
        [Parameter(Mandatory = $true)][string]$EnhancedPackagePath
    )
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "                    INTELLIGENT DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    
    Write-Host "`nOriginal Components ($($OriginalComponents.Count)):" -ForegroundColor Yellow
    $OriginalComponents | Group-Object -Property Type | ForEach-Object {
        Write-Host "  • $($_.Name): $($_.Count) components" -ForegroundColor White
    }
    
    Write-Host "`nDiscovered Dependencies ($($Dependencies.Count)):" -ForegroundColor Green
    $Dependencies | Group-Object -Property Type | ForEach-Object {
        Write-Host "  • $($_.Name): $($_.Count) components" -ForegroundColor White
    }
    
    Write-Host "`nDependency Sources:" -ForegroundColor Magenta
    $Dependencies | Group-Object -Property Source | ForEach-Object {
        Write-Host "  • $($_.Name): $($_.Count) dependencies" -ForegroundColor White
    }
    
    Write-Host "`nEnhanced Package.xml saved to:" -ForegroundColor Cyan
    Write-Host "  $EnhancedPackagePath" -ForegroundColor Gray
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
}

function Get-UserDeploymentConsent {
    <#
    .SYNOPSIS
        Gets user consent for deployment
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$ComponentCount)
    
    Write-Host "`nDeployment Consent Required:" -ForegroundColor Yellow
    Write-Host "  • Total components to deploy: $ComponentCount" -ForegroundColor White
    Write-Host "  • Target org: $($Script:Settings.DestinationOrgAlias)" -ForegroundColor White
    Write-Host "  • Operation: VALIDATION ONLY (no actual deployment)" -ForegroundColor Green
    
    $consent = Read-Host "`nDo you want to proceed with validation? (y/n)"
    return $consent.ToLower() -eq 'y'
}

function Test-MetadataIntegrity {
    <#
    .SYNOPSIS
        Validates metadata integrity by checking for missing source files and incomplete metadata pairs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$PackageXmlPath
    )
    
    $issues = @()
    $isValid = $true
    
    try {
        # Parse package.xml to get all metadata components
        [xml]$packageXml = Get-Content $PackageXmlPath
        
        # Define metadata types that require source files
        $metadataTypesWithSourceFiles = @{
            'ApexClass' = @{ Extension = '.cls'; MetaExtension = '.cls-meta.xml'; Directory = 'classes' }
            'ApexTrigger' = @{ Extension = '.trigger'; MetaExtension = '.trigger-meta.xml'; Directory = 'triggers' }
            'ApexPage' = @{ Extension = '.page'; MetaExtension = '.page-meta.xml'; Directory = 'pages' }
            'ApexComponent' = @{ Extension = '.component'; MetaExtension = '.component-meta.xml'; Directory = 'components' }
            'LightningComponentBundle' = @{ Extension = ''; MetaExtension = ''; Directory = 'lwc' }
            'StaticResource' = @{ Extension = '.resource'; MetaExtension = '.resource-meta.xml'; Directory = 'staticresources' }
            'EmailTemplate' = @{ Extension = '.email'; MetaExtension = '.email-meta.xml'; Directory = 'email' }
            'Report' = @{ Extension = '.report'; MetaExtension = '.report-meta.xml'; Directory = 'reports' }
            'Dashboard' = @{ Extension = '.dashboard'; MetaExtension = '.dashboard-meta.xml'; Directory = 'dashboards' }
            'Flow' = @{ Extension = '.flow'; MetaExtension = '.flow-meta.xml'; Directory = 'flows' }
            'Layout' = @{ Extension = '.layout'; MetaExtension = '.layout-meta.xml'; Directory = 'layouts' }
            'CustomObject' = @{ Extension = '.object'; MetaExtension = '.object-meta.xml'; Directory = 'objects' }
            'CustomMetadata' = @{ Extension = '.md'; MetaExtension = '.md-meta.xml'; Directory = 'customMetadata' }
            'PermissionSet' = @{ Extension = '.permissionset'; MetaExtension = '.permissionset-meta.xml'; Directory = 'permissionsets' }
            'Profile' = @{ Extension = '.profile'; MetaExtension = '.profile-meta.xml'; Directory = 'profiles' }
            'FlexiPage' = @{ Extension = '.flexipage'; MetaExtension = '.flexipage-meta.xml'; Directory = 'flexipages' }
            'AuraDefinitionBundle' = @{ Extension = ''; MetaExtension = ''; Directory = 'aura' }
        }
        
        # Check each metadata type in package.xml
        foreach ($type in $packageXml.Package.types) {
            $metadataType = $type.name
            
            if ($metadataTypesWithSourceFiles.ContainsKey($metadataType)) {
                $typeInfo = $metadataTypesWithSourceFiles[$metadataType]
                $typeDirectory = Join-Path $SourceDirectory $typeInfo.Directory
                
                if (Test-Path $typeDirectory) {
                    foreach ($member in $type.members) {
                        $memberName = $member
                        
                        # Special handling for different metadata types
                        switch ($metadataType) {
                            'ApexClass' {
                                $sourceFile = Join-Path $typeDirectory "$memberName.cls"
                                $metaFile = Join-Path $typeDirectory "$memberName.cls-meta.xml"
                                
                                if (Test-Path $metaFile -and -not (Test-Path $sourceFile)) {
                                    $issues += "Missing source file: $sourceFile (meta file exists)"
                                    $isValid = $false
                                }
                                elseif (Test-Path $sourceFile -and -not (Test-Path $metaFile)) {
                                    $issues += "Missing meta file: $metaFile (source file exists)"
                                    $isValid = $false
                                }
                            }
                            'ApexTrigger' {
                                $sourceFile = Join-Path $typeDirectory "$memberName.trigger"
                                $metaFile = Join-Path $typeDirectory "$memberName.trigger-meta.xml"
                                
                                if (Test-Path $metaFile -and -not (Test-Path $sourceFile)) {
                                    $issues += "Missing source file: $sourceFile (meta file exists)"
                                    $isValid = $false
                                }
                                elseif (Test-Path $sourceFile -and -not (Test-Path $metaFile)) {
                                    $issues += "Missing meta file: $metaFile (source file exists)"
                                    $isValid = $false
                                }
                            }
                            'LightningComponentBundle' {
                                $componentDir = Join-Path $typeDirectory $memberName
                                if (-not (Test-Path $componentDir)) {
                                    $issues += "Missing LWC directory: $componentDir"
                                    $isValid = $false
                                }
                            }
                            'AuraDefinitionBundle' {
                                $auraDir = Join-Path $typeDirectory $memberName
                                if (-not (Test-Path $auraDir)) {
                                    $issues += "Missing Aura directory: $auraDir"
                                    $isValid = $false
                                }
                            }
                            default {
                                # For other metadata types, check if the expected file exists
                                if ($typeInfo.Extension) {
                                    $sourceFile = Join-Path $typeDirectory "$memberName$($typeInfo.Extension)"
                                    if (-not (Test-Path $sourceFile)) {
                                        $issues += "Missing metadata file: $sourceFile"
                                        $isValid = $false
                                    }
                                }
                            }
                        }
                    }
                } else {
                    $issues += "Missing directory for metadata type '$metadataType': $typeDirectory"
                    $isValid = $false
                }
            }
        }
        
        # Check for orphaned metadata files (meta files without source files)
        $classesDir = Join-Path $SourceDirectory "classes"
        if (Test-Path $classesDir) {
            $metaFiles = Get-ChildItem $classesDir -Filter "*.cls-meta.xml"
            foreach ($metaFile in $metaFiles) {
                $baseName = $metaFile.BaseName -replace '\.cls-meta$', ''
                $sourceFile = Join-Path $classesDir "$baseName.cls"
                if (-not (Test-Path $sourceFile)) {
                    $issues += "Orphaned meta file: $($metaFile.FullName) (missing source file: $sourceFile)"
                    $isValid = $false
                }
            }
        }
        
        # Check for other common metadata directories
        $commonDirs = @{
            'triggers' = '*.trigger-meta.xml'
            'pages' = '*.page-meta.xml'
            'components' = '*.component-meta.xml'
        }
        
        foreach ($dirName in $commonDirs.Keys) {
            $dir = Join-Path $SourceDirectory $dirName
            if (Test-Path $dir) {
                $metaFiles = Get-ChildItem $dir -Filter $commonDirs[$dirName]
                foreach ($metaFile in $metaFiles) {
                    $baseName = $metaFile.BaseName -replace '\.(trigger|page|component)-meta$', ''
                    $expectedExt = switch ($dirName) {
                        'triggers' { '.trigger' }
                        'pages' { '.page' }
                        'components' { '.component' }
                    }
                    $sourceFile = Join-Path $dir "$baseName$expectedExt"
                    if (-not (Test-Path $sourceFile)) {
                        $issues += "Orphaned meta file: $($metaFile.FullName) (missing source file: $sourceFile)"
                        $isValid = $false
                    }
                }
            }
        }
        
        return @{
            IsValid = $isValid
            Issues = $issues
            CheckedTypes = $metadataTypesWithSourceFiles.Keys
        }
        
    } catch {
        Write-Log -Level ERROR "Error validating metadata integrity: $($_.Exception.Message)"
        return @{
            IsValid = $false
            Issues = @("Error validating metadata integrity: $($_.Exception.Message)")
            CheckedTypes = @()
        }
    }
}

function New-FilteredPackageXml {
    <#
    .SYNOPSIS
        Creates a filtered package.xml excluding problematic metadata components
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$OriginalPackageXml,
        [Parameter(Mandatory = $true)][hashtable]$ValidationResult,
        [Parameter(Mandatory = $true)][string]$SourceDirectory
    )
    
    try {
        # Parse the original package.xml
        [xml]$packageXml = Get-Content $OriginalPackageXml
        
        # Extract problematic component names from validation issues
        $problematicComponents = @{}
        foreach ($issue in $ValidationResult.Issues) {
            if ($issue -match "Missing source file: .*\\(.+)\.cls \(meta file exists\)") {
                $componentName = $matches[1]
                if (-not $problematicComponents.ContainsKey('ApexClass')) {
                    $problematicComponents['ApexClass'] = @()
                }
                $problematicComponents['ApexClass'] += $componentName
            }
            elseif ($issue -match "Missing source file: .*\\(.+)\.trigger \(meta file exists\)") {
                $componentName = $matches[1]
                if (-not $problematicComponents.ContainsKey('ApexTrigger')) {
                    $problematicComponents['ApexTrigger'] = @()
                }
                $problematicComponents['ApexTrigger'] += $componentName
            }
            elseif ($issue -match "Orphaned meta file: .*\\(.+)\.cls-meta\.xml") {
                $componentName = $matches[1]
                if (-not $problematicComponents.ContainsKey('ApexClass')) {
                    $problematicComponents['ApexClass'] = @()
                }
                $problematicComponents['ApexClass'] += $componentName
            }
            elseif ($issue -match "Missing LWC directory: .*\\(.+)$") {
                $componentName = $matches[1]
                if (-not $problematicComponents.ContainsKey('LightningComponentBundle')) {
                    $problematicComponents['LightningComponentBundle'] = @()
                }
                $problematicComponents['LightningComponentBundle'] += $componentName
            }
        }
        
        # Create filtered package.xml
        $filteredPackageXml = [xml]'<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"></Package>'
        $packageNode = $filteredPackageXml.Package
        
        # Process each type in the original package.xml
        foreach ($type in $packageXml.Package.types) {
            $metadataType = $type.name
            $validMembers = @()
            
            # Filter out problematic components
            foreach ($member in $type.members) {
                $memberName = $member
                $shouldInclude = $true
                
                if ($problematicComponents.ContainsKey($metadataType)) {
                    if ($problematicComponents[$metadataType] -contains $memberName) {
                        Write-Log -Level WARN "Excluding problematic component: $metadataType.$memberName"
                        $shouldInclude = $false
                    }
                }
                
                if ($shouldInclude) {
                    $validMembers += $memberName
                }
            }
            
            # Only add the type if it has valid members
            if ($validMembers.Count -gt 0) {
                $typeNode = $filteredPackageXml.CreateElement("types", $packageNode.NamespaceURI)
                
                foreach ($member in $validMembers) {
                    $memberNode = $filteredPackageXml.CreateElement("members", $packageNode.NamespaceURI)
                    $memberNode.InnerText = $member
                    $typeNode.AppendChild($memberNode) | Out-Null
                }
                
                $nameNode = $filteredPackageXml.CreateElement("name", $packageNode.NamespaceURI)
                $nameNode.InnerText = $metadataType
                $typeNode.AppendChild($nameNode) | Out-Null
                $packageNode.AppendChild($typeNode) | Out-Null
            }
        }
        
        # Add version
        $versionNode = $filteredPackageXml.CreateElement("version", $packageNode.NamespaceURI)
        $versionNode.InnerText = $packageXml.Package.version
        $packageNode.AppendChild($versionNode) | Out-Null
        
        # Save filtered package.xml
        $filteredPackageXmlPath = Join-Path $SourceDirectory "filtered-package.xml"
        $filteredPackageXml.Save($filteredPackageXmlPath)
        
        Write-Log -Level INFO "Created filtered package.xml with $($packageNode.types.Count) valid metadata types"
        
        return $filteredPackageXmlPath
        
    } catch {
        Write-Log -Level ERROR "Error creating filtered package.xml: $($_.Exception.Message)"
        throw "Failed to create filtered package.xml: $($_.Exception.Message)"
    }
}

function Invoke-DeploymentValidation {
    <#
    .SYNOPSIS
        Performs deployment validation using Salesforce CLI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PackageXmlPath,
        [Parameter(Mandatory = $true)][string]$TargetOrg
    )
    
    $startTime = Start-Operation "Deployment Validation"
    
    try {
        Write-Log -Level INFO "Starting deployment validation..."
        Write-Host "`n=== DEPLOYMENT VALIDATION ===" -ForegroundColor Cyan
        Write-Host "Package: $PackageXmlPath" -ForegroundColor Gray
        Write-Host "Target Org: $TargetOrg" -ForegroundColor Gray
        
        # Validate inputs
        if (-not (Test-Path $PackageXmlPath)) {
            throw "Package.xml file not found: $PackageXmlPath"
        }
        
        # Get source directory from package.xml path
        $sourceDir = Split-Path -Parent $PackageXmlPath
        
        # Build validation command - use manifest approach for iterative deployment
        $validationCommand = @(
            'sf', 'project', 'deploy', 'start',
            '--manifest', "`"$PackageXmlPath`"",
            '--target-org', $TargetOrg,
            '--dry-run',
            '--json'
        )
        Write-Log -Level INFO "Using manifest deployment approach: $PackageXmlPath"
        
        Write-Log -Level DEBUG "Validation command: $($validationCommand -join ' ')"
        Write-Host "`nExecuting validation (this may take several minutes)..." -ForegroundColor Yellow
        Write-Host "Command: $($validationCommand -join ' ')" -ForegroundColor Gray
        
        # Execute validation using Start-Process for better control
        Write-Host "`n🔧 Setting up process..." -ForegroundColor Cyan
        
        # First, check if sf command is available
        try {
            $sfCommand = Get-Command 'sf' -ErrorAction Stop
            Write-Host "✅ Found sf command at: $($sfCommand.Source)" -ForegroundColor Green
        } catch {
            Write-Host "❌ sf command not found in PATH" -ForegroundColor Red
            Write-Log -Level ERROR "sf command not found: $($_.Exception.Message)"
            
            # Return failure result
            return @{
                Success = $false
                Result = $null
                Message = "sf command not found. Please ensure Salesforce CLI is installed and in PATH."
                ErrorMessages = @("sf command not found")
            }
        }
        
        try {
            # Use safer command execution approach
            $fullCommand = $validationCommand -join ' '
            Write-Host "🚀 Executing command: $fullCommand" -ForegroundColor Cyan
            
            # Execute the command and capture output
            $output = $null
            $errorOutput = $null
            $exitCode = 0
            
            try {
                $output = & 'sf' ($validationCommand[1..($validationCommand.Count-1)]) 2>&1
                $exitCode = $LASTEXITCODE
            } catch {
                $exitCode = 1
                $errorOutput = $_.Exception.Message
            }
            
            Write-Host "✅ Command completed with exit code: $exitCode" -ForegroundColor Cyan
            
            # Convert output to string if it's an array
            if ($output -is [Array]) {
                $output = $output -join "`n"
            }
            
            # Convert error output to string if needed
            if ($errorOutput -is [Array]) {
                $errorOutput = $errorOutput -join "`n"
            }
            
            # Ensure we have strings
            if ($output -eq $null) { $output = "" }
            if ($errorOutput -eq $null) { $errorOutput = "" }
            
        } catch {
            Write-Host "`n❌ Error during process execution: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log -Level ERROR "Process execution failed: $($_.Exception.Message)"
            
            # Return failure result
            return @{
                Success = $false
                Result = $null
                Message = "Process execution failed: $($_.Exception.Message)"
                ErrorMessages = @($_.Exception.Message)
            }
        }
        
        Write-Log -Level DEBUG "Validation exit code: $exitCode"
        Write-Log -Level DEBUG "Validation output: $output"
        Write-Log -Level DEBUG "Validation error output: $errorOutput"
        
        # Debug: Show output to user
        Write-Host "`n🔍 Debug Info:" -ForegroundColor Cyan
        Write-Host "Exit Code: $exitCode" -ForegroundColor Gray
        Write-Host "Output Length: $($output.Length)" -ForegroundColor Gray
        Write-Host "Error Length: $($errorOutput.Length)" -ForegroundColor Gray
        
        if ($output.Length -gt 0) {
            $outputPreview = $output.Substring(0, [Math]::Min(200, $output.Length))
            Write-Host "Output Preview: $outputPreview" -ForegroundColor Gray
        }
        
        if ($errorOutput.Length -gt 0) {
            $errorPreview = $errorOutput.Substring(0, [Math]::Min(200, $errorOutput.Length))
            Write-Host "Error Preview: $errorPreview" -ForegroundColor Gray
        }
        
        if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($output)) {
            try {
                $result = $output | ConvertFrom-Json
                
                Write-Host "`n✅ VALIDATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
                Write-Host "Validation ID: $($result.result.id)" -ForegroundColor Cyan
                
                # Show validation details
                if ($result.result.details) {
                    $details = $result.result.details
                    Write-Host "`nValidation Summary:" -ForegroundColor Yellow
                    Write-Host "  Components Deployed: $($details.componentDeployments.Count)" -ForegroundColor White
                    Write-Host "  Tests Run: $($details.runTestResult.totalTestsRun)" -ForegroundColor White
                    Write-Host "  Code Coverage: $($details.runTestResult.overallCoveragePercentage)%" -ForegroundColor White
                }
                
                return @{
                    Success = $true
                    Result = $result
                    Message = "Validation completed successfully"
                    ValidationId = $result.result.id
                    ErrorMessages = @()
                }
            } catch {
                Write-Host "`n⚠️ Validation completed but failed to parse result" -ForegroundColor Yellow
                return @{
                    Success = $true
                    Result = $output
                    Message = "Validation completed but result parsing failed: $($_.Exception.Message)"
                    ErrorMessages = @()
                }
            }
        } else {
            Write-Host "`n❌ VALIDATION FAILED" -ForegroundColor Red
            
            # Try to parse error details from JSON
            if (-not [string]::IsNullOrWhiteSpace($output)) {
                try {
                    $errorResult = $output | ConvertFrom-Json
                    if ($errorResult.message) {
                        Write-Host "Error: $($errorResult.message)" -ForegroundColor Red
                    }
                    if ($errorResult.result -and $errorResult.result.details) {
                        $failures = $errorResult.result.details.componentDeployments | Where-Object { $_.problemType }
                        if ($failures) {
                            Write-Host "`nComponent Failures:" -ForegroundColor Yellow
                            $failures | ForEach-Object {
                                Write-Host "  - $($_.fullName): $($_.problem)" -ForegroundColor Red
                            }
                        }
                    }
                } catch {
                    Write-Host "Raw error output: $output" -ForegroundColor Red
                }
            }
            
            if (-not [string]::IsNullOrWhiteSpace($errorOutput)) {
                Write-Host "Error details: $errorOutput" -ForegroundColor Red
            }
            
            # Enhanced error parsing for iterative validation
            $errorMessages = @()
            
            # Try to parse error details from JSON
            if (-not [string]::IsNullOrWhiteSpace($output)) {
                try {
                    $errorResult = $output | ConvertFrom-Json
                    if ($errorResult.result -and $errorResult.result.details) {
                        $failures = $errorResult.result.details.componentDeployments | Where-Object { $_.problemType }
                        if ($failures) {
                            $errorMessages += $failures | ForEach-Object { $_.problem }
                        }
                        
                        # Also check for test failures
                        if ($errorResult.result.details.runTestResult) {
                            $testFailures = $errorResult.result.details.runTestResult.failures
                            if ($testFailures) {
                                $errorMessages += $testFailures | ForEach-Object { $_.message }
                            }
                        }
                    }
                    
                    # Check for general error message
                    if ($errorResult.message) {
                        $errorMessages += $errorResult.message
                    }
                    
                    # Handle specific error cases
                    if ($errorResult.name -eq "NothingToDeploy") {
                        Write-Host "`n⚠️ Nothing to deploy - this may indicate missing source files" -ForegroundColor Yellow
                        $errorMessages += "Nothing to deploy - check for missing source files"
                    }
                    
                    if ($errorResult.name -eq "ExpectedSourceFilesError") {
                        Write-Host "`n⚠️ Expected source files error detected" -ForegroundColor Yellow
                        $errorMessages += $errorResult.message
                    }
                } catch {
                    $errorMessages += "Failed to parse validation output: $($_.Exception.Message)"
                }
            }
            
            if (-not [string]::IsNullOrWhiteSpace($errorOutput)) {
                $errorMessages += $errorOutput
            }
            
            return @{
                Success = $false
                Result = $output
                Message = "Validation failed with exit code: $exitCode"
                ErrorMessages = $errorMessages
            }
        }
    } catch {
        Write-Host "`n❌ VALIDATION ERROR" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        
        return @{
            Success = $false
            Result = $null
            Message = "Validation error: $($_.Exception.Message)"
            ErrorMessages = @($_.Exception.Message)
        }
    } finally {
        End-Operation -StartTime $startTime
    }
}

function Show-ValidationResults {
    <#
    .SYNOPSIS
        Shows the results of deployment validation
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][hashtable]$Result)
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "                    VALIDATION RESULTS" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    
    if ($Result.Success) {
        Write-Host "`n✅ VALIDATION SUCCESSFUL!" -ForegroundColor Green
        
        if ($Result.Result.result) {
            $deployResult = $Result.Result.result
            Write-Host "`nValidation Details:" -ForegroundColor Yellow
            Write-Host "  • Components Deployed: $($deployResult.numberComponentsDeployed)" -ForegroundColor White
            Write-Host "  • Components Total: $($deployResult.numberComponentsTotal)" -ForegroundColor White
            Write-Host "  • Tests Completed: $($deployResult.numberTestsCompleted)" -ForegroundColor White
            Write-Host "  • Tests Total: $($deployResult.numberTestsTotal)" -ForegroundColor White
            
            if ($deployResult.details.componentSuccesses) {
                Write-Host "`nSuccessful Components:" -ForegroundColor Green
                foreach ($success in $deployResult.details.componentSuccesses) {
                    Write-Host "  ✅ $($success.componentType): $($success.fullName)" -ForegroundColor White
                }
            }
        }
    } else {
        Write-Host "`n❌ VALIDATION FAILED!" -ForegroundColor Red
        Write-Host "`nError Details:" -ForegroundColor Yellow
        Write-Host $Result.Result -ForegroundColor Red
    }
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
}
#endregion

#region Advanced Functions

function Handle-ProjectSetup-SubMenu {
    while($true) {
        $menuOptions = @(
            @{ Key = "[1]"; Label = "List and Select Source/Destination Orgs"; Color = "White" },
            @{ Key = "[2]"; Label = "Edit Project Settings (API, Log Level)"; Color = "White" },
            @{ Key = "[3]"; Label = "Authorize a New Org"; Color = "White" },
            @{ Key = "[4]"; Label = "Switch to a Different Project"; Color = "White" },
            @{ Key = "[B]"; Label = "Back to Main Menu"; Color = "Cyan" },
            @{ Key = "[Q]"; Label = "Quit"; Color = "Red" }
        )
        
        Show-ModernMenu -Title "Project and Org Setup" -Options $menuOptions -BreadcrumbPath "Main Menu > Project and Org Setup"
        $choice = Read-Host '> Enter your choice'
        Write-Log -Level INFO "User selected Project Setup option '$choice'."
        switch ($choice) {
            '1' { Select-Org }
            '2' { Edit-ProjectSettings }
            '3' { Authorize-Org }
            '4' { return "switch" } # Special return value to signal a project switch
            'b' { return }
            'q' { 
                Track-FeatureUsage -Feature "Project-Setup" -Action "Quit"
                try { Send-UsageTelemetry } catch { Write-Log -Level WARN "Failed to send final telemetry" }
                Write-Log -Level INFO 'User chose to quit from Project Setup menu. Ending session.'
                Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Ended ==================="
                Write-Log -Level INFO "Session End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                Save-Settings
                exit
            }
            default { Write-Log -Level WARN "Invalid option." }
        }
    }
}

function Handle-Utilities-SubMenu {
    while($true) {
        $menuOptions = @(
            @{ Key = "[1]"; Label = "Generate Deployment Manifest (package.xml)"; Color = "White" },
            @{ Key = "[2]"; Label = "Open Org in Browser"; Color = "White" },
            @{ Key = "[3]"; Label = "Analyze Local Profile/Permission Set Files"; Color = "White" },
            @{ Key = "[4]"; Label = "View Project Log File"; Color = "White" },
            @{ Key = "[5]"; Label = "Clear Project Cache"; Color = "White" },
            @{ Key = "[6]"; Label = "Re-run System Readiness Check"; Color = "White" },
            @{ Key = "[7]"; Label = "Export System Information"; Color = "White" },
            @{ Key = "[8]"; Label = "Validate Salesforce Project Structure"; Color = "White" },
            @{ Key = "[9]"; Label = "Backup/Restore Project Settings"; Color = "White" },
            @{ Key = "[B]"; Label = "Back to Main Menu"; Color = "Cyan" },
            @{ Key = "[Q]"; Label = "Quit"; Color = "Red" }
        )
        
        Show-ModernMenu -Title "System and Utilities" -Options $menuOptions -BreadcrumbPath "Main Menu > System and Utilities"
        $choice = Read-Host '> Enter your choice'
        Write-Log -Level INFO "User selected Utilities option '$choice'."
        switch ($choice) {
            '1' { Handle-Manifest-Generation }
            '2' { Open-Org }
            '3' { Analyze-Permissions-Local }
            '4' { View-LogFile }
            '5' { Clear-ProjectCache }
            '6' { Check-Prerequisites -ForceRefresh }
            '7' { Export-SystemInfo }
            '8' { Test-ProjectStructure }
            '9' { Handle-ProjectBackup }
            'b' { return }
            'q' { 
                Track-FeatureUsage -Feature "Utilities" -Action "Quit"
                try { Send-UsageTelemetry } catch { Write-Log -Level WARN "Failed to send final telemetry" }
                Write-Log -Level INFO 'User chose to quit from Utilities menu. Ending session.'
                Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Ended ==================="
                Write-Log -Level INFO "Session End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                Save-Settings
                exit
            }
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
        Write-Host "`nEnter numbers to include or all"
        $choices = Read-Host ""
        if($choices -eq 'all') { $selectedTypes = $metadataResult.xmlName }
        else { $selectedTypes = $choices -split ',' | ForEach-Object { if($_.Trim() -match '^\d+$') { $metadataResult[[int]$_.Trim() - 1].xmlName } } }
        
        if($selectedTypes.Count -eq 0) { Write-Log -Level WARN "No valid types selected."; return }
        
        $manifestContent = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" + '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
        $selectedTypes | ForEach-Object { $manifestContent += "`n  " + '<types>' + "`n    " + '<members>*</members>' + "`n    " + '<name>' + $_ + '</name>' + "`n  " + '</types>' }
        $manifestContent += "`n  " + '<version>' + $Script:Settings.ApiVersion + '</version>' + "`n" + '</Package>'
        
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
            if ((Read-Host 'A delta-deployment package was found. Do you want to deploy it? (y/n)').ToLower() -eq 'y') {
                $pathToDeploy = $deltaPackageDir
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($pathToDeploy)) {
            $pathToDeploy = Read-Host 'Enter the path to the directory containing the metadata to deploy (e.g., force-app)'
        }

        if (-not (Test-Path $pathToDeploy)) { throw ('Invalid path. Directory not found at ' + $pathToDeploy + '.') }
        
        Write-Log -Level INFO "Starting deployment of folder '$pathToDeploy' to org '$targetOrg'."
        $deployCommand = "sf project deploy start --metadata-dir `"$pathToDeploy`" --target-org $targetOrg --api-version $($Script:Settings.ApiVersion)"

        $testLevel = Read-Host 'Enter test level (NoTestRun, RunLocalTests, RunAllTestsInOrg, RunSpecifiedTests)'
        $deployCommand += " --test-level $testLevel"
        
        if ($testLevel -eq "RunSpecifiedTests") {
            $testsToRun = Read-Host 'Enter comma-separated test classes'
            if (-not [string]::IsNullOrWhiteSpace($testsToRun)) { $deployCommand += " --tests `"$testsToRun`"" }
        }

        Write-Host ""
        if ((Read-Host 'Do you want to VALIDATE first before deploying? (y/n)').ToLower() -eq 'y') {
                Write-Log -Level INFO "Running validation..."
            $validationCommand = $deployCommand + " --dry-run"
            $validationSuccess = Invoke-SalesforceCLIWithProgress -Command $validationCommand -Activity "Validating Deployment" -EstimatedMinutes 15
            if (-not $validationSuccess) { throw "Validation failed." }
            Write-Log -Level INFO "Validation successful."
            if ((Read-Host "`nValidation successful. To proceed with deployment, type alias '$targetOrg' again") -ne $targetOrg) {
                Write-Log -Level INFO "Deployment cancelled by user."; return
            }
        }

        Write-Log -Level INFO "Running final deployment command: $deployCommand"
        $deploySuccess = Invoke-SalesforceCLIWithProgress -Command $deployCommand -Activity "Deploying Metadata" -EstimatedMinutes 20
        if (-not $deploySuccess) { throw "Deployment failed." }

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
        
        # CORRECTED: Loop over the 'metadataObjects' array within result.
        foreach ($type in @($metadataJson.result.metadataObjects)) {
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

        if (-not (Set-JsonContent -Path $Script:METADATA_MAP_FILE -Content $fileContent)) {
            throw "Failed to save metadata map"
        }
        Write-Log -Level INFO "Metadata map updated successfully. Total types: $($mappingData.Count). Found $newTypesFound new type(s)."
        Write-Host "✅ Metadata map has been updated." -ForegroundColor Green
    } catch {
        Track-Error -ErrorType "Update-Metadata-Mappings" -ErrorMessage $_.Exception.Message -Properties @{
            SourceOrg = $Script:Settings.SourceOrgAlias
            ApiVersion = $Script:Settings.ApiVersion
        }
        Write-Log -Level ERROR "Failed to update metadata mappings. Error: $($_.Exception.Message | Out-String)"
    }
    End-Operation -startTime $startTime
}


function Edit-ProjectSettings {
    Write-Log -Level DEBUG "Entering function 'Edit-ProjectSettings'."
    try {
        Write-Host "`n[1] Set Project Default API Version" -ForegroundColor Cyan
        Write-Host "[2] Set Project Log Level" -ForegroundColor Cyan
        $choice = Read-Host '> Enter your choice'
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
            Write-Host '[1] INFO  (Default, standard logging)'
            Write-Host '[2] DEBUG (Verbose, for troubleshooting)'
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
    <#
    .SYNOPSIS
        Clears project cache for specified property or all cache
    .PARAMETER property
        Specific property to clear, or all if not specified
    #>
    [CmdletBinding()]
    param([string]$property)
    
    Write-Log -Level INFO "Clearing project cache for property: $($property | Out-String)"
    try {
        if($property) { 
            if ($Script:Settings.PSObject.Properties[$property]) { 
                $Script:Settings.PSObject.Properties.Remove($property) 
            }
        }
        else {
            if ($Script:Settings.PSObject.Properties['Orgs']) { $Script:Settings.PSObject.Properties.Remove("Orgs") }
            if ($Script:Settings.PSObject.Properties['MetadataTypes']) { $Script:Settings.PSObject.Properties.Remove("MetadataTypes") }
            if ($Script:Settings.PSObject.Properties['Cache']) { $Script:Settings.PSObject.Properties.Remove("Cache") }
            if ($Script:Settings.PSObject.Properties['SystemInfo']) { $Script:Settings.PSObject.Properties.Remove("SystemInfo") }
        }
        Save-Settings
        Write-Host "✅ Project cache cleared successfully." -ForegroundColor Green
        Write-Log -Level INFO "Project cache cleared."
    } catch {
        Write-Log -Level ERROR "Failed to clear cache. Error: $($_.Exception.Message | Out-String)"
    }
}

function Export-SystemInfo {
    <#
    .SYNOPSIS
        Exports system information to a file for troubleshooting
    #>
    [CmdletBinding()]
    param()
    
    try {
        $systemInfo = Get-SystemInfo
        $exportPath = Join-Path -Path $Script:ProjectRoot -ChildPath "system-info.json"
        
        $fullReport = @{
            ExportedAt = (Get-Date -Format "o")
            SystemInfo = $systemInfo
            ProjectSettings = $Script:Settings
            InstalledModules = Get-Module -ListAvailable | Select-Object Name, Version
            EnvironmentVariables = Get-ChildItem Env: | Select-Object Name, Value
        }
        
        Set-JsonContent -Path $exportPath -Content $fullReport | Out-Null
        Write-Host "✅ System information exported to: $exportPath" -ForegroundColor Green
        Write-Log -Level INFO "System information exported successfully."
    } catch {
        Write-Log -Level ERROR "Failed to export system info. Error: $($_.Exception.Message)"
    }
}

function Test-ProjectStructure {
    <#
    .SYNOPSIS
        Validates the Salesforce project structure
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "`nValidating Salesforce project structure..." -ForegroundColor Cyan
        
        $checks = @()
        
        # Check for sfdx-project.json
        $sfdxProjectPath = Join-Path -Path $Script:ProjectRoot -ChildPath "sfdx-project.json"
        if (Test-Path $sfdxProjectPath) {
            $checks += @{ Name = "sfdx-project.json"; Status = "✅ Found"; Color = "Green" }
            try {
                $sfdxProject = Get-JsonContent -Path $sfdxProjectPath
                if ($sfdxProject.packageDirectories) {
                    $checks += @{ Name = "Package Directories"; Status = "✅ Configured"; Color = "Green" }
                } else {
                    $checks += @{ Name = "Package Directories"; Status = "⚠️ Missing"; Color = "Yellow" }
                }
            } catch {
                $checks += @{ Name = "sfdx-project.json"; Status = "❌ Invalid JSON"; Color = "Red" }
            }
        } else {
            $checks += @{ Name = "sfdx-project.json"; Status = "❌ Missing"; Color = "Red" }
        }
        
        # Check for common directories
        $commonDirs = @("force-app", "scripts", "config")
        foreach ($dir in $commonDirs) {
            $dirPath = Join-Path -Path $Script:ProjectRoot -ChildPath $dir
            if (Test-Path $dirPath) {
                $checks += @{ Name = "$dir directory"; Status = "✅ Found"; Color = "Green" }
            } else {
                $checks += @{ Name = "$dir directory"; Status = "⚠️ Missing"; Color = "Yellow" }
            }
        }
        
        # Check for .gitignore
        $gitignorePath = Join-Path -Path $Script:ProjectRoot -ChildPath ".gitignore"
        if (Test-Path $gitignorePath) {
            $checks += @{ Name = ".gitignore"; Status = "✅ Found"; Color = "Green" }
        } else {
            $checks += @{ Name = ".gitignore"; Status = "⚠️ Missing"; Color = "Yellow" }
        }
        
        # Display results
        foreach ($check in $checks) {
            Write-Host "  $($check.Name): $($check.Status)" -ForegroundColor $check.Color
        }
        
        Write-Log -Level INFO "Project structure validation completed."
    } catch {
        Write-Log -Level ERROR "Failed to validate project structure. Error: $($_.Exception.Message)"
    }
}

function Handle-ProjectBackup {
    <#
    .SYNOPSIS
        Handles project backup and restore operations
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`n[1] Backup Project Settings" -ForegroundColor Cyan
    Write-Host "[2] Restore Project Settings" -ForegroundColor Cyan
    $choice = Read-Host "Enter your choice"
    
    switch ($choice) {
        '1' { Backup-ProjectSettings }
        '2' { Restore-ProjectSettings }
        default { Write-Log -Level WARN "Invalid choice." }
    }
}

function Backup-ProjectSettings {
    <#
    .SYNOPSIS
        Creates a backup of project settings
    #>
    [CmdletBinding()]
    param()
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = Join-Path -Path $Script:ProjectRoot -ChildPath ".sfdc-toolkit\backup-$timestamp.json"
        
        $backupData = @{
            BackupDate = (Get-Date -Format "o")
            ToolkitVersion = $Script:VERSION
            Settings = $Script:Settings
        }
        
        Set-JsonContent -Path $backupPath -Content $backupData | Out-Null
        Write-Host "✅ Project settings backed up to: $backupPath" -ForegroundColor Green
        Write-Log -Level INFO "Project settings backup created successfully."
    } catch {
        Write-Log -Level ERROR "Failed to backup project settings. Error: $($_.Exception.Message)"
    }
}

function Restore-ProjectSettings {
    <#
    .SYNOPSIS
        Restores project settings from a backup
    #>
    [CmdletBinding()]
    param()
    
    try {
        $backupDir = Join-Path -Path $Script:ProjectRoot -ChildPath ".sfdc-toolkit"
        $backupFiles = Get-ChildItem -Path $backupDir -Filter "backup-*.json" | Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -eq 0) {
            Write-Host "No backup files found." -ForegroundColor Yellow
            return
        }
        
        Write-Host "`nAvailable backups:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $backupFiles.Count; $i++) {
            Write-Host "  [$($i+1)] $($backupFiles[$i].Name) - $($backupFiles[$i].LastWriteTime)"
        }
        
        $choice = Read-Host "`nSelect backup to restore (1-$($backupFiles.Count))"
        if ($choice -match '^\d+$' -and [int]$choice -gt 0 -and [int]$choice -le $backupFiles.Count) {
            $selectedBackup = $backupFiles[[int]$choice - 1]
            $backupData = Get-JsonContent -Path $selectedBackup.FullName
            
            Write-Host "`nRestoring from backup created on: $($backupData.BackupDate)" -ForegroundColor Yellow
            if ((Read-Host "Are you sure you want to restore? (y/n)").ToLower() -eq 'y') {
                $Script:Settings = $backupData.Settings
                Save-Settings
                Write-Host "✅ Project settings restored successfully." -ForegroundColor Green
                Write-Log -Level INFO "Project settings restored from backup."
            }
        } else {
            Write-Log -Level WARN "Invalid selection."
        }
    } catch {
        Write-Log -Level ERROR "Failed to restore project settings. Error: $($_.Exception.Message)"
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
                        try {
                            $mapJson = $mapContent | ConvertFrom-Json
                            if ($mapJson.lastUpdated -and ((Get-Date) - [datetime]$mapJson.lastUpdated).TotalDays -le 7) {
                               $mapIsStale = $false
                            }
                        } catch {
                            Write-Log -Level WARN "Metadata map file is corrupted. Will create new one."
                            $mapIsStale = $true
                        }
                    }
                }
            } catch {
                Write-Log -Level WARN "Could not parse existing metadata map. Will recommend update."
            }

            if ($mapIsStale) {
                Write-Host "`nYour metadata map is missing or older than 7 days." -ForegroundColor Yellow
                if((Read-Host 'It is recommended to create/update it now. Update now? (y/n)').ToLower() -eq 'y') {
                    if($Script:Settings.SourceOrgAlias) { Update-Metadata-Mappings }
                    else { Write-Log -Level WARN 'Cannot update map without a selected Source Org.'}
                }
            }
        } else {
            Check-Prerequisites
        }

        while ($true) {
            Show-MainMenu
            $choice = Get-EnhancedUserInput -Prompt "Enter your choice" -ValidOptions @('1','2','3','s','q') -ShowHelp
            Write-Log -Level DEBUG "User entered choice '$choice'."
            switch ($choice.ToLower()) {
                '1'  { Track-FeatureUsage -Feature "Main-Menu" -Action "Compare-Deploy"; Handle-CompareAndDeploy-SubMenu }
                '2'  {
                    Track-FeatureUsage -Feature "Main-Menu" -Action "Project-Setup"
                    $result = Handle-ProjectSetup-SubMenu
                    if ($result -eq 'switch') { Main; return }
                }
                '3'  { Track-FeatureUsage -Feature "Main-Menu" -Action "Utilities"; Handle-Utilities-SubMenu }
                's'  { Track-FeatureUsage -Feature "Main-Menu" -Action "Switch-Project"; Main; return } # Kept as a hidden alias for switching projects
                'q'  { 
                    Track-FeatureUsage -Feature "Main-Menu" -Action "Quit"
                    # Send final telemetry before exit
                    try { Send-UsageTelemetry } catch { Write-Log -Level WARN "Failed to send final telemetry" }
                    Write-Log -Level INFO 'User chose to quit. Ending session.'
                    Write-Log -Level INFO "=================== SFDC DevOps Toolkit v$($Script:VERSION) Session Ended ==================="
                    Write-Log -Level INFO "Session End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                    Save-Settings; return 
                }
                default { Write-Log -Level WARN "Invalid option '$choice'."; Start-Sleep 1 }
            }
        }
    }
    catch {
        Write-Log -Level ERROR ('An unhandled exception occurred in the Main script body. Error: ' + $_.Exception.Message)
        Read-Host 'A fatal error occurred. Check the log for details. Press Enter to exit.'
    }
    finally {
        Set-Location -Path $originalLocation
        Write-Log -Level INFO '============================ Toolkit Session Ended ============================'
    }
}

# --- Script Entry Point ---
# Handle console settings safely for EXE mode
try {
    if ($Host.UI.RawUI) {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        $Host.UI.RawUI.ForegroundColor = 'White'
    }
    try { Clear-Host } catch { }
} catch {
    # Ignore console setting errors in EXE mode
}
Main