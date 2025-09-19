# Test script to debug initialization
Write-Host "Testing initialization..." -ForegroundColor Cyan

# Import the configuration module
Import-Module ".\modules\SFDC-Toolkit-Configuration.psm1" -Force

# Test initialization
Write-Host "Calling Initialize-ToolkitConfiguration..." -ForegroundColor Yellow
$result = Initialize-ToolkitConfiguration

Write-Host "Result: $result" -ForegroundColor Green
Write-Host "Config loaded: $($Script:Config -ne $null)" -ForegroundColor Green

if ($Script:Config) {
    Write-Host "Author: $($Script:Config.AuthorName)" -ForegroundColor Cyan
    Write-Host "Version: $($Script:Config.ToolkitVersion)" -ForegroundColor Cyan
    Write-Host "Has LatestVersion: $($Script:Config.PSObject.Properties.Name -contains 'LatestVersion')" -ForegroundColor Cyan
    if ($Script:Config.PSObject.Properties.Name -contains 'LatestVersion') {
        Write-Host "Latest Version: $($Script:Config.LatestVersion)" -ForegroundColor Cyan
    }
    Write-Host "Has WelcomeText: $($Script:Config.PSObject.Properties.Name -contains 'WelcomeText')" -ForegroundColor Cyan
    if ($Script:Config.PSObject.Properties.Name -contains 'WelcomeText') {
        Write-Host "Welcome Text: $($Script:Config.WelcomeText)" -ForegroundColor Cyan
    }
}

Write-Host "Test completed." -ForegroundColor Cyan
